//
//  CSV.swift
//  GestionTutorial
//
//  Parser CSV (comillas, comas internas, "" escapadas) y auto-mapeo de columnas
//  al modelo Alumno para la importación desde Alexia.
//

import Foundation

enum CSV {
    /// Parsea texto CSV a filas de campos según RFC 4180. Soporta campos
    /// entrecomillados con comas y saltos de línea internos, y comillas dobles
    /// escapadas ("") como comilla literal.
    ///
    /// Opera sobre `unicodeScalars` (no `Character`) porque en Swift la secuencia
    /// CRLF ("\r\n") es UN solo grapheme cluster: iterando por `Character` nunca
    /// casaría con "\r" ni "\n" y los saltos de línea se perderían.
    static func parsear(_ texto: String, separador: Character = ",") -> [[String]] {
        let sep: Unicode.Scalar = separador.unicodeScalars.first ?? ","
        let comilla: Unicode.Scalar = "\""
        let cr: Unicode.Scalar = "\r"
        let lf: Unicode.Scalar = "\n"

        var filas: [[String]] = []
        var campo = ""
        var fila: [String] = []
        var enComillas = false

        let escalares = Array(texto.unicodeScalars)
        var i = 0

        func finFila() {
            fila.append(campo); campo = ""
            filas.append(fila); fila = []
        }

        while i < escalares.count {
            let c = escalares[i]
            if enComillas {
                if c == comilla {
                    if i + 1 < escalares.count && escalares[i + 1] == comilla {
                        campo.unicodeScalars.append(comilla)   // "" -> comilla literal
                        i += 1
                    } else {
                        enComillas = false                     // cierra el campo entrecomillado
                    }
                } else {
                    campo.unicodeScalars.append(c)             // coma o salto DENTRO de comillas = dato
                }
            } else {
                switch c {
                case comilla:
                    enComillas = true
                case sep:
                    fila.append(campo); campo = ""
                case cr:
                    // Fin de fila; absorbe el \n de un CRLF si viene a continuación.
                    if i + 1 < escalares.count && escalares[i + 1] == lf { i += 1 }
                    finFila()
                case lf:
                    finFila()
                default:
                    campo.unicodeScalars.append(c)
                }
            }
            i += 1
        }
        // Último campo/fila si el archivo no termina en salto de línea.
        if !campo.isEmpty || !fila.isEmpty {
            fila.append(campo)
            filas.append(fila)
        }
        // Descarta filas totalmente vacías.
        return filas.filter { $0.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }

    /// Detecta el separador más probable mirando la primera línea.
    static func detectarSeparador(_ texto: String) -> Character {
        let primera = texto.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let comas = primera.filter { $0 == "," }.count
        let puntoComas = primera.filter { $0 == ";" }.count
        return puntoComas > comas ? ";" : ","
    }
}

// MARK: - Campo destino

/// Campo del modelo Alumno al que se puede asignar una columna del CSV.
enum CampoDestino: String, CaseIterable, Identifiable {
    case ignorar
    case apellidosNombre        // columna combinada "Apellidos, Nombre"
    case apellidos
    case nombre
    case fechaNacimiento
    case poblacionNacimiento
    case numeroDocumento
    case telefono
    case email
    case nombrePadre
    case nombreMadre
    case telefonoTutor1
    case emailTutor1
    case telefonoTutor2
    case emailTutor2
    case tutorLegal
    case telefonoTutorLegal
    case padresSeparados
    case padresNoSeHablan
    case alergiasMedico
    case direccionActual
    case codigoPostal
    case localidadActual
    case observaciones

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .ignorar:            return "— Ignorar —"
        case .apellidosNombre:    return "Apellidos, Nombre (combinado)"
        case .apellidos:          return "Apellidos"
        case .nombre:             return "Nombre"
        case .fechaNacimiento:    return "Fecha de nacimiento"
        case .poblacionNacimiento:return "Población de nacimiento"
        case .numeroDocumento:    return "Nº documento (DNI/NIE)"
        case .telefono:           return "Teléfono alumno"
        case .email:              return "Email alumno"
        case .nombrePadre:        return "Nombre del padre"
        case .nombreMadre:        return "Nombre de la madre"
        case .telefonoTutor1:     return "Teléfono tutor 1"
        case .emailTutor1:        return "Email tutor 1"
        case .telefonoTutor2:     return "Teléfono tutor 2"
        case .emailTutor2:        return "Email tutor 2"
        case .tutorLegal:         return "Tutor legal"
        case .telefonoTutorLegal: return "Teléfono tutor legal"
        case .padresSeparados:    return "Padres separados"
        case .padresNoSeHablan:   return "Padres no se hablan"
        case .alergiasMedico:     return "Alergias / cuestiones médicas"
        case .direccionActual:    return "Dirección actual"
        case .codigoPostal:       return "Código postal"
        case .localidadActual:    return "Localidad actual"
        case .observaciones:      return "Observaciones"
        }
    }
}

// MARK: - Auto-mapeo

enum MapeoColumnas {
    /// Normaliza una cabecera: sin acentos, minúsculas, sin puntuación, espacios colapsados.
    static func normalizar(_ s: String) -> String {
        let sinAcentos = s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let limpio = sinAcentos.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(limpio).split(separator: " ").joined(separator: " ")
    }

    /// Deduce el campo destino de una cabecera. Primera regla que casa gana.
    static func deducir(_ cabecera: String) -> CampoDestino {
        let h = normalizar(cabecera)
        func tiene(_ ss: String...) -> Bool { ss.allSatisfy { h.contains($0) } }

        if tiene("apellidos", "nombre")            { return .apellidosNombre }
        if h == "apellidos"                        { return .apellidos }
        if h == "nombre"                           { return .nombre }
        if tiene("fecha", "nacimiento")            { return .fechaNacimiento }
        if tiene("poblacion")                      { return .poblacionNacimiento }
        if tiene("documento") || tiene("dni") || tiene("nie") { return .numeroDocumento }
        if tiene("telefono", "legal")              { return .telefonoTutorLegal }
        if tiene("tutor", "legal")                 { return .tutorLegal }
        if tiene("telefono", "tutor", "1")         { return .telefonoTutor1 }
        if tiene("email", "tutor", "1")            { return .emailTutor1 }
        if tiene("telefono", "tutor", "2")         { return .telefonoTutor2 }
        if tiene("email", "tutor", "2")            { return .emailTutor2 }
        if tiene("telefono", "alumno")             { return .telefono }
        if tiene("email", "alumno")                { return .email }
        if tiene("nombre", "padre")                { return .nombrePadre }
        if tiene("nombre", "madre")                { return .nombreMadre }
        if tiene("padres", "separados")            { return .padresSeparados }
        if tiene("padres", "hablan")               { return .padresNoSeHablan }
        if tiene("alergia") || tiene("medic")      { return .alergiasMedico }
        if tiene("direccion")                      { return .direccionActual }
        if tiene("codigo", "postal")               { return .codigoPostal }
        if tiene("localidad")                      { return .localidadActual }
        if tiene("observaciones")                  { return .observaciones }
        if tiene("telefono")                       { return .telefono }
        if tiene("email")                          { return .email }
        return .ignorar
    }

    /// Interpreta un valor de texto como booleano (Sí/x/1/true → true).
    static func esVerdadero(_ v: String) -> Bool {
        let n = normalizar(v)
        return ["si", "s", "x", "1", "true", "verdadero", "yes", "y"].contains(n)
    }

    private static let formatoFecha: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy"
        f.isLenient = false
        return f
    }()

    /// Parsea una fecha dd/MM/yyyy (europea). Acepta también dd-MM-yyyy.
    static func parsearFecha(_ v: String) -> Date? {
        let limpio = v.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "-", with: "/")
        guard !limpio.isEmpty else { return nil }
        return formatoFecha.date(from: limpio)
    }
}

// MARK: - Alumno importado (previsualización)

/// Resultado de aplicar el mapeo a una fila del CSV, con marcas de duplicado.
struct AlumnoImportado: Identifiable {
    let id = UUID()
    var apellidos = ""
    var nombre = ""
    var fechaNacimiento: Date?
    var fechaNacimientoTextoInvalido: String?   // texto original si no se pudo parsear
    var poblacionNacimiento = ""
    var numeroDocumento = ""
    var telefono = ""
    var email = ""
    var nombrePadre = ""
    var nombreMadre = ""
    var telefonoTutor1 = ""
    var emailTutor1 = ""
    var telefonoTutor2 = ""
    var emailTutor2 = ""
    var tutorLegal = ""
    var telefonoTutorLegal = ""
    var padresSeparados = false
    var padresNoSeHablan = false
    var alergiasMedico = ""
    var direccionActual = ""
    var codigoPostal = ""
    var localidadActual = ""
    var observaciones = ""

    var duplicadoDNI = false
    var duplicadoNombre = false

    var nombreMostrar: String {
        apellidos.isEmpty ? nombre : (nombre.isEmpty ? apellidos : "\(apellidos), \(nombre)")
    }

    /// Construye un AlumnoImportado a partir de una fila y el mapeo de columnas.
    static func desde(fila: [String], mapeo: [CampoDestino]) -> AlumnoImportado {
        var a = AlumnoImportado()
        for (idx, destino) in mapeo.enumerated() where idx < fila.count {
            let valor = fila[idx].trimmingCharacters(in: .whitespaces)
            switch destino {
            case .ignorar: break
            case .apellidosNombre:
                if let coma = valor.firstIndex(of: ",") {
                    a.apellidos = String(valor[..<coma]).trimmingCharacters(in: .whitespaces)
                    a.nombre = String(valor[valor.index(after: coma)...]).trimmingCharacters(in: .whitespaces)
                } else {
                    a.apellidos = valor
                }
            case .apellidos:          a.apellidos = valor
            case .nombre:             a.nombre = valor
            case .fechaNacimiento:
                if valor.isEmpty { break }
                if let f = MapeoColumnas.parsearFecha(valor) { a.fechaNacimiento = f }
                else { a.fechaNacimientoTextoInvalido = valor }
            case .poblacionNacimiento:a.poblacionNacimiento = valor
            case .numeroDocumento:    a.numeroDocumento = valor
            case .telefono:           a.telefono = valor
            case .email:              a.email = valor
            case .nombrePadre:        a.nombrePadre = valor
            case .nombreMadre:        a.nombreMadre = valor
            case .telefonoTutor1:     a.telefonoTutor1 = valor
            case .emailTutor1:        a.emailTutor1 = valor
            case .telefonoTutor2:     a.telefonoTutor2 = valor
            case .emailTutor2:        a.emailTutor2 = valor
            case .tutorLegal:         a.tutorLegal = valor
            case .telefonoTutorLegal: a.telefonoTutorLegal = valor
            case .padresSeparados:    a.padresSeparados = MapeoColumnas.esVerdadero(valor)
            case .padresNoSeHablan:   a.padresNoSeHablan = MapeoColumnas.esVerdadero(valor)
            case .alergiasMedico:     a.alergiasMedico = valor
            case .direccionActual:    a.direccionActual = valor
            case .codigoPostal:       a.codigoPostal = valor
            case .localidadActual:    a.localidadActual = valor
            case .observaciones:      a.observaciones = valor
            }
        }
        return a
    }

    /// Convierte a un modelo Alumno persistible.
    func aAlumno() -> Alumno {
        Alumno(
            apellidos: apellidos,
            nombre: nombre,
            fechaNacimiento: fechaNacimiento,
            poblacionNacimiento: poblacionNacimiento,
            numeroDocumento: numeroDocumento,
            telefono: telefono,
            email: email,
            direccionActual: direccionActual,
            codigoPostal: codigoPostal,
            localidadActual: localidadActual,
            nombrePadre: nombrePadre,
            nombreMadre: nombreMadre,
            telefonoTutor1: telefonoTutor1,
            emailTutor1: emailTutor1,
            telefonoTutor2: telefonoTutor2,
            emailTutor2: emailTutor2,
            tutorLegal: tutorLegal,
            telefonoTutorLegal: telefonoTutorLegal,
            padresSeparados: padresSeparados,
            padresNoSeHablan: padresNoSeHablan,
            alergiasMedico: alergiasMedico,
            observaciones: observaciones
        )
    }
}
