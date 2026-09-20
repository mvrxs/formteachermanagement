//
//  Imagenes.swift
//  GestionTutorial
//
//  Utilidades para cargar y redimensionar fotos de alumno antes de guardarlas.
//  Multiplataforma: usa AppKit en macOS y UIKit en iOS.
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ImagenUtil {
    /// Carga una imagen desde un archivo, la redimensiona y devuelve JPEG.
    static func jpegRedimensionado(desde url: URL, maxLado: CGFloat = 512, calidad: CGFloat = 0.8) -> Data? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return jpegRedimensionado(cgImage: cg, maxLado: maxLado, calidad: calidad)
    }

    /// Redimensiona una imagen (bytes) manteniendo proporción y la codifica como JPEG.
    static func jpegRedimensionado(datos: Data, maxLado: CGFloat = 512, calidad: CGFloat = 0.8) -> Data? {
        guard let src = CGImageSourceCreateWithData(datos as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return jpegRedimensionado(cgImage: cg, maxLado: maxLado, calidad: calidad)
    }

    /// Redimensiona un `CGImage` y lo codifica como JPEG. Independiente de plataforma.
    static func jpegRedimensionado(cgImage cg: CGImage, maxLado: CGFloat = 512, calidad: CGFloat = 0.8) -> Data? {
        let ancho = CGFloat(cg.width), alto = CGFloat(cg.height)
        guard ancho > 0, alto > 0 else { return nil }

        let escala = min(1, maxLado / max(ancho, alto))
        let dw = Int((ancho * escala).rounded(.down))
        let dh = Int((alto * escala).rounded(.down))
        guard dw > 0, dh > 0 else { return nil }

        let espacio = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: dw, height: dh,
            bitsPerComponent: 8, bytesPerRow: 0, space: espacio,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: dw, height: dh))
        guard let redim = ctx.makeImage() else { return nil }

        let salida = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(salida, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, redim, [kCGImageDestinationLossyCompressionQuality: calidad] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return salida as Data
    }
}
