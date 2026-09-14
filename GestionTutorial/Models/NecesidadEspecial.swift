//
//  NecesidadEspecial.swift
//  GestionTutorial
//
//  Necesidad educativa / diagnóstico vinculado a un alumno. Dato muy sensible.
//

import Foundation
import SwiftData

@Model
final class NecesidadEspecial {
    /// Tipo almacenado como raw String de `TipoNecesidad`.
    var tipoRaw: String

    var descripcionDiagnostico: String
    var adaptacionesAplicadas: String
    var observaciones: String

    var fechaCreacion: Date

    // MARK: - Relación
    var alumno: Alumno?

    init(
        tipo: TipoNecesidad = .otra,
        descripcionDiagnostico: String = "",
        adaptacionesAplicadas: String = "",
        observaciones: String = "",
        fechaCreacion: Date = .now,
        alumno: Alumno? = nil
    ) {
        self.tipoRaw = tipo.rawValue
        self.descripcionDiagnostico = descripcionDiagnostico
        self.adaptacionesAplicadas = adaptacionesAplicadas
        self.observaciones = observaciones
        self.fechaCreacion = fechaCreacion
        self.alumno = alumno
    }
}

extension NecesidadEspecial {
    var tipo: TipoNecesidad {
        get { TipoNecesidad(rawValue: tipoRaw) ?? .otra }
        set { tipoRaw = newValue.rawValue }
    }
}

enum TipoNecesidad: String, CaseIterable, Identifiable {
    case tea = "TEA / Autismo"
    case dislexia = "Dislexia"
    case tdah = "TDAH"
    case auditiva = "Discapacidad auditiva"
    case visual = "Discapacidad visual"
    case motriz = "Discapacidad motriz"
    case otra = "Otra"
    var id: String { rawValue }

    /// Símbolo SF para pintar cada tipo en la interfaz.
    var simbolo: String {
        switch self {
        case .tea:      return "brain.head.profile"
        case .dislexia: return "textformat.abc"
        case .tdah:     return "bolt.fill"
        case .auditiva: return "ear.fill"
        case .visual:   return "eye.fill"
        case .motriz:   return "figure.roll"
        case .otra:     return "cross.case.fill"
        }
    }
}
