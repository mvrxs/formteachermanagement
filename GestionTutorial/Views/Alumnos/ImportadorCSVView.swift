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

    private var previsualizacion: [AlumnoImportado] {
        let dnisExistentes = Set(existentes
            .map { normalizarDNI($0.numeroDocumento) }
            .filter { !$0.isEmpty })
        let nombresExistentes = Set(existentes.map { claveNombre($0.apellidos, $0.nombre) })

        var vistosDNI = Set<String>()
        var vistosNombre = Set<String>()
        var resultado: [AlumnoImportado] = []

        for fila in filasDatos {
            var a = AlumnoImportado.desde(fila: fila, mapeo: mapeo)

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
            if cabeceras.isEmpty {
                ContentUnavailableView("Esperando datos",
                                       systemImage: "tablecells",
                                       description: Text("Pega el CSV o abre un archivo para ver el mapeo de columnas."))
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
                List(previsualizacion) { a in
                    filaPreview(a)
                }
                .clipShape(.rect(cornerRadius: 10))
            }
        }
        .padding(16)
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

    /// Decodifica probando UTF-8 y, si falla, Latin-1 (típico de Excel español).
    private func decodificar(_ datos: Data) -> String {
        if let utf8 = String(data: datos, encoding: .utf8) { return utf8 }
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
