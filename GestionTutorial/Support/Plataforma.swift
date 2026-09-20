//
//  Plataforma.swift
//  GestionTutorial
//
//  Capa de compatibilidad macOS/iOS: imágenes, colores del sistema, abrir URLs
//  y un documento genérico para exportar con .fileExporter en ambas plataformas.
//

import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum Plataforma {
    /// Bytes PNG de una imagen del catálogo de assets, por nombre.
    static func pngDeAsset(_ nombre: String) -> Data? {
        #if os(macOS)
        guard let img = NSImage(named: nombre),
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
        #else
        return UIImage(named: nombre)?.pngData()
        #endif
    }

    /// Abre una URL en el navegador/app correspondiente.
    static func abrir(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }
}

// MARK: - Modificadores multiplataforma

extension View {
    /// Subtítulo de navegación (solo macOS; en iOS no hace nada).
    @ViewBuilder
    func subtituloNavegacion(_ texto: String) -> some View {
        #if os(macOS)
        self.navigationSubtitle(texto)
        #else
        self
        #endif
    }
}

// MARK: - Colores del sistema multiplataforma

extension Color {
    /// Fondo de tarjeta agrupada.
    static var fondoTarjeta: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    /// Color de separación fina.
    static var separadorSistema: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }
}

// MARK: - Imagen desde Data multiplataforma

extension Image {
    /// Crea una `Image` de SwiftUI a partir de datos de imagen (JPEG/PNG…).
    init?(datosImagen data: Data) {
        #if os(macOS)
        guard let img = NSImage(data: data) else { return nil }
        self = Image(nsImage: img)
        #else
        guard let img = UIImage(data: data) else { return nil }
        self = Image(uiImage: img)
        #endif
    }
}

// MARK: - Documento para exportar (.fileExporter, macOS + iOS)

struct DocumentoDatos: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    static var writableContentTypes: [UTType] { [.data, .commaSeparatedText, UTType(filenameExtension: "pptx") ?? .data, UTType(filenameExtension: "xlsx") ?? .data] }

    var datos: Data
    var tipo: UTType

    init(datos: Data, tipo: UTType) {
        self.datos = datos
        self.tipo = tipo
    }

    init(configuration: ReadConfiguration) throws {
        datos = configuration.file.regularFileContents ?? Data()
        tipo = .data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: datos)
    }
}
