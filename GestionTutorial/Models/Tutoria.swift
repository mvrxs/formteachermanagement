//
//  Tutoria.swift
//  GestionTutorial
//
//  Registro de una sesión de tutoría vinculada a un alumno.
//

import Foundation
import SwiftData

@Model
final class Tutoria {
    var fecha: Date

    /// Si la tutoría llegó a realizarse (por si se planifica y luego se cancela).
    var realizada: Bool

    /// Modalidad almacenada como raw String de `Modalidad`.
    var modalidadRaw: String

    /// Con quién se realizó, raw String de `Interlocutor`.
    var interlocutorRaw: String

    /// Detalle libre cuando el interlocutor es "otro".
    var interlocutorOtro: String

    var temasTratados: String
    var acuerdos: String

    /// Notas largas: aquí se pega el resumen/transcripción de una grabación.
    var notasTranscripcion: String

    var fechaCreacion: Date

    /// Identificador del evento en el Calendario de macOS (EventKit), si está sincronizado.
    var eventKitIdentifier: String?

    // MARK: - Relación
    var alumno: Alumno?

    init(
        fecha: Date = .now,
        realizada: Bool = true,
        modalidad: Modalidad = .presencial,
        interlocutor: Interlocutor = .alumno,
        interlocutorOtro: String = "",
        temasTratados: String = "",
        acuerdos: String = "",
        notasTranscripcion: String = "",
        fechaCreacion: Date = .now,
        alumno: Alumno? = nil
    ) {
        self.fecha = fecha
        self.realizada = realizada
        self.modalidadRaw = modalidad.rawValue
        self.interlocutorRaw = interlocutor.rawValue
        self.interlocutorOtro = interlocutorOtro
        self.temasTratados = temasTratados
        self.acuerdos = acuerdos
        self.notasTranscripcion = notasTranscripcion
        self.fechaCreacion = fechaCreacion
        self.alumno = alumno
    }
}

extension Tutoria {
    /// Acceso tipado a la modalidad.
    var modalidad: Modalidad {
        get { Modalidad(rawValue: modalidadRaw) ?? .presencial }
        set { modalidadRaw = newValue.rawValue }
    }

    /// Acceso tipado al interlocutor.
    var interlocutor: Interlocutor {
        get { Interlocutor(rawValue: interlocutorRaw) ?? .alumno }
        set { interlocutorRaw = newValue.rawValue }
    }
}

enum Modalidad: String, CaseIterable, Identifiable {
    case presencial = "Presencial"
    case online = "Online"
    var id: String { rawValue }
}

enum Interlocutor: String, CaseIterable, Identifiable {
    case alumno = "Alumno/a"
    case padre = "Padre"
    case madre = "Madre"
    case tutorLegal = "Tutor legal"
    case otro = "Otro"
    var id: String { rawValue }
}
