//
//  AlumnosListView.swift
//  GestionTutorial
//
//  Lista de alumnos con búsqueda, filtro por estado de edad, agrupación,
//  alta manual e importación CSV.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension EstadoEdad {
    /// Color de identificación del estado en la interfaz.
    var color: Color {
        switch self {
        case .menor:           return .secondary
        case .cumpleEsteCurso: return .orange
        case .mayor:           return .green
        }
    }
}

struct AlumnosListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var seleccion: Alumno?

    @Query(sort: [SortDescriptor(\Alumno.apellidos), SortDescriptor(\Alumno.nombre)])
    private var alumnos: [Alumno]

    @State private var busqueda = ""
    @State private var mostrarImportador = false
    @State private var estadoFiltro: EstadoEdad?      // nil = todos
    @State private var agrupar = false
    @State private var soloAutorizacionPendiente = false
    @State private var soloInglesConvalidado = false
    @State private var soloEmancipados = false
    @State private var errorExportar: String?
    @State private var confirmarBorrado: TipoBorrado?
    @State private var docExportar: DocumentoDatos?
    @State private var nombreExportar = ""
    @State private var tipoExportar: UTType = .data
    @State private var mostrarExportador = false

    enum TipoBorrado: Identifiable {
        case todos, visibles
        var id: Int { self == .todos ? 0 : 1 }
    }

    /// Filtrado solo por búsqueda (para contar por estado en el menú).
    private var buscados: [Alumno] {
        BusquedaAlumnos.filtrar(alumnos, texto: busqueda)
    }

    /// Búsqueda + filtro de estado de edad + filtros de autorización/inglés.
    private var filtrados: [Alumno] {
        buscados.filter { alumno in
            (estadoFiltro == nil || alumno.estadoEdad == estadoFiltro)
            && (!soloAutorizacionPendiente || alumno.autorizacionPendiente)
            && (!soloInglesConvalidado || alumno.inglesConvalidado)
            && (!soloEmancipados || alumno.emancipado)
        }
    }

    private var hayFiltroActivo: Bool {
        estadoFiltro != nil || soloAutorizacionPendiente || soloInglesConvalidado || soloEmancipados
    }

    private func cuenta(_ estado: EstadoEdad) -> Int {
        buscados.filter { $0.estadoEdad == estado }.count
    }

    var body: some View {
        List(selection: $seleccion) {
            if agrupar {
                ForEach(EstadoEdad.allCases) { estado in
                    let grupo = filtrados.filter { $0.estadoEdad == estado }
                    if !grupo.isEmpty {
                        Section {
                            ForEach(grupo) { fila($0) }
                        } header: {
                            Label(estado.rawValue, systemImage: estado.simbolo)
                                .foregroundStyle(estado.color)
                        }
                    }
                }
            } else {
                ForEach(filtrados) { fila($0) }
                    .onDelete(perform: borrar)
            }
        }
        #if os(macOS)
        .onDeleteCommand {
            if let seleccion { borrarAlumno(seleccion) }
        }
        #endif
        .navigationTitle("Alumnos")
        .subtituloNavegacion(subtitulo)
        .navigationSplitViewColumnWidth(min: 345, ideal: 415, max: 500)
        .searchable(text: $busqueda, prompt: "Buscar")
        .searchSuggestions {
            if busqueda.isEmpty {
                ForEach(BusquedaAlumnos.clavesSugeridas, id: \.self) { clave in
                    Label("\(clave):", systemImage: "magnifyingglass")
                        .searchCompletion("\(clave):")
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("Filtrar por edad", selection: $estadoFiltro) {
                        Text("Todos (\(buscados.count))").tag(EstadoEdad?.none)
                        ForEach(EstadoEdad.allCases) { estado in
                            Label("\(estado.rawValue) (\(cuenta(estado)))", systemImage: estado.simbolo)
                                .tag(EstadoEdad?.some(estado))
                        }
                    }
                    Divider()
                    Toggle("Solo autorización sin firmar", isOn: $soloAutorizacionPendiente)
                    Toggle("Solo inglés convalidado", isOn: $soloInglesConvalidado)
                    Toggle("Solo emancipados", isOn: $soloEmancipados)
                    Divider()
                    Toggle("Agrupar por edad", isOn: $agrupar)
                } label: {
                    Label("Filtros", systemImage: hayFiltroActivo || agrupar
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem {
                Menu {
                    if hayFiltroActivo || !busqueda.isEmpty {
                        Button(role: .destructive) {
                            confirmarBorrado = .visibles
                        } label: {
                            Label("Eliminar \(filtrados.count) visibles", systemImage: "trash")
                        }
                    }
                    Button(role: .destructive) {
                        confirmarBorrado = .todos
                    } label: {
                        Label("Eliminar todos…", systemImage: "trash")
                    }
                } label: {
                    Label("Más acciones", systemImage: "ellipsis.circle")
                }
                .menuIndicator(.hidden)
                .disabled(alumnos.isEmpty)
            }
            ToolbarSpacer(.fixed)
            ToolbarItem {
                Button {
                    mostrarImportador = true
                } label: {
                    Label("Importar CSV", systemImage: "square.and.arrow.down")
                }
            }
            ToolbarItem {
                Menu {
                    Button {
                        exportarPowerPoint()
                    } label: {
                        Label("PowerPoint (fichas)", systemImage: "rectangle.on.rectangle.angled")
                    }
                    Divider()
                    Button {
                        exportarTabla(.csv)
                    } label: {
                        Label("CSV", systemImage: "tablecells")
                    }
                    Button {
                        exportarTabla(.excel)
                    } label: {
                        Label("Excel (.xlsx)", systemImage: "tablecells.badge.ellipsis")
                    }
                } label: {
                    Label("Exportar", systemImage: "square.and.arrow.up")
                }
                .disabled(filtrados.isEmpty)
                .help("Exporta los alumnos visibles")
            }
            ToolbarItem {
                Button(action: nuevoAlumno) {
                    Label("Nuevo alumno", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $mostrarImportador) {
            ImportadorCSVView()
        }
        .alert("No se pudo exportar", isPresented: .constant(errorExportar != nil)) {
            Button("OK") { errorExportar = nil }
        } message: {
            Text(errorExportar ?? "")
        }
        .fileExporter(
            isPresented: $mostrarExportador,
            document: docExportar,
            contentType: tipoExportar,
            defaultFilename: nombreExportar
        ) { resultado in
            if case .failure(let error) = resultado {
                errorExportar = error.localizedDescription
            }
        }
        .confirmationDialog(
            "¿Eliminar alumnos?",
            isPresented: Binding(get: { confirmarBorrado != nil },
                                 set: { if !$0 { confirmarBorrado = nil } }),
            presenting: confirmarBorrado
        ) { tipo in
            Button(tipo == .todos ? "Eliminar los \(alumnos.count)" : "Eliminar \(filtrados.count) visibles",
                   role: .destructive) {
                ejecutarBorrado(tipo)
            }
            Button("Cancelar", role: .cancel) { confirmarBorrado = nil }
        } message: { tipo in
            Text(tipo == .todos
                 ? "Se eliminarán TODOS los alumnos (\(alumnos.count)) y sus tutorías y necesidades. No se puede deshacer."
                 : "Se eliminarán los \(filtrados.count) alumnos visibles y sus datos. No se puede deshacer.")
        }
        .overlay {
            if alumnos.isEmpty {
                ContentUnavailableView {
                    Label("Sin alumnos", systemImage: "person.2")
                } description: {
                    Text("Añade uno con + o importa un CSV de Alexia.")
                }
            } else if filtrados.isEmpty {
                ContentUnavailableView {
                    Label("Sin resultados", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("Ningún alumno coincide con la búsqueda o el filtro.")
                }
            }
        }
    }

    private var subtitulo: String {
        if let estadoFiltro {
            return "\(filtrados.count) · \(estadoFiltro.rawValue.lowercased())"
        }
        return "\(alumnos.count) en el grupo"
    }

    @ViewBuilder
    private func fila(_ alumno: Alumno) -> some View {
        FilaAlumno(alumno: alumno)
            .tag(alumno)
            .contextMenu {
                Button(role: .destructive) {
                    borrarAlumno(alumno)
                } label: {
                    Label("Eliminar alumno", systemImage: "trash")
                }
            }
    }

    // MARK: - Exportación (fileExporter, macOS + iOS)

    private enum FormatoTabla {
        case csv, excel
        var ext: String { self == .csv ? "csv" : "xlsx" }
        var tipo: UTType { self == .csv ? .commaSeparatedText : (UTType(filenameExtension: "xlsx") ?? .spreadsheet) }
    }

    private func exportarPowerPoint() {
        let datos = ExportadorPowerPoint.generar(
            alumnos: filtrados,
            grupo: "1SMX-A",
            logoPNG: Plataforma.pngDeAsset("LogoMonlau")
        )
        presentarExportador(datos, tipo: UTType(filenameExtension: "pptx") ?? .data, nombre: "Grupo 1SMX-A.pptx")
    }

    private func exportarTabla(_ formato: FormatoTabla) {
        let datos = formato == .csv
            ? ExportadorTabla.csv(alumnos: filtrados)
            : ExportadorTabla.xlsx(alumnos: filtrados)
        presentarExportador(datos, tipo: formato.tipo, nombre: "Alumnos 1SMX-A.\(formato.ext)")
    }

    private func presentarExportador(_ datos: Data, tipo: UTType, nombre: String) {
        docExportar = DocumentoDatos(datos: datos, tipo: tipo)
        tipoExportar = tipo
        nombreExportar = nombre
        mostrarExportador = true
    }

    private func nuevoAlumno() {
        let alumno = Alumno(apellidos: "", nombre: "Nuevo alumno")
        modelContext.insert(alumno)
        seleccion = alumno
    }

    private func borrar(_ offsets: IndexSet) {
        for index in offsets {
            borrarAlumno(filtrados[index])
        }
    }

    private func borrarAlumno(_ alumno: Alumno) {
        if alumno == seleccion { seleccion = nil }
        modelContext.delete(alumno)
    }

    private func ejecutarBorrado(_ tipo: TipoBorrado) {
        let objetivo = tipo == .todos ? alumnos : filtrados
        seleccion = nil
        for alumno in objetivo {
            modelContext.delete(alumno)
        }
        confirmarBorrado = nil
    }
}

struct FilaAlumno: View {
    let alumno: Alumno

    var body: some View {
        HStack(spacing: 10) {
            AvatarAlumno(foto: alumno.foto, tamano: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(alumno.nombreCompleto)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let edad = alumno.edad {
                        Text("\(edad) años")
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    if !alumno.numeroDocumento.isEmpty {
                        Text("· \(alumno.numeroDocumento)")
                            .truncationMode(.tail)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
            iconosEstado
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var iconosEstado: some View {
        HStack(spacing: 6) {
            // Edad: mayor (verde) / cumple este curso (naranja). Menor: sin icono.
            switch alumno.estadoEdad {
            case .mayor:
                icono("18.circle.fill", .green, "Mayor de edad")
            case .cumpleEsteCurso:
                if let f = alumno.cumple18DuranteCurso {
                    icono("18.circle.fill", .orange, "Cumple 18 el \(f.formatted(Formatos.fechaMedia))")
                } else {
                    icono("18.circle.fill", .orange, "Cumple 18 este curso")
                }
            case .menor:
                EmptyView()
            }

            // Un único check verde para convalidación y/o autorización firmada.
            if alumno.tieneAlgunaConvalidacion || alumno.estadoAutorizacion == .firmada {
                icono("checkmark.circle.fill", .green, ayudaCheck)
            }

            // Autorización pendiente de firmar: reloj naranja.
            if alumno.estadoAutorizacion == .pendiente {
                icono("clock.fill", .orange, "Autorización pendiente de firmar")
            }

            // No quiere firmar: aviso rojo.
            if alumno.estadoAutorizacion == .rechazada {
                icono("exclamationmark.triangle.fill", .red, "No quiere firmar la autorización")
            }

            // Necesidades especiales.
            if !alumno.necesidades.isEmpty {
                icono("accessibility", .purple, "Tiene necesidades especiales")
            }

            // Alergias / cuestiones médicas (seguridad).
            if !alumno.alergiasMedico.isEmpty {
                icono("cross.case.fill", .red, "Alergias / cuestiones médicas")
            }
        }
    }

    private func icono(_ sistema: String, _ color: Color, _ ayuda: String) -> some View {
        Image(systemName: sistema)
            .foregroundStyle(color)
            .help(ayuda)
    }

    private var ayudaCheck: String {
        var partes: [String] = []
        if alumno.estadoAutorizacion == .firmada { partes.append("Autorización firmada") }
        if alumno.tieneAlgunaConvalidacion { partes.append("Convalidación") }
        return partes.joined(separator: " · ")
    }
}
