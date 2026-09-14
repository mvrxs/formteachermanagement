//
//  Imagenes.swift
//  GestionTutorial
//
//  Utilidades para cargar y redimensionar fotos de alumno antes de guardarlas.
//

import AppKit

enum ImagenUtil {
    /// Carga una imagen desde un archivo, la redimensiona y devuelve JPEG.
    static func jpegRedimensionado(desde url: URL, maxLado: CGFloat = 512, calidad: CGFloat = 0.8) -> Data? {
        guard let imagen = NSImage(contentsOf: url) else { return nil }
        return jpegRedimensionado(imagen: imagen, maxLado: maxLado, calidad: calidad)
    }

    /// Redimensiona una NSImage manteniendo proporción y la codifica como JPEG.
    static func jpegRedimensionado(imagen: NSImage, maxLado: CGFloat = 512, calidad: CGFloat = 0.8) -> Data? {
        let original = imagen.size
        guard original.width > 0, original.height > 0 else { return nil }

        let escala = min(1, maxLado / max(original.width, original.height))
        let destino = NSSize(width: floor(original.width * escala),
                             height: floor(original.height * escala))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(destino.width),
            pixelsHigh: Int(destino.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        rep.size = destino

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        imagen.draw(in: NSRect(origin: .zero, size: destino),
                    from: NSRect(origin: .zero, size: original),
                    operation: .copy,
                    fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .jpeg, properties: [.compressionFactor: calidad])
    }
}
