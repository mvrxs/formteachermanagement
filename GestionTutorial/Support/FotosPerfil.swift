//
//  FotosPerfil.swift
//  GestionTutorial
//
//  Lee el .zip de fotos de perfil (carpeta con .jpg + manifest.csv) y las
//  empareja con cada alumno por el nombre (normalizado a conjunto de palabras).
//  El manifest.csv mapea filename → fullname; el fullname se compara con el
//  "Apellidos, Nombre" del alumno.
//

import Foundation

struct FotosPerfil {
    private struct Entrada { let tokens: Set<String>; let datos: Data }
    private var exactas: [String: Data] = [:]
    private var entradas: [Entrada] = []

    /// Nº de fotos disponibles en el zip.
    var total: Int { entradas.count }

    /// Construye el mapa desde los bytes de un .zip.
    static func desdeZip(_ datos: Data) -> FotosPerfil {
        var fp = FotosPerfil()
        let archivos = ZipReader.descomprimir(datos)
        guard !archivos.isEmpty else { return fp }

        var porNombreArchivo: [String: Data] = [:]
        var manifest: Data?
        for (ruta, contenido) in archivos {
            let base = (ruta as NSString).lastPathComponent
            if base.caseInsensitiveCompare("manifest.csv") == .orderedSame { manifest = contenido; continue }
            let ext = (base as NSString).pathExtension.lowercased()
            if ["jpg", "jpeg", "png"].contains(ext) { porNombreArchivo[base] = contenido }
        }

        guard let manifest, let texto = String(data: manifest, encoding: .utf8) else { return fp }
        let filas = CSV.parsear(texto, separador: CSV.detectarSeparador(texto))
        guard let cabecera = filas.first else { return fp }

        func idx(_ nombre: String) -> Int? {
            cabecera.firstIndex { normalizar($0) == nombre }
        }
        guard let iFull = idx("fullname"), let iFile = idx("filename") else { return fp }

        for fila in filas.dropFirst() where iFull < fila.count && iFile < fila.count {
            let full = fila[iFull]
            let archivo = fila[iFile]
            guard let bruto = porNombreArchivo[archivo] else { continue }
            let tokens = tokeniza(full)
            guard !tokens.isEmpty else { continue }
            let jpeg = ImagenUtil.jpegRedimensionado(datos: bruto) ?? bruto
            fp.exactas[clave(tokens)] = jpeg
            fp.entradas.append(Entrada(tokens: tokens, datos: jpeg))
        }
        return fp
    }

    /// Devuelve la foto de un alumno por nombre: coincidencia exacta del conjunto
    /// de palabras o, si no, la de mayor solape (≥ 2 palabras).
    func foto(apellidos: String, nombre: String) -> Data? {
        let t = FotosPerfil.tokeniza("\(apellidos) \(nombre)")
        guard !t.isEmpty else { return nil }
        if let d = exactas[FotosPerfil.clave(t)] { return d }

        var mejor: Data?
        var mejorSolape = 1   // exige al menos 2 palabras en común
        for e in entradas {
            let o = e.tokens.intersection(t).count
            if o > mejorSolape { mejorSolape = o; mejor = e.datos }
        }
        return mejor
    }

    // MARK: - Normalización

    private static func tokeniza(_ s: String) -> Set<String> {
        let base = s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let toks = base.split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 1 }
        return Set(toks)
    }

    private static func clave(_ t: Set<String>) -> String { t.sorted().joined(separator: " ") }

    private static func normalizar(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
