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
    static let idioma           = "idioma"
}

enum Idioma: String, CaseIterable, Identifiable {
    case sistema = "sistema"
    case catalan = "ca"
    case espanol = "es"
    case ingles = "en"
    case aleman = "de"
    case frances = "fr"

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .sistema: return "Sistema"
        case .catalan: return "Català"
        case .espanol: return "Español"
        case .ingles:  return "English"
        case .aleman:  return "Deutsch"
        case .frances: return "Français"
        }
    }

    /// Código de idioma, o `nil` para "seguir al sistema".
    var codigo: String? { self == .sistema ? nil : rawValue }

    /// Locale correspondiente (nil = sistema).
    var locale: Locale? { codigo.map { Locale(identifier: $0) } }

    /// Orden en el selector: Sistema, y Català como primera opción de idioma.
    static var ordenados: [Idioma] { [.sistema, .catalan, .espanol, .ingles, .aleman, .frances] }
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
            ClaveAjuste.idioma: Idioma.sistema.rawValue,
        ])
    }

    static var autoSyncNuevas: Bool { d.bool(forKey: ClaveAjuste.autoSyncNuevas) }
    static var duracionEvento: TimeInterval { TimeInterval(max(15, d.integer(forKey: ClaveAjuste.duracionEventoMin)) * 60) }
    static var recordatorioMinutos: Int { d.integer(forKey: ClaveAjuste.recordatorioMin) }
    static var cursoInicio: Date { Date(timeIntervalSinceReferenceDate: d.double(forKey: ClaveAjuste.cursoInicio)) }
    static var cursoFin: Date { Date(timeIntervalSinceReferenceDate: d.double(forKey: ClaveAjuste.cursoFin)) }

    static var idioma: Idioma { Idioma(rawValue: d.string(forKey: ClaveAjuste.idioma) ?? "") ?? .sistema }
}
