//
//  Actualizaciones.swift
//  GestionTutorial
//
//  Comprobación de actualizaciones vía GitHub Releases. La app consulta el
//  último release publicado; si su versión es mayor que la instalada, ofrece
//  descargar el .dmg (instalación manual). No auto-instala: la firma es ad-hoc.
//

import SwiftUI
import AppKit

@Observable
@MainActor
final class GestorActualizaciones {

    /// Información de una actualización disponible.
    struct Info: Identifiable {
        var id: String { version }
        let version: String
        let notas: String
        let urlDescarga: URL
        let urlPagina: URL

        /// Notas recortadas para caber en una alerta.
        var notasResumidas: String {
            let limpio = notas.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !limpio.isEmpty else { return "" }
            return limpio.count > 500 ? String(limpio.prefix(499)) + "…" : limpio
        }
    }

    var disponible: Info?        // ≠ nil ⇒ mostrar alerta de actualización
    var comprobando = false
    var sinNovedades = false     // resultado de una búsqueda manual sin cambios
    var error: String?

    /// `owner/repo` de GitHub. Sus releases deben ser públicos.
    private let repo = "mvrxs/formteachermanagement"
    private let claveOmitir = "update.versionOmitida"

    /// Versión instalada (CFBundleShortVersionString).
    var versionActual: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    // MARK: - Puntos de entrada

    /// Comprobación silenciosa al arrancar (respeta "omitir versión").
    func buscarAlArrancar() {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
        Task { await buscar(manual: false) }
    }

    /// Comprobación manual (siempre informa del resultado).
    func buscarManual() {
        Task { await buscar(manual: true) }
    }

    /// Marca una versión para no volver a avisar de ella en el arranque.
    func omitir(_ version: String) {
        UserDefaults.standard.set(version, forKey: claveOmitir)
        disponible = nil
    }

    func abrir(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    // MARK: - Lógica

    private func buscar(manual: Bool) async {
        comprobando = true
        error = nil
        sinNovedades = false
        defer { comprobando = false }

        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("FormTeacherManager", forHTTPHeaderField: "User-Agent")
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 15

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let codigo = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard codigo == 200 else {
                if manual {
                    error = codigo == 404
                        ? "Aún no hay ninguna versión publicada en GitHub Releases."
                        : "No se pudo consultar GitHub (código \(codigo))."
                }
                return
            }

            let rel = try JSONDecoder().decode(GHRelease.self, from: data)
            let remota = rel.tagLimpio

            guard esMayor(remota, que: versionActual) else {
                if manual { sinNovedades = true }
                return
            }
            if !manual, UserDefaults.standard.string(forKey: claveOmitir) == remota { return }

            let dmg = rel.assets.first { $0.name.lowercased().hasSuffix(".dmg") }
            let paginaURL = URL(string: rel.htmlURL) ?? url
            let descargaURL = dmg.flatMap { URL(string: $0.downloadURL) } ?? paginaURL

            disponible = Info(version: remota,
                              notas: rel.body ?? "",
                              urlDescarga: descargaURL,
                              urlPagina: paginaURL)
        } catch {
            if manual { self.error = error.localizedDescription }
        }
    }

    /// Compara dos versiones por componentes numéricos (1.10 > 1.9).
    private func esMayor(_ a: String, que b: String) -> Bool {
        let pa = componentes(a), pb = componentes(b)
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private func componentes(_ s: String) -> [Int] {
        s.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }
}

// MARK: - Modelo del release de GitHub

private struct GHRelease: Decodable {
    let tagName: String
    let body: String?
    let htmlURL: String
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let downloadURL: String
        enum CodingKeys: String, CodingKey { case name; case downloadURL = "browser_download_url" }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case htmlURL = "html_url"
        case assets
    }

    /// Tag sin la "v" inicial habitual (v1.3 → 1.3).
    var tagLimpio: String {
        tagName.hasPrefix("v") || tagName.hasPrefix("V") ? String(tagName.dropFirst()) : tagName
    }
}

// MARK: - Alertas reutilizables

private struct ModificadorActualizaciones: ViewModifier {
    @Bindable var gestor: GestorActualizaciones

    func body(content: Content) -> some View {
        content
            .alert("Nueva versión disponible", isPresented: Binding(
                get: { gestor.disponible != nil },
                set: { if !$0 { gestor.disponible = nil } }
            )) {
                if let info = gestor.disponible {
                    Button("Descargar") { gestor.abrir(info.urlDescarga) }
                    Button("Omitir esta versión") { gestor.omitir(info.version) }
                    Button("Ahora no", role: .cancel) { gestor.disponible = nil }
                }
            } message: {
                if let info = gestor.disponible {
                    let cabecera = "Versión \(info.version) disponible (tienes la \(gestor.versionActual))."
                    Text(info.notasResumidas.isEmpty ? cabecera : "\(cabecera)\n\n\(info.notasResumidas)")
                }
            }
            .alert("Estás al día", isPresented: $gestor.sinNovedades) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Tienes la última versión (\(gestor.versionActual)).")
            }
            .alert("No se pudo comprobar", isPresented: Binding(
                get: { gestor.error != nil },
                set: { if !$0 { gestor.error = nil } }
            )) {
                Button("OK", role: .cancel) { gestor.error = nil }
            } message: {
                Text(gestor.error ?? "")
            }
    }
}

extension View {
    /// Adjunta las alertas de actualización (disponible / al día / error).
    func alertasActualizacion(_ gestor: GestorActualizaciones) -> some View {
        modifier(ModificadorActualizaciones(gestor: gestor))
    }
}
