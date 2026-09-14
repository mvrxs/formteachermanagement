//
//  SincronizadorCalendario.swift
//  GestionTutorial
//
//  Sincroniza tutorías con el Calendario nativo de macOS (EventKit).
//

import EventKit
import Foundation

@MainActor
final class SincronizadorCalendario {
    static let shared = SincronizadorCalendario()
    private let store = EKEventStore()

    private init() {}

    /// Solicita acceso de escritura al calendario. Devuelve si se concedió.
    func solicitarAcceso() async -> Bool {
        if #available(macOS 14.0, *) {
            return (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            return (try? await store.requestAccess(to: .event)) ?? false
        }
    }

    /// Crea o actualiza el evento asociado a la tutoría y guarda su identificador.
    /// Devuelve un mensaje de error si falla, o `nil` si fue bien.
    @discardableResult
    func sincronizar(_ tutoria: Tutoria) async -> String? {
        guard await solicitarAcceso() else {
            return "Sin permiso para acceder al Calendario. Actívalo en Ajustes › Privacidad › Calendarios."
        }

        let evento: EKEvent
        if let id = tutoria.eventKitIdentifier, let existente = store.event(withIdentifier: id) {
            evento = existente
        } else {
            evento = EKEvent(eventStore: store)
            guard let calendario = store.defaultCalendarForNewEvents else {
                return "No hay un calendario de escritura por defecto configurado."
            }
            evento.calendar = calendario
        }

        evento.title = "Tutoría · " + (tutoria.alumno?.nombreCompleto ?? "Sin alumno")
        evento.startDate = tutoria.fecha
        evento.endDate = tutoria.fecha.addingTimeInterval(Ajustes.duracionEvento)
        evento.notes = [
            "Modalidad: \(tutoria.modalidad.rawValue)",
            "Con: \(tutoria.interlocutor.rawValue)",
            tutoria.temasTratados.isEmpty ? "" : "Temas: \(tutoria.temasTratados)",
            tutoria.acuerdos.isEmpty ? "" : "Acuerdos: \(tutoria.acuerdos)",
        ].filter { !$0.isEmpty }.joined(separator: "\n")

        // Recordatorio según ajustes (-1 = ninguno).
        evento.alarms?.forEach { evento.removeAlarm($0) }
        let recordatorio = Ajustes.recordatorioMinutos
        if recordatorio >= 0 {
            evento.addAlarm(EKAlarm(relativeOffset: TimeInterval(-recordatorio * 60)))
        }

        do {
            try store.save(evento, span: .thisEvent)
            tutoria.eventKitIdentifier = evento.eventIdentifier
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Elimina del Calendario el evento con ese identificador (si existe).
    func eliminar(identificador: String?) async {
        guard let id = identificador,
              await solicitarAcceso(),
              let evento = store.event(withIdentifier: id) else { return }
        try? store.remove(evento, span: .thisEvent)
    }
}
