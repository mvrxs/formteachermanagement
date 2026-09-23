//
//  ImportadorCSVView.swift
//  GestionTutorial
//
//  Importa un CSV de Alexia: parseo robusto, separador auto-detectado,
//  auto-mapeo de columnas con ajuste manual, preview y aviso de duplicados
//  (por DNI y por nombre). Nunca fusiona: el usuario decide.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportadorCSVView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var existentes: [Alumno]

    @State private var textoPegado = ""
    @State private var separadorForzado: SeparadorOpcion = .auto
    @State private var arrastrando = false
    @State private var mostrarPegar = true
    @State private var errorArchivo: String?
    @State private var fotos: FotosPerfil?
    @State private var nombreZipFotos: String?

    // Datos derivados del parseo (recalculados al cambiar texto/separador).
    @State private var cabeceras: [String] = []
    @State private var filasDatos: [[String]] = []
    @State private var mapeo: [CampoDestino] = []

    // Modo "varios CSV": cada archivo con sus filas, mapeo y toggle de cabecera.
    @State private var archivos: [ArchivoCSV] = []
    @State private var mostrarSelectorMultiple = false

    struct ArchivoCSV: Identifiable {
        let id = UUID()
        var nombre: String
        var filas: [[String]]
        var hayCabecera: Bool
        var mapeo: [CampoDestino]

        var numFilas: Int { hayCabecera ? max(0, filas.count - 1) : filas.count }
        var rol: RolCSV { FusionAlumnos.rol(mapeo) }

        var entrada: FusionAlumnos.EntradaCSV {
            .init(filas: filas, hayCabecera: hayCabecera, mapeo: mapeo)
        }
    }

    private var modoMulti: Bool { !archivos.isEmpty }

    /// Roles obligatorios que aún no aparecen entre los CSV cargados.
    private var rolesFaltantes: [RolCSV] {
        let presentes = Set(archivos.map(\.rol))
        return RolCSV.obligatorios.filter { !presentes.contains($0) }
    }
    private var multiCompleto: Bool { modoMulti && rolesFaltantes.isEmpty }

    enum SeparadorOpcion: String, CaseIterable, Identifiable {
        case auto = "Auto"
        case coma = "Coma ( , )"
        case puntoComa = "Punto y coma ( ; )"
        var id: String { rawValue }
    }

    private var separadorEfectivo: Character {
        switch separadorForzado {
        case .auto:      return CSV.detectarSeparador(textoPegado)
        case .coma:      return ","
        case .puntoComa: return ";"
        }
    }

    // MARK: - Preview con duplicados

    /// Registros base antes de detectar duplicados: del modo multi (ya fusionados)
    /// o del parseo del texto pegado con su mapeo.
    private var baseImportados: [AlumnoImportado] {
        if modoMulti { return FusionAlumnos.desdeArchivos(archivos.map(\.entrada)) }
        return filasDatos.map { AlumnoImportado.desde(fila: $0, mapeo: mapeo) }
    }

    private var previsualizacion: [AlumnoImportado] {
        let dnisExistentes = Set(existentes
            .map { normalizarDNI($0.numeroDocumento) }
            .filter { !$0.isEmpty })
        let nombresExistentes = Set(existentes.map { claveNombre($0.apellidos, $0.nombre) })

        var vistosDNI = Set<String>()
        var vistosNombre = Set<String>()
        var resultado: [AlumnoImportado] = []

        for base in baseImportados {
            var a = base

            let dni = normalizarDNI(a.numeroDocumento)
            if !dni.isEmpty && (dnisExistentes.contains(dni) || vistosDNI.contains(dni)) {
                a.duplicadoDNI = true
            }
            if !dni.isEmpty { vistosDNI.insert(dni) }

            let clave = claveNombre(a.apellidos, a.nombre)
            if nombresExistentes.contains(clave) || vistosNombre.contains(clave) {
                a.duplicadoNombre = true
            }
            vistosNombre.insert(clave)

            resultado.append(a)
        }
        return resultado
    }

    private var nuevos: [AlumnoImportado] {
        previsualizacion.filter { !$0.duplicadoDNI && !$0.duplicadoNombre }
    }
    private var numDuplicados: Int { previsualizacion.count - nuevos.count }
    private var numFechasInvalidas: Int { previsualizacion.filter { $0.fechaNacimientoTextoInvalido != nil }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            encabezado
            Divider()
            HSplitView {
                panelEntrada.frame(minWidth: 280)
                panelMapeoYPreview.frame(minWidth: 420)
            }
            Divider()
            pieAcciones
        }
        .frame(minWidth: 860, minHeight: 600)
        .onChange(of: textoPegado) { _, _ in reanalizar() }
        .onChange(of: separadorForzado) { _, _ in reanalizar() }
        .fileImporter(
            isPresented: $mostrarSelectorMultiple,
            allowedContentTypes: [.commaSeparatedText, .plainText, .text, .zip],
            allowsMultipleSelection: true
        ) { cargarVarios($0) }
        .alert("No se pudo leer el archivo", isPresented: .constant(errorArchivo != nil)) {
            Button("OK") { errorArchivo = nil }
        } message: {
            Text(errorArchivo ?? "")
        }
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Importar alumnos desde CSV")
                .font(.title2.bold())
            Text("Arrastra, abre o pega los CSV exportados de Alexia. Se detectan y fusionan por alumno automáticamente.")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .padding(16)
    }

    // MARK: - Panel de entrada

    private var panelEntrada: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Datos de origen").font(.headline)

            zonaSoltar

            if let fotos, let nombreZipFotos {
                HStack(spacing: 8) {
                    Image(systemName: "photo.stack.fill").foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(nombreZipFotos).font(.callout).fontWeight(.medium).lineLimit(1)
                        Text(nuevos.isEmpty
                             ? "\(fotos.total) fotos cargadas · añade los CSV para asignarlas"
                             : "\(fotos.total) fotos cargadas · \(fotosAsignadas) asignadas")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        self.fotos = nil
                        self.nombreZipFotos = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(10)
                .background(.blue.opacity(0.08), in: .rect(cornerRadius: 8))
            }

            DisclosureGroup(isExpanded: $mostrarPegar) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Picker("Separador", selection: $separadorForzado) {
                            ForEach(SeparadorOpcion.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                        if separadorForzado == .auto, !textoPegado.isEmpty {
                            Text("detectado: « \(String(separadorEfectivo)) »")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    TextEditor(text: $textoPegado)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 130)
                        .overlay(alignment: .topLeading) {
                            if textoPegado.isEmpty {
                                Text("\"Apellidos, Nombre\",Fecha,…\n\"Pérez García, Ana\",15/06/2010,…")
                                    .foregroundStyle(.tertiary)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(8)
                                    .allowsHitTesting(false)
                            }
                        }
                        .clipShape(.rect(cornerRadius: 8))
                }
                .padding(.top, 4)
            } label: {
                Text("O pegar el texto de un CSV").font(.subheadline)
            }
        }
        .padding(16)
    }

    /// Zona grande de arrastrar y soltar (también abre el selector al pulsar).
    private var zonaSoltar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(arrastrando ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(arrastrando ? Color.accentColor : Color.secondary.opacity(0.35),
                              style: StrokeStyle(lineWidth: 2, dash: [8]))

            VStack(spacing: 12) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(arrastrando ? Color.accentColor : .secondary)
                    .symbolEffect(.bounce, value: arrastrando)
                VStack(spacing: 4) {
                    Text("Arrastra aquí tus CSV y el ZIP de fotos").font(.title3.bold())
                    Text("Se detectan y fusionan por alumno automáticamente")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button {
                    mostrarSelectorMultiple = true
                } label: {
                    Label("Abrir CSV…", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { mostrarSelectorMultiple = true }
        .dropDestination(for: URL.self) { urls, _ in
            cargarURLs(urls)
            return true
        } isTargeted: { arrastrando = $0 }
    }

    // MARK: - Mapeo + preview

    private var panelMapeoYPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            if modoMulti {
                panelMultiArchivos
                Divider()
                cabeceraPreview
                List(previsualizacion) { a in
                    filaPreview(a)
                }
                .clipShape(.rect(cornerRadius: 10))
            } else if cabeceras.isEmpty {
                ContentUnavailableView("Esperando datos",
                                       systemImage: "tablecells",
                                       description: Text("Pega el CSV, abre un archivo o importa varios CSV a la vez."))
            } else {
                Text("Mapeo de columnas").font(.headline)
                Text("Auto-detectado por cabecera. Corrige a mano si algo no encaja.")
                    .font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(cabeceras.indices, id: \.self) { idx in
                            filaMapeo(idx)
                        }
                    }
                }
                .frame(maxHeight: 220)

                Divider()
                cabeceraPreview
                List(previsualizacion) { a in
                    filaPreview(a)
                }
                .clipShape(.rect(cornerRadius: 10))
            }
        }
        .padding(16)
    }

    private var cabeceraPreview: some View {
        HStack {
            Text("Previsualización (\(previsualizacion.count))").font(.headline)
            Spacer()
            if numDuplicados > 0 {
                Label("\(numDuplicados) duplicado(s)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
            if numFechasInvalidas > 0 {
                Label("\(numFechasInvalidas) fecha(s) no válidas", systemImage: "calendar.badge.exclamationmark")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private var panelMultiArchivos: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Varios CSV (automático)").font(.headline)
                Spacer()
                Button("Quitar todos", systemImage: "xmark.circle") {
                    archivos = []
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            // Archivos cargados con su rol detectado.
            VStack(alignment: .leading, spacing: 4) {
                ForEach(archivos) { a in
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(a.nombre).fontWeight(.medium).lineLimit(1)
                            Text(a.rol.titulo)
                                .font(.caption)
                                .foregroundStyle(a.rol == .otro ? .orange : .secondary)
                        }
                        Spacer()
                        Text("\(a.numFilas) fila(s)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Checklist de tipos obligatorios.
            VStack(alignment: .leading, spacing: 3) {
                Text("Tipos necesarios").font(.subheadline.bold())
                ForEach(RolCSV.obligatorios) { rol in
                    let ok = archivos.contains { $0.rol == rol }
                    Label(rol.titulo, systemImage: ok ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(ok ? .green : .secondary)
                }
            }

            if !rolesFaltantes.isEmpty {
                Label("Faltan CSV: sin ellos los datos quedarían a medias. Añade los que faltan.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
                Button("Añadir más CSV…", systemImage: "plus") {
                    mostrarSelectorMultiple = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func filaMapeo(_ idx: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(cabeceras[idx]).fontWeight(.medium).lineLimit(1)
                if let ejemplo = filasDatos.first, idx < ejemplo.count, !ejemplo[idx].isEmpty {
                    Text(ejemplo[idx]).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Picker("", selection: Binding(
                get: { idx < mapeo.count ? mapeo[idx] : .ignorar },
                set: { if idx < mapeo.count { mapeo[idx] = $0 } }
            )) {
                ForEach(CampoDestino.allCases) { Text($0.nombre).tag($0) }
            }
            .labelsHidden()
            .frame(width: 240)
        }
        .padding(.vertical, 2)
    }

    private func filaPreview(_ a: AlumnoImportado) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconoPreview(a))
                .foregroundStyle(colorPreview(a))
            VStack(alignment: .leading, spacing: 1) {
                Text(a.nombreMostrar).fontWeight(.medium)
                HStack(spacing: 6) {
                    if !a.numeroDocumento.isEmpty { Text(a.numeroDocumento) }
                    if let f = a.fechaNacimiento { Text("· \(f.formatted(Formatos.fechaMedia))") }
                    if let inv = a.fechaNacimientoTextoInvalido { Text("· fecha «\(inv)»?").foregroundStyle(.orange) }
                }
                .font(.caption).foregroundStyle(.secondary)
                if a.duplicadoDNI {
                    Text("DNI ya existente").font(.caption).foregroundStyle(.orange)
                } else if a.duplicadoNombre {
                    Text("Nombre ya existente").font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
        }
    }

    private func iconoPreview(_ a: AlumnoImportado) -> String {
        (a.duplicadoDNI || a.duplicadoNombre) ? "exclamationmark.triangle.fill" : "person.crop.circle.badge.plus"
    }
    private func colorPreview(_ a: AlumnoImportado) -> Color {
        (a.duplicadoDNI || a.duplicadoNombre) ? .orange : .green
    }

    // MARK: - Pie de acciones

    private var pieAcciones: some View {
        HStack {
            if modoMulti, !multiCompleto {
                Label("Faltan tipos de CSV para importar", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange).font(.subheadline)
            } else if !previsualizacion.isEmpty {
                Text("Se importarán \(nuevos.count) nuevo(s)"
                     + (numDuplicados > 0 ? "; \(numDuplicados) duplicado(s) se omiten." : "."))
                    .foregroundStyle(.secondary).font(.subheadline)
            }
            Spacer()
            Button("Cancelar", role: .cancel) { dismiss() }
            if numDuplicados > 0, !(modoMulti && !multiCompleto) {
                Menu {
                    Button("Importar TODOS, incluidos duplicados (\(previsualizacion.count))") {
                        importar(previsualizacion)
                    }
                } label: {
                    Text("Opciones")
                }
                .menuStyle(.button)
                .fixedSize()
            }
            Button {
                importar(nuevos)
            } label: {
                Text("Importar \(nuevos.count) nuevo(s)")
            }
            .buttonStyle(.borderedProminent)
            .disabled(nuevos.isEmpty || (modoMulti && !multiCompleto))
        }
        .padding(16)
    }

    // MARK: - Lógica

    private func reanalizar() {
        // Pegar/teclear texto sale del modo "varios CSV".
        if !textoPegado.isEmpty, modoMulti {
            archivos = []
        }
        let filas = CSV.parsear(textoPegado, separador: separadorEfectivo)
        guard let primera = filas.first else {
            cabeceras = []; filasDatos = []; mapeo = []
            return
        }
        cabeceras = primera
        filasDatos = Array(filas.dropFirst())
        // Auto-mapeo (conserva ajustes manuales solo si no cambió el nº de columnas).
        if mapeo.count != primera.count {
            mapeo = primera.map { MapeoColumnas.deducir($0) }
        }
    }

    private func cargarVarios(_ resultado: Result<[URL], Error>) {
        switch resultado {
        case .success(let urls): cargarURLs(urls)
        case .failure(let error): errorArchivo = error.localizedDescription
        }
    }

    /// Carga uno o varios CSV (desde el selector o arrastrados). Cada archivo se
    /// auto-mapea (por cabecera si la detecta, o por el valor de sus columnas) y
    /// se acumula; la fusión por alumno es automática.
    private func cargarURLs(_ urls: [URL]) {
        let zips = urls.filter { $0.pathExtension.lowercased() == "zip" }
        let csvs = urls.filter { ["csv", "txt", "tsv", "tab"].contains($0.pathExtension.lowercased()) || $0.pathExtension.isEmpty }
        guard !csvs.isEmpty || !zips.isEmpty else {
            errorArchivo = "Arrastra CSV (.csv, .txt) o el ZIP de fotos."
            return
        }

        // ZIP de fotos de perfil (carpeta con .jpg + manifest.csv).
        for url in zips {
            let acceso = url.startAccessingSecurityScopedResource()
            defer { if acceso { url.stopAccessingSecurityScopedResource() } }
            do {
                let datos = try Data(contentsOf: url)
                let fp = FotosPerfil.desdeZip(datos)
                if fp.total > 0 {
                    fotos = fp
                    nombreZipFotos = url.lastPathComponent
                } else {
                    errorArchivo = "El ZIP no contiene fotos reconocibles (falta manifest.csv o los .jpg)."
                }
            } catch {
                errorArchivo = "No se pudo leer el ZIP: \(error.localizedDescription)"
            }
        }

        var cargados: [ArchivoCSV] = []
        for url in csvs {
            let acceso = url.startAccessingSecurityScopedResource()
            defer { if acceso { url.stopAccessingSecurityScopedResource() } }
            guard let datos = try? Data(contentsOf: url) else { continue }

            let texto = decodificar(datos)
            let sep = CSV.detectarSeparador(texto)
            let filas = CSV.parsear(texto, separador: sep)
            guard !filas.isEmpty else { continue }

            let hayCabecera = adivinarCabecera(filas)
            let mapeo = hayCabecera
                ? (filas.first ?? []).map { MapeoColumnas.deducir($0) }
                : FusionAlumnos.autoMapearPorValor(filas, hayCabecera: false)

            cargados.append(ArchivoCSV(nombre: url.lastPathComponent,
                                       filas: filas,
                                       hayCabecera: hayCabecera,
                                       mapeo: mapeo))
        }

        guard !cargados.isEmpty else {
            // Si solo se soltó el ZIP de fotos, no es un error.
            if !csvs.isEmpty { errorArchivo = "Los CSV están vacíos o no se pudieron leer." }
            return
        }

        // Limpia el modo pegado para no mezclar fuentes.
        textoPegado = ""
        cabeceras = []
        filasDatos = []
        mapeo = []
        // Acumula (permite añadir más), evitando repetir por nombre.
        for nuevo in cargados where !archivos.contains(where: { $0.nombre == nuevo.nombre }) {
            archivos.append(nuevo)
        }
    }

    /// Heurística: la 1ª fila es cabecera si sus valores se reconocen como
    /// nombres de campo (y no como datos de un alumno).
    private func adivinarCabecera(_ filas: [[String]]) -> Bool {
        guard let h = filas.first, !h.isEmpty else { return false }
        let mapeados = h.map { MapeoColumnas.deducir($0) }.filter { $0 != .ignorar }.count
        return mapeados >= 2 && mapeados * 2 >= h.count
    }

    /// Decodifica según BOM (UTF-16 LE/BE, típico de exports de Windows/Excel) y,
    /// si no, prueba UTF-8 y finalmente Latin-1 (Excel español).
    private func decodificar(_ datos: Data) -> String {
        if datos.starts(with: [0xFF, 0xFE]) || datos.starts(with: [0xFE, 0xFF]) {
            if let u16 = String(data: datos, encoding: .utf16) { return u16 }
        }
        if datos.starts(with: [0xEF, 0xBB, 0xBF]) || String(data: datos, encoding: .utf8) != nil {
            if let u8 = String(data: datos, encoding: .utf8) { return u8 }
        }
        return String(data: datos, encoding: .isoLatin1) ?? ""
    }

    private func importar(_ filas: [AlumnoImportado]) {
        for fila in filas {
            let alumno = fila.aAlumno()
            if let foto = fotos?.foto(apellidos: fila.apellidos, nombre: fila.nombre) {
                alumno.foto = foto
            }
            modelContext.insert(alumno)
        }
        dismiss()
    }

    /// Nº de alumnos nuevos que recibirán foto del ZIP.
    private var fotosAsignadas: Int {
        guard let fotos else { return 0 }
        return nuevos.filter { fotos.foto(apellidos: $0.apellidos, nombre: $0.nombre) != nil }.count
    }

    private func normalizarDNI(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces).uppercased().replacingOccurrences(of: "-", with: "")
    }
    private func claveNombre(_ apellidos: String, _ nombre: String) -> String {
        "\(apellidos)|\(nombre)".folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }
}
