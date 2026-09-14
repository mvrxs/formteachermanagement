//
//  ComponentesGlass.swift
//  GestionTutorial
//
//  Componentes de la CAPA DE CONTENIDO. Según la guía de Apple para Liquid Glass,
//  el glass va en la capa de navegación (sidebar y toolbars, que el sistema aplica
//  solo en macOS 26). El contenido que scrollea NO debe llevar glass: usa fills,
//  materiales estándar y vibrancy para no "colisionar" con la capa de navegación.
//

import SwiftUI

/// Tarjeta de agrupación para la capa de contenido. Fondo sólido de control +
/// borde de separación (no Liquid Glass), como las tarjetas agrupadas de macOS.
struct TarjetaSeccion<Contenido: View>: View {
    var titulo: String?
    var simbolo: String?
    @ViewBuilder var contenido: Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let titulo {
                Label {
                    Text(titulo)
                        .font(.headline)
                } icon: {
                    if let simbolo {
                        Image(systemName: simbolo)
                            .foregroundStyle(.secondary)
                    }
                }
                .labelStyle(.titleAndIcon)
            }
            contenido
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

/// Campo de texto etiquetado para las fichas editables.
struct CampoEtiquetado: View {
    var etiqueta: String
    @Binding var valor: String
    var prompt: String = ""
    var eje: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(etiqueta)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(prompt.isEmpty ? etiqueta : prompt, text: $valor, axis: eje)
                .textFieldStyle(.plain)
                .lineLimit(eje == .vertical ? 10 : 1)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        }
    }
}

/// Avatar circular del alumno: muestra la foto si existe, si no un marcador.
struct AvatarAlumno: View {
    var foto: Data?
    var tamano: CGFloat = 56

    var body: some View {
        Group {
            if let foto, let imagen = NSImage(data: foto) {
                Image(nsImage: imagen)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: tamano, height: tamano)
        .clipShape(.circle)
    }
}

/// Etiqueta compacta tipo "chip" para avisos. Sobre la capa de contenido usa un
/// fill teñido con vibrancy (no glass), como recomienda Apple para elementos
/// que van encima de otra superficie.
struct Chip: View {
    var texto: String
    var simbolo: String
    var tinte: Color

    var body: some View {
        Label(texto, systemImage: simbolo)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(tinte)
            .background(tinte.opacity(0.15), in: .capsule)
    }
}
