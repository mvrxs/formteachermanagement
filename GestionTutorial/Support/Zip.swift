//
//  Zip.swift
//  GestionTutorial
//
//  Escritor ZIP mínimo (método STORE, sin compresión) para empaquetar OOXML.
//  Un .pptx es un ZIP; con entradas STORE + CRC32 es un paquete válido que
//  PowerPoint y Keynote abren sin problemas, y evita dependencias externas.
//

import Foundation

struct ZipWriter {
    private struct Entrada {
        let nombre: String
        let tam: UInt32
        let crc: UInt32
        let offset: UInt32
    }

    private var entradas: [Entrada] = []
    private var buffer = Data()

    /// Tabla CRC-32 (polinomio 0xEDB88320), calculada una vez.
    private static let tablaCRC: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
        return c
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for b in data { c = tablaCRC[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFFFFFF
    }

    /// Añade un archivo al paquete (sin compresión).
    mutating func agregar(_ nombre: String, _ data: Data) {
        let crc = Self.crc32(data)
        let offset = UInt32(buffer.count)
        let nombreBytes = Array(nombre.utf8)

        var h = Data()
        h.appendLE32(0x04034b50)              // firma cabecera local
        h.appendLE16(20)                      // versión necesaria
        h.appendLE16(0)                       // flags
        h.appendLE16(0)                       // método 0 = STORE
        h.appendLE16(0)                       // hora
        h.appendLE16(0)                       // fecha
        h.appendLE32(crc)
        h.appendLE32(UInt32(data.count))      // tam. comprimido
        h.appendLE32(UInt32(data.count))      // tam. sin comprimir
        h.appendLE16(UInt16(nombreBytes.count))
        h.appendLE16(0)                       // longitud extra
        h.append(contentsOf: nombreBytes)

        buffer.append(h)
        buffer.append(data)
        entradas.append(Entrada(nombre: nombre, tam: UInt32(data.count), crc: crc, offset: offset))
    }

    /// Cierra el paquete y devuelve los bytes del ZIP completo.
    mutating func finalizar() -> Data {
        let inicioCentral = UInt32(buffer.count)
        var central = Data()

        for e in entradas {
            let nombreBytes = Array(e.nombre.utf8)
            var h = Data()
            h.appendLE32(0x02014b50)          // firma directorio central
            h.appendLE16(20)                  // versión creador
            h.appendLE16(20)                  // versión necesaria
            h.appendLE16(0)                   // flags
            h.appendLE16(0)                   // método
            h.appendLE16(0)                   // hora
            h.appendLE16(0)                   // fecha
            h.appendLE32(e.crc)
            h.appendLE32(e.tam)               // comprimido
            h.appendLE32(e.tam)               // sin comprimir
            h.appendLE16(UInt16(nombreBytes.count))
            h.appendLE16(0)                   // extra
            h.appendLE16(0)                   // comentario
            h.appendLE16(0)                   // nº disco
            h.appendLE16(0)                   // attrs internos
            h.appendLE32(0)                   // attrs externos
            h.appendLE32(e.offset)
            h.append(contentsOf: nombreBytes)
            central.append(h)
        }

        buffer.append(central)

        var fin = Data()
        fin.appendLE32(0x06054b50)            // firma EOCD
        fin.appendLE16(0)                     // nº disco
        fin.appendLE16(0)                     // disco del central
        fin.appendLE16(UInt16(entradas.count))
        fin.appendLE16(UInt16(entradas.count))
        fin.appendLE32(UInt32(central.count))
        fin.appendLE32(inicioCentral)
        fin.appendLE16(0)                     // comentario
        buffer.append(fin)

        return buffer
    }
}

private extension Data {
    mutating func appendLE16(_ v: UInt16) {
        append(UInt8(v & 0xFF))
        append(UInt8((v >> 8) & 0xFF))
    }
    mutating func appendLE32(_ v: UInt32) {
        append(UInt8(v & 0xFF))
        append(UInt8((v >> 8) & 0xFF))
        append(UInt8((v >> 16) & 0xFF))
        append(UInt8((v >> 24) & 0xFF))
    }
}
