//
//  Alumno.swift
//  GestionTutorial
//
//  Modelo principal. Datos sensibles de menores — almacenamiento SIEMPRE local.
//

import Foundation
import SwiftData

@Model
final class Alumno {
    // MARK: - Identidad
    var apellidos: String
    var nombre: String
    var fechaNacimiento: Date?
    var poblacionNacimiento: String

    /// Número de documento (DNI/NIE). El tipo se deriva con `tipoDocumento`.
    var numeroDocumento: String

    // MARK: - Contacto del alumno
    var telefono: String
    var email: String
    var direccionActual: String
    var codigoPostal: String
    var localidadActual: String

    // MARK: - Familia / tutores
    var nombrePadre: String
    var nombreMadre: String

    var telefonoTutor1: String
    var emailTutor1: String
    var telefonoTutor2: String
    var emailTutor2: String

    /// Tutor legal, cuando difiere de padre/madre (acogida, tutela, etc.).
    var tutorLegal: String
    var telefonoTutorLegal: String

    /// Situación familiar delicada: padres separados o que no se hablan.
    var padresSeparados: Bool
    var padresNoSeHablan: Bool

    // MARK: - Autorizaciones y académico
    // Valor por defecto EN LA DECLARACIÓN (no solo en el init): SwiftData lo usa
    // como default del esquema para migrar filas existentes sin romper el store.
    /// Autorización de comunicación con la familia firmada (relevante al ser mayor de edad).
    var autorizacionComunicacionFirmada: Bool = false
    /// El alumno se niega a firmar la autorización (distinto de "aún pendiente").
    var rechazaFirmarAutorizacion: Bool = false
    /// Inglés convalidado / exento.
    var inglesConvalidado: Bool = false

    // MARK: - Prácticas, convalidaciones y situación
    /// Realiza / tiene prácticas (FCT).
    var tienePracticas: Bool = false
    /// Empresa de prácticas (si aplica).
    var empresaPracticas: String = ""
    /// Convalidación por experiencia laboral, raw String de `ConvalidacionExperiencia`.
    var convalidacionExperienciaRaw: String = ConvalidacionExperiencia.ninguna.rawValue
    /// Horas acreditadas en vida laboral (se requieren 1000 para convalidar por experiencia).
    var horasVidaLaboral: Int = 0
    /// Asignaturas convalidadas (texto libre, una por línea o separadas por comas).
    var asignaturasConvalidadas: String = ""
    /// Alumno emancipado.
    var emancipado: Bool = false

    // MARK: - Salud / notas
    var alergiasMedico: String
    var observaciones: String

    /// Foto del alumno (JPEG redimensionado). Guardada en disco aparte del store.
    @Attribute(.externalStorage) var foto: Data?

    // MARK: - Metadatos
    var fechaCreacion: Date

    // MARK: - Relaciones
    @Relationship(deleteRule: .cascade, inverse: \Tutoria.alumno)
    var tutorias: [Tutoria] = []

    @Relationship(deleteRule: .cascade, inverse: \NecesidadEspecial.alumno)
    var necesidades: [NecesidadEspecial] = []

    init(
        apellidos: String = "",
        nombre: String = "",
        fechaNacimiento: Date? = nil,
        poblacionNacimiento: String = "",
        numeroDocumento: String = "",
        telefono: String = "",
        email: String = "",
        direccionActual: String = "",
        codigoPostal: String = "",
        localidadActual: String = "",
        nombrePadre: String = "",
        nombreMadre: String = "",
        telefonoTutor1: String = "",
        emailTutor1: String = "",
        telefonoTutor2: String = "",
        emailTutor2: String = "",
        tutorLegal: String = "",
        telefonoTutorLegal: String = "",
        padresSeparados: Bool = false,
        padresNoSeHablan: Bool = false,
        autorizacionComunicacionFirmada: Bool = false,
        rechazaFirmarAutorizacion: Bool = false,
        inglesConvalidado: Bool = false,
        tienePracticas: Bool = false,
        empresaPracticas: String = "",
        convalidacionExperiencia: ConvalidacionExperiencia = .ninguna,
        horasVidaLaboral: Int = 0,
        asignaturasConvalidadas: String = "",
        emancipado: Bool = false,
        alergiasMedico: String = "",
        observaciones: String = "",
        foto: Data? = nil,
        fechaCreacion: Date = .now
    ) {
        self.apellidos = apellidos
        self.nombre = nombre
        self.fechaNacimiento = fechaNacimiento
        self.poblacionNacimiento = poblacionNacimiento
        self.numeroDocumento = numeroDocumento
        self.telefono = telefono
        self.email = email
        self.direccionActual = direccionActual
        self.codigoPostal = codigoPostal
        self.localidadActual = localidadActual
        self.nombrePadre = nombrePadre
        self.nombreMadre = nombreMadre
        self.telefonoTutor1 = telefonoTutor1
        self.emailTutor1 = emailTutor1
        self.telefonoTutor2 = telefonoTutor2
        self.emailTutor2 = emailTutor2
        self.tutorLegal = tutorLegal
        self.telefonoTutorLegal = telefonoTutorLegal
        self.padresSeparados = padresSeparados
        self.padresNoSeHablan = padresNoSeHablan
        self.autorizacionComunicacionFirmada = autorizacionComunicacionFirmada
        self.rechazaFirmarAutorizacion = rechazaFirmarAutorizacion
        self.inglesConvalidado = inglesConvalidado
        self.tienePracticas = tienePracticas
        self.empresaPracticas = empresaPracticas
        self.convalidacionExperienciaRaw = convalidacionExperiencia.rawValue
        self.horasVidaLaboral = horasVidaLaboral
        self.asignaturasConvalidadas = asignaturasConvalidadas
        self.emancipado = emancipado
        self.alergiasMedico = alergiasMedico
        self.observaciones = observaciones
        self.foto = foto
        self.fechaCreacion = fechaCreacion
    }
}

// MARK: - Propiedades calculadas (no persistidas)

extension Alumno {
    /// Nombre para mostrar en listas: "Apellidos, Nombre".
    var nombreCompleto: String {
        let a = apellidos.trimmingCharacters(in: .whitespaces)
        let n = nombre.trimmingCharacters(in: .whitespaces)
        switch (a.isEmpty, n.isEmpty) {
        case (false, false): return "\(a), \(n)"
        case (false, true):  return a
        case (true, false):  return n
        case (true, true):   return "(Sin nombre)"
        }
    }

    /// Tipo de documento derivado del primer carácter: NIE si empieza por X/Y/Z, si no DNI.
    var tipoDocumento: TipoDocumento {
        guard let primera = numeroDocumento
            .trimmingCharacters(in: .whitespaces)
            .uppercased()
            .first
        else { return .desconocido }

        return "XYZ".contains(primera) ? .nie : .dni
    }

    /// Edad actual en años cumplidos. `nil` si no hay fecha de nacimiento.
    var edad: Int? {
        guard let fechaNacimiento else { return nil }
        return Calendar.current.dateComponents([.year], from: fechaNacimiento, to: .now).year
    }

    /// Fecha exacta en que el alumno cumple (o cumplió) 18 años.
    var fechaCumple18: Date? {
        guard let fechaNacimiento else { return nil }
        return Calendar.current.date(byAdding: .year, value: 18, to: fechaNacimiento)
    }

    /// `true` si ya es mayor de edad hoy.
    var esMayorDeEdad: Bool {
        guard let edad else { return false }
        return edad >= 18
    }

    /// Fecha en que cumple 18 SI cae dentro del curso 2026/27 (14/09/2026 – 31/05/2027).
    /// `nil` si no aplica (ya los cumplió antes, o los cumple después).
    var cumple18DuranteCurso: Date? {
        guard let fechaCumple18 else { return nil }
        let cal = Calendar.current
        let inicio = Ajustes.cursoInicio
        let fin = Ajustes.cursoFin
        let dia = cal.startOfDay(for: fechaCumple18)
        return (dia >= cal.startOfDay(for: inicio) && dia <= cal.startOfDay(for: fin)) ? fechaCumple18 : nil
    }
}

enum TipoDocumento: String {
    case dni = "DNI"
    case nie = "NIE"
    case desconocido = "—"
}

// MARK: - Estado de edad (para filtros y simbología)

extension Alumno {
    /// Clasificación por edad usada en filtros e iconos de la lista.
    var estadoEdad: EstadoEdad {
        if esMayorDeEdad { return .mayor }
        if cumple18DuranteCurso != nil { return .cumpleEsteCurso }
        return .menor
    }

    /// Estado de la autorización de comunicación.
    var estadoAutorizacion: EstadoAutorizacion {
        if autorizacionComunicacionFirmada { return .firmada }
        if rechazaFirmarAutorizacion { return .rechazada }
        if esMayorDeEdad { return .pendiente }
        return .noAplica
    }

    /// Mayor de edad con la autorización aún pendiente de firmar.
    var autorizacionPendiente: Bool { estadoAutorizacion == .pendiente }

    /// Tiene convalidación de cualquier tipo (inglés, experiencia o asignaturas).
    var tieneAlgunaConvalidacion: Bool {
        inglesConvalidado || tieneConvalidacionExperiencia || tieneAsignaturasConvalidadas
    }

    /// Acceso tipado a la convalidación por experiencia laboral.
    var convalidacionExperiencia: ConvalidacionExperiencia {
        get { ConvalidacionExperiencia(rawValue: convalidacionExperienciaRaw) ?? .ninguna }
        set { convalidacionExperienciaRaw = newValue.rawValue }
    }

    /// Tiene convalidación por experiencia laboral marcada.
    var tieneConvalidacionExperiencia: Bool {
        convalidacionExperiencia != .ninguna
    }

    /// Convalidación por experiencia marcada pero sin las 1000 h requeridas.
    var horasExperienciaInsuficientes: Bool {
        tieneConvalidacionExperiencia && horasVidaLaboral < 1000
    }

    /// Tiene alguna asignatura convalidada (texto no vacío).
    var tieneAsignaturasConvalidadas: Bool {
        !asignaturasConvalidadas.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum EstadoAutorizacion {
    case noAplica    // menor sin firmar / sin rechazar
    case pendiente   // mayor de edad, aún sin firmar
    case firmada
    case rechazada   // no quiere firmar
}

enum ConvalidacionExperiencia: String, CaseIterable, Identifiable {
    case ninguna = "Ninguna"
    case sector50 = "Del sector (50%)"
    case noSector25 = "Fuera del sector (25%)"
    var id: String { rawValue }

    /// Porcentaje convalidable, para mostrar de forma compacta.
    var porcentaje: Int {
        switch self {
        case .ninguna:    return 0
        case .sector50:   return 50
        case .noSector25: return 25
        }
    }
}

enum EstadoEdad: String, CaseIterable, Identifiable {
    case menor = "Menores"
    case cumpleEsteCurso = "Cumplen 18 este curso"
    case mayor = "Mayores de edad"

    var id: String { rawValue }

    /// Símbolo SF que identifica cada estado.
    var simbolo: String {
        switch self {
        case .menor:           return "person.fill"
        case .cumpleEsteCurso: return "hourglass.circle.fill"
        case .mayor:           return "checkmark.seal.fill"
        }
    }
}
