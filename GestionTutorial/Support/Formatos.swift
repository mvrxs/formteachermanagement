//
//  Formatos.swift
//  GestionTutorial
//
//  Formateadores de fecha reutilizables (locale es_ES).
//

import Foundation

enum Formatos {
    /// 13 sept 2026
    static let fechaMedia: Date.FormatStyle = Date.FormatStyle(date: .abbreviated, time: .omitted)
        .locale(Locale(identifier: "es_ES"))

    /// 13 de septiembre de 2026
    static let fechaLarga: Date.FormatStyle = Date.FormatStyle(date: .long, time: .omitted)
        .locale(Locale(identifier: "es_ES"))

    /// 13/09/2026 14:30
    static let fechaHora: Date.FormatStyle = Date.FormatStyle(date: .numeric, time: .shortened)
        .locale(Locale(identifier: "es_ES"))
}
