//
//  ZipReader.swift
//  GestionTutorial
//
//  Lector ZIP mínimo (STORE + DEFLATE) para descomprimir el .zip de fotos de
//  perfil. Usa el framework Compression (raw DEFLATE), disponible en macOS e iOS.
//

import Foundation
import Compression

enum ZipReader {
    /// Descomprime un ZIP en memoria. Devuelve [nombreEntrada: datos].
    /// Soporta método 0 (almacenado) y 8 (deflate).
    static func descomprimir(_ datos: Data) -> [String: Data] {
        let bytes = [UInt8](datos)
        guard let eocd = buscarEOCD(bytes) else { return [:] }

        let inicioCentral = Int(leerLE32(bytes, eocd + 16))
        let numEntradas = Int(leerLE16(bytes, eocd + 10))

        var resultado: [String: Data] = [:]
        var p = inicioCentral

        for _ in 0..<numEntradas {
            guard p + 46 <= bytes.count, leerLE32(bytes, p) == 0x02014b50 else { break }
            let metodo = leerLE16(bytes, p + 10)
            let compSize = Int(leerLE32(bytes, p + 20))
            let uncompSize = Int(leerLE32(bytes, p + 24))
            let nameLen = Int(leerLE16(bytes, p + 28))
            let extraLen = Int(leerLE16(bytes, p + 30))
            let commentLen = Int(leerLE16(bytes, p + 32))
            let localOffset = Int(leerLE32(bytes, p + 42))

            let nombre = cadena(bytes, p + 46, nameLen)
            p += 46 + nameLen + extraLen + commentLen

            // Cabecera local para localizar el inicio de los datos.
            guard localOffset + 30 <= bytes.count, leerLE32(bytes, localOffset) == 0x04034b50 else { continue }
            let lNameLen = Int(leerLE16(bytes, localOffset + 26))
            let lExtraLen = Int(leerLE16(bytes, localOffset + 28))
            let inicioDatos = localOffset + 30 + lNameLen + lExtraLen
            guard inicioDatos + compSize <= bytes.count else { continue }

            let comprimido = Array(bytes[inicioDatos..<inicioDatos + compSize])

            if metodo == 0 {
                resultado[nombre] = Data(comprimido)
            } else if metodo == 8 {
                if let inflado = inflar(comprimido, tamano: uncompSize) {
                    resultado[nombre] = inflado
                }
            }
        }
        return resultado
    }

    // MARK: - Utilidades

    /// Busca la firma End Of Central Directory (0x06054b50) desde el final.
    private static func buscarEOCD(_ b: [UInt8]) -> Int? {
        guard b.count >= 22 else { return nil }
        var i = b.count - 22
        let minimo = max(0, b.count - 22 - 65_536)   // el comentario final cabe en 64 KB
        while i >= minimo {
            if leerLE32(b, i) == 0x06054b50 { return i }
            i -= 1
        }
        return nil
    }

    private static func inflar(_ comprimido: [UInt8], tamano: Int) -> Data? {
        guard tamano > 0 else { return Data() }
        var destino = [UInt8](repeating: 0, count: tamano)
        let escritos = comprimido.withUnsafeBufferPointer { src in
            destino.withUnsafeMutableBufferPointer { dst in
                compression_decode_buffer(dst.baseAddress!, tamano,
                                          src.baseAddress!, comprimido.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard escritos > 0 else { return nil }
        return Data(destino.prefix(escritos))
    }

    private static func leerLE16(_ b: [UInt8], _ i: Int) -> UInt16 {
        guard i + 1 < b.count else { return 0 }
        return UInt16(b[i]) | (UInt16(b[i + 1]) << 8)
    }

    private static func leerLE32(_ b: [UInt8], _ i: Int) -> UInt32 {
        guard i + 3 < b.count else { return 0 }
        return UInt32(b[i]) | (UInt32(b[i + 1]) << 8) | (UInt32(b[i + 2]) << 16) | (UInt32(b[i + 3]) << 24)
    }

    private static func cadena(_ b: [UInt8], _ i: Int, _ len: Int) -> String {
        guard i + len <= b.count else { return "" }
        return String(decoding: b[i..<i + len], as: UTF8.self)
    }
}
