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
    @State private var mostrarSelectorArchivo = false
    @State private var errorArchivo: String?

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

        var numColumnas: Int { filas.map(\.count).max() ?? 0 }
        var numFilas: Int { hayCabecera ? max(0, filas.count - 1) : filas.count }

        /// Primer valor no vacío de la columna (fila de muestra).
        func muestra(_ col: Int) -> String {
            let datos = hayCabecera ? Array(filas.dropFirst()) : filas
            return datos.first(where: { col < $0.count && !$0[col].trimmingCharacters(in: .whitespaces).isEmpty })?[col] ?? ""
        }

        /// Cabecera de la columna (si la hay) para mostrar como etiqueta.
        func etiqueta(_ col: Int) -> String {
            if hayCabecera, let h = filas.first, col < h.count, !h[col].isEmpty { return h[col] }
            return "Columna \(col + 1)"
        }

        var entrada: FusionAlumnos.EntradaCSV {
            .init(filas: filas, hayCabecera: hayCabecera, mapeo: mapeo)
        }
    }

    private var modoMulti: Bool { !archivos.isEmpty }

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
            isPresented: $mostrarSelectorArchivo,
            allowedContentTypes: [.commaSeparatedText, .plainText, .text],
            allowsMultipleSelection: false
        ) { cargarArchivo($0) }
        .fileImporter(
            isPresented: $mostrarSelectorMultiple,
            allowedContentTypes: [.commaSeparatedText, .plainText, .text],
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
            Text("Pega o abre el CSV exportado de Alexia. La primera fila debe ser la de cabeceras.")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .padding(16)
    }

    // MARK: - Panel de entrada

    private var panelEntrada: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Datos de origen").font(.headline)
                Spacer()
                Button {
                    mostrarSelectorArchivo = true
                } label: {
                    Label("Abrir archivo…", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                Button {
                    mostrarSelectorMultiple = true
                } label: {
                    Label("Varios CSV…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                .help("Importa varios CSV a la vez y fusiona por alumno (DNI o nombre)")
            }
            HStack {
                Picker("Separador", selection: $separadorForzado) {
                    ForEach(SeparadorOpcion.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 220)
                if separadorForzado == .auto, !textoPegado.isEmpty {
                    Text("detectado: « \(String(separadorEfectivo)) »")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            TextEditor(text: $textoPegado)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    if textoPegado.isEmpty {
                        Text("\"Apellidos, Nombre\",Fecha nacimiento,…\n\"Pérez García, Ana\",15/06/2010,…")
                            .foregroundStyle(.tertiary)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                }
                .clipShape(.rect(cornerRadius: 10))
        }
        .padding(16)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Varios CSV").font(.headline)
                Spacer()
                Button("Quitar todos", systemImage: "xmark.circle") {
                    archivos = []
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            Text("Se fusionan por DNI o, si falta, por nombre. Ajusta el mapeo de cada columna si hace falta.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(archivos.indices, id: \.self) { i in
                        bloqueArchivo(i)
                    }
                }
            }
            .frame(maxHeight: 240)
        }
    }

    private func bloqueArchivo(_ i: Int) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "doc.text").foregroundStyle(.secondary)
                    Text(archivos[i].nombre).fontWeight(.medium).lineLimit(1)
                    Spacer()
                    Text("\(archivos[i].numFilas) fila(s)").font(.caption).foregroundStyle(.secondary)
                }
                Toggle("La 1ª fila es cabecera", isOn: Binding(
                    get: { archivos[i].hayCabecera },
                    set: { archivos[i].hayCabecera = $0; remapear(i) }
                ))
                .font(.caption)
                .toggleStyle(.checkbox)

                ForEach(0..<archivos[i].numColumnas, id: \.self) { col in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(archivos[i].etiqueta(col)).font(.caption).lineLimit(1)
                            let m = archivos[i].muestra(col)
                            if !m.isEmpty {
                                Text(m).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        Picker("", selection: Binding(
                            get: { col < archivos[i].mapeo.count ? archivos[i].mapeo[col] : .ignorar },
                            set: { if col < archivos[i].mapeo.count { archivos[i].mapeo[col] = $0 } }
                        )) {
                            ForEach(CampoDestino.allCases) { Text($0.nombre).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 210)
                    }
                }
            }
        }
    }

    /// Recalcula el mapeo de un archivo al cambiar el toggle de cabecera.
    private func remapear(_ i: Int) {
        let a = archivos[i]
        if a.hayCabecera, let h = a.filas.first {
            archivos[i].mapeo = h.map { MapeoColumnas.deducir($0) }
        } else {
            archivos[i].mapeo = FusionAlumnos.autoMapearPorValor(a.filas, hayCabecera: a.hayCabecera)
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
            if !previsualizacion.isEmpty {
                Text("Se importarán \(nuevos.count) nuevo(s)"
                     + (numDuplicados > 0 ? "; \(numDuplicados) duplicado(s) se omiten." : "."))
                    .foregroundStyle(.secondary).font(.subheadline)
            }
            Spacer()
            Button("Cancelar", role: .cancel) { dismiss() }
            if numDuplicados > 0 {
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
            .disabled(nuevos.isEmpty)
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

    private func cargarArchivo(_ resultado: Result<[URL], Error>) {
        switch resultado {
        case .success(let urls):
            guard let url = urls.first else { return }
            let acceso = url.startAccessingSecurityScopedResource()
            defer { if acceso { url.stopAccessingSecurityScopedResource() } }
            do {
                let datos = try Data(contentsOf: url)
                textoPegado = decodificar(datos)
                mapeo = []           // fuerza re-automapeo
                reanalizar()
            } catch {
                errorArchivo = error.localizedDescription
            }
        case .failure(let error):
            errorArchivo = error.localizedDescription
        }
    }

    /// Carga varios CSV. Cada uno se auto-mapea (por cabecera si la detecta, o por
    /// el valor de sus columnas) y se deja editable; la fusión es automática.
    private func cargarVarios(_ resultado: Result<[URL], Error>) {
        switch resultado {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            var cargados: [ArchivoCSV] = []

            for url in urls {
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
                errorArchivo = "Los CSV seleccionados están vacíos o no se pudieron leer."
                return
            }

            // Limpia el modo pegado para no mezclar fuentes.
            textoPegado = ""
            cabeceras = []
            filasDatos = []
            mapeo = []
            archivos = cargados

        case .failure(let error):
            errorArchivo = error.localizedDescription
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
            modelContext.insert(fila.aAlumno())
        }
        dismiss()
    }

    private func normalizarDNI(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces).uppercased().replacingOccurrences(of: "-", with: "")
    }
    private func claveNombre(_ apellidos: String, _ nombre: String) -> String {
        "\(apellidos)|\(nombre)".folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }
}
