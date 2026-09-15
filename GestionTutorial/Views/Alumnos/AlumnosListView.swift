//
//  AlumnosListView.swift
//  GestionTutorial
//
//  Lista de alumnos con búsqueda, filtro por estado de edad, agrupación,
//  alta manual e importación CSV.
//

import SwiftUI
import SwiftData
import AppKit
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
        .onDeleteCommand {
            if let seleccion { borrarAlumno(seleccion) }
        }
        .navigationTitle("Alumnos")
        .navigationSubtitle(subtitulo)
        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
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
            ToolbarSpacer(.fixed)
            ToolbarItem {
                Button {
                    mostrarImportador = true
                } label: {
                    Label("Importar CSV", systemImage: "square.and.arrow.down")
                }
            }
            ToolbarItem {
                Button(action: exportarPowerPoint) {
                    Label("Exportar PowerPoint", systemImage: "rectangle.on.rectangle.angled")
                }
                .disabled(filtrados.isEmpty)
                .help("Exporta los alumnos visibles a una presentación de PowerPoint")
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

    // MARK: - Exportación a PowerPoint

    private func exportarPowerPoint() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "pptx") ?? .presentation]
        panel.nameFieldStringValue = "Grupo 1SMX-A.pptx"
        panel.canCreateDirectories = true
        panel.title = "Exportar a PowerPoint"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let datos = ExportadorPowerPoint.generar(
            alumnos: filtrados,
            grupo: "1SMX-A",
            logoPNG: logoMonlauPNG()
        )
        do {
            try datos.write(to: url)
        } catch {
            errorExportar = error.localizedDescription
        }
    }

    /// Logo de la escuela desde el catálogo de assets, re-codificado a PNG para el .pptx.
    private func logoMonlauPNG() -> Data? {
        guard let img = NSImage(named: "LogoMonlau"),
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
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
