//
//  Ajustes.swift
//  GestionTutorial
//
//  Preferencias de la app (UserDefaults). Accesibles desde vistas con @AppStorage
//  y desde código no-vista mediante `Ajustes`.
//

import SwiftUI

enum ClaveAjuste {
    static let autoSyncNuevas   = "sync.autoNuevas"
    static let duracionEventoMin = "sync.duracionMin"
    static let recordatorioMin  = "sync.recordatorioMin"
    static let cursoInicio      = "curso.inicio"
    static let cursoFin         = "curso.fin"
    static let apariencia       = "apariencia"
    static let modalidadDefecto = "tutoria.modalidadDefecto"
}

enum Apariencia: String, CaseIterable, Identifiable {
    case sistema = "Sistema"
    case claro = "Claro"
    case oscuro = "Oscuro"
    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .sistema: return nil
        case .claro:   return .light
        case .oscuro:  return .dark
        }
    }
}

/// Acceso de solo lectura a las preferencias desde lógica no-vista.
enum Ajustes {
    private static var d: UserDefaults { .standard }

    /// Registra los valores por defecto. Llamar al arrancar la app.
    static func registrarPorDefecto() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let inicio = cal.date(from: DateComponents(year: 2026, month: 9, day: 14)) ?? .now
        let fin = cal.date(from: DateComponents(year: 2027, month: 5, day: 31)) ?? .now

        d.register(defaults: [
            ClaveAjuste.autoSyncNuevas: false,
            ClaveAjuste.duracionEventoMin: 60,
            ClaveAjuste.recordatorioMin: -1,        // -1 = sin recordatorio
            ClaveAjuste.cursoInicio: inicio.timeIntervalSinceReferenceDate,
            ClaveAjuste.cursoFin: fin.timeIntervalSinceReferenceDate,
            ClaveAjuste.apariencia: Apariencia.sistema.rawValue,
            ClaveAjuste.modalidadDefecto: Modalidad.presencial.rawValue,
        ])
    }

    static var autoSyncNuevas: Bool { d.bool(forKey: ClaveAjuste.autoSyncNuevas) }
    static var duracionEvento: TimeInterval { TimeInterval(max(15, d.integer(forKey: ClaveAjuste.duracionEventoMin)) * 60) }
    static var recordatorioMinutos: Int { d.integer(forKey: ClaveAjuste.recordatorioMin) }
    static var cursoInicio: Date { Date(timeIntervalSinceReferenceDate: d.double(forKey: ClaveAjuste.cursoInicio)) }
    static var cursoFin: Date { Date(timeIntervalSinceReferenceDate: d.double(forKey: ClaveAjuste.cursoFin)) }
    static var modalidadDefecto: Modalidad {
        Modalidad(rawValue: d.string(forKey: ClaveAjuste.modalidadDefecto) ?? "") ?? .presencial
    }
}
