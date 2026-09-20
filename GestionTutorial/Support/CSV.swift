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
    case padreContacto          // "Nombre / email / teléfono" del padre en una celda
    case madreContacto          // "Nombre / email / teléfono" de la madre en una celda

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
        case .padreContacto:      return "Padre (Nombre / email / tel)"
        case .madreContacto:      return "Madre (Nombre / email / tel)"
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

    /// Parte "Nombre / email / teléfono" en sus tres piezas (por posición del "/").
    /// Detecta email y teléfono por forma; el resto es el nombre.
    static func partirContacto(_ v: String) -> (nombre: String, email: String, telefono: String) {
        let partes = v.split(separator: "/", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var nombre = "", email = "", telefono = ""
        for p in partes where !p.isEmpty {
            if p.contains("@") { email = p }
            else if p.filter(\.isNumber).count >= 6 { telefono = p }
            else if nombre.isEmpty { nombre = p }
        }
        return (nombre, email, telefono)
    }

    private static let regexDNI = try? NSRegularExpression(pattern: "^[XYZ]?[0-9]{5,8}[A-Z]$")

    private static func pareceDNI(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces).uppercased()
        guard let re = regexDNI else { return false }
        return re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil
    }

    /// Auto-mapeo por VALOR (para CSV sin cabecera): inspecciona una muestra de
    /// valores de la columna y deduce el campo destino. Devuelve `.ignorar` si no
    /// hay señal clara. `padreContacto`/`madreContacto` se desambiguan fuera (por
    /// posición) porque por valor son indistinguibles.
    static func deducirPorValor(_ valores: [String]) -> CampoDestino {
        let muestra = valores
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !muestra.isEmpty else { return .ignorar }

        func mayoria(_ pred: (String) -> Bool) -> Bool {
            muestra.filter(pred).count * 2 > muestra.count
        }

        // "Nombre / email / teléfono": tiene "/" y "@".
        if mayoria({ $0.contains("/") && $0.contains("@") }) { return .padreContacto }
        // "Apellidos, Nombre": tiene coma y tras la coma empieza por letra (un
        // nombre), lo que lo distingue de una dirección "Calle X, 11". Tolera un
        // prefijo de grupo con dígitos ("1SMXA …").
        if mayoria(esNombreApellidos) { return .apellidosNombre }
        // DNI/NIE.
        if mayoria(pareceDNI) { return .numeroDocumento }
        // Fecha dd/MM/yyyy.
        if mayoria({ parsearFecha($0) != nil }) { return .fechaNacimiento }
        // Código postal (5 dígitos exactos).
        if mayoria({ $0.count == 5 && $0.allSatisfy(\.isNumber) }) { return .codigoPostal }
        // Índice de fila (números cortos). Se ignora.
        if mayoria({ $0.allSatisfy(\.isNumber) && $0.count <= 3 }) { return .ignorar }
        // Email suelto.
        if mayoria({ $0.contains("@") }) { return .email }
        // Dirección: texto con letras y algún número, más de 8 caracteres.
        if mayoria({ $0.count > 8 && $0.contains(where: \.isLetter) && $0.contains(where: \.isNumber) }) {
            return .direccionActual
        }
        return .ignorar
    }

    /// "Apellidos, Nombre": hay coma y lo que sigue empieza por letra.
    private static func esNombreApellidos(_ s: String) -> Bool {
        guard !s.contains("@"), !s.contains("/"), let ci = s.firstIndex(of: ",") else { return false }
        let despues = s[s.index(after: ci)...].trimmingCharacters(in: .whitespaces)
        return despues.first?.isLetter == true
    }
}

/// Tipo de CSV dentro del juego que forma una ficha completa de alumno.
enum RolCSV: String, CaseIterable, Identifiable {
    case contactosPadres    // nombre + padre/madre (email/tel)
    case fichaPersonal      // nombre + DNI + fecha + dirección…
    case listaNombres       // solo la lista de alumnos del grupo
    case otro

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .contactosPadres: return "Contactos de padres/madres"
        case .fichaPersonal:   return "Ficha personal (DNI, fecha, dirección)"
        case .listaNombres:    return "Lista de alumnos del grupo"
        case .otro:            return "No reconocido"
        }
    }

    /// Roles obligatorios para poder importar (si falta uno, quedarían datos a
    /// medias). La lista de nombres es redundante (solo nombres) y no se exige.
    static var obligatorios: [RolCSV] { [.contactosPadres, .fichaPersonal] }
}

// MARK: - Fusión de varios CSV

/// Une filas provenientes de varios CSV en un registro por alumno. Empareja por
/// DNI y, si falta, por nombre; así un mismo alumno repartido en distintos CSV
/// (unos con contacto, otros con datos médicos…) queda en una sola ficha.
enum FusionAlumnos {
    static func normalizarDNI(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces).uppercased().replacingOccurrences(of: "-", with: "")
    }

    static func claveNombre(_ apellidos: String, _ nombre: String) -> String {
        "\(apellidos)|\(nombre)"
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
    }

    private static func nombreVacio(_ clave: String) -> Bool {
        clave.replacingOccurrences(of: "|", with: "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Un CSV cargado listo para fusionar: sus filas, si la 1ª es cabecera y el
    /// mapeo de cada columna.
    struct EntradaCSV {
        var filas: [[String]]
        var hayCabecera: Bool
        var mapeo: [CampoDestino]
    }

    /// Auto-mapeo de un archivo SIN cabecera, por los valores de cada columna.
    /// Desambigua padre/madre por posición (1º padre, siguientes madre).
    static func autoMapearPorValor(_ filas: [[String]], hayCabecera: Bool) -> [CampoDestino] {
        let datos = hayCabecera ? Array(filas.dropFirst()) : filas
        let numCol = filas.map(\.count).max() ?? 0
        var mapeo: [CampoDestino] = (0..<numCol).map { c in
            MapeoColumnas.deducirPorValor(datos.compactMap { c < $0.count ? $0[c] : nil })
        }
        var vistoPadre = false
        for i in mapeo.indices where mapeo[i] == .padreContacto {
            if vistoPadre { mapeo[i] = .madreContacto } else { vistoPadre = true }
        }
        // Localidad: primera columna de solo letras (una ciudad) justo tras el CP.
        if let cp = mapeo.firstIndex(of: .codigoPostal) {
            for c in (cp + 1)..<numCol where mapeo[c] == .ignorar {
                let vals = datos.compactMap { c < $0.count ? $0[c] : nil }
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                let permitidos = CharacterSet.letters.union(CharacterSet(charactersIn: " '’-."))
                let sonCiudad = !vals.isEmpty && vals.allSatisfy {
                    $0.unicodeScalars.allSatisfy(permitidos.contains)
                }
                if sonCiudad { mapeo[c] = .localidadActual; break }
            }
        }
        return mapeo
    }

    /// Rol de un CSV deducido de su mapeo, para exigir el juego completo.
    static func rol(_ mapeo: [CampoDestino]) -> RolCSV {
        let tieneNombre = mapeo.contains(.apellidosNombre) || mapeo.contains(.apellidos)
        let tieneContacto = mapeo.contains(.padreContacto) || mapeo.contains(.madreContacto)
        let tieneFicha = mapeo.contains(.numeroDocumento) || mapeo.contains(.fechaNacimiento)

        if tieneContacto { return .contactosPadres }
        if tieneFicha { return .fichaPersonal }
        // Solo nombres (y columnas vacías/ignoradas): lista de clase.
        if tieneNombre { return .listaNombres }
        return .otro
    }

    /// Construye la lista fusionada a partir de varios CSV ya mapeados. Quita el
    /// prefijo de grupo común del nombre (p. ej. "1SMXA ") para que el emparejado
    /// por nombre funcione entre archivos.
    static func desdeArchivos(_ entradas: [EntradaCSV]) -> [AlumnoImportado] {
        var todos: [AlumnoImportado] = []
        for e in entradas {
            let datos = e.hayCabecera ? Array(e.filas.dropFirst()) : e.filas
            let nameIdx = e.mapeo.firstIndex { $0 == .apellidosNombre || $0 == .apellidos }

            var prefijo = ""
            if let ni = nameIdx {
                let nombres = datos
                    .compactMap { ni < $0.count ? $0[ni] : nil }
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                prefijo = prefijoComunPalabra(nombres)
            }

            for var fila in datos {
                if !prefijo.isEmpty, let ni = nameIdx, ni < fila.count, fila[ni].hasPrefix(prefijo) {
                    fila[ni] = String(fila[ni].dropFirst(prefijo.count))
                }
                let imp = AlumnoImportado.desde(fila: fila, mapeo: e.mapeo)
                if imp.apellidos.isEmpty && imp.nombre.isEmpty && imp.numeroDocumento.isEmpty { continue }
                todos.append(imp)
            }
        }
        return fusionar(todos)
    }

    /// Prefijo común (palabra completa terminada en espacio) entre todos los
    /// valores, solo si parece un código de grupo corto (≤ 8 caracteres).
    private static func prefijoComunPalabra(_ valores: [String]) -> String {
        guard valores.count > 1, var prefijo = valores.first else { return "" }
        for v in valores.dropFirst() {
            while !prefijo.isEmpty, !v.hasPrefix(prefijo) { prefijo.removeLast() }
            if prefijo.isEmpty { return "" }
        }
        guard let sp = prefijo.lastIndex(of: " ") else { return "" }
        let corte = String(prefijo[...sp])
        return corte.count <= 8 && !corte.contains(",") ? corte : ""
    }

    /// Fusiona una secuencia de registros ya mapeados (en orden de aparición).
    static func fusionar(_ todos: [AlumnoImportado]) -> [AlumnoImportado] {
        var registros: [AlumnoImportado] = []
        var porDNI: [String: Int] = [:]
        var porNombre: [String: Int] = [:]

        for a in todos {
            let dni = normalizarDNI(a.numeroDocumento)
            let nom = claveNombre(a.apellidos, a.nombre)

            // Busca un registro previo por DNI o, si no, por nombre.
            var idx: Int? = nil
            if !dni.isEmpty { idx = porDNI[dni] }
            if idx == nil, !nombreVacio(nom) { idx = porNombre[nom] }

            if let i = idx {
                registros[i].merge(a)
                // Reindexa: el merge puede haber rellenado DNI o nombre.
                let d2 = normalizarDNI(registros[i].numeroDocumento)
                if !d2.isEmpty { porDNI[d2] = i }
                let n2 = claveNombre(registros[i].apellidos, registros[i].nombre)
                if !nombreVacio(n2) { porNombre[n2] = i }
            } else {
                registros.append(a)
                let i = registros.count - 1
                if !dni.isEmpty { porDNI[dni] = i }
                if !nombreVacio(nom) { porNombre[nom] = i }
            }
        }
        return registros
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
            case .padreContacto:
                let (nom, email, tel) = MapeoColumnas.partirContacto(valor)
                a.nombrePadre = nom; a.emailTutor1 = email; a.telefonoTutor1 = tel
            case .madreContacto:
                let (nom, email, tel) = MapeoColumnas.partirContacto(valor)
                a.nombreMadre = nom; a.emailTutor2 = email; a.telefonoTutor2 = tel
            }
        }
        return a
    }

    /// Fusiona otro registro (de otro CSV) sobre este: rellena campos vacíos
    /// con los del otro y combina los booleanos con OR. Nunca pisa un valor ya
    /// presente, así columnas redundantes entre CSV no generan confusión.
    mutating func merge(_ o: AlumnoImportado) {
        func rellenar(_ a: inout String, _ b: String) {
            if a.trimmingCharacters(in: .whitespaces).isEmpty { a = b }
        }
        rellenar(&apellidos, o.apellidos)
        rellenar(&nombre, o.nombre)
        rellenar(&poblacionNacimiento, o.poblacionNacimiento)
        rellenar(&numeroDocumento, o.numeroDocumento)
        rellenar(&telefono, o.telefono)
        rellenar(&email, o.email)
        rellenar(&nombrePadre, o.nombrePadre)
        rellenar(&nombreMadre, o.nombreMadre)
        rellenar(&telefonoTutor1, o.telefonoTutor1)
        rellenar(&emailTutor1, o.emailTutor1)
        rellenar(&telefonoTutor2, o.telefonoTutor2)
        rellenar(&emailTutor2, o.emailTutor2)
        rellenar(&tutorLegal, o.tutorLegal)
        rellenar(&telefonoTutorLegal, o.telefonoTutorLegal)
        rellenar(&alergiasMedico, o.alergiasMedico)
        rellenar(&direccionActual, o.direccionActual)
        rellenar(&codigoPostal, o.codigoPostal)
        rellenar(&localidadActual, o.localidadActual)

        // Observaciones: concatena si ambos aportan texto distinto.
        if observaciones.trimmingCharacters(in: .whitespaces).isEmpty {
            observaciones = o.observaciones
        } else if !o.observaciones.trimmingCharacters(in: .whitespaces).isEmpty,
                  !observaciones.contains(o.observaciones) {
            observaciones += "\n" + o.observaciones
        }

        if fechaNacimiento == nil { fechaNacimiento = o.fechaNacimiento }
        if fechaNacimientoTextoInvalido == nil { fechaNacimientoTextoInvalido = o.fechaNacimientoTextoInvalido }

        padresSeparados = padresSeparados || o.padresSeparados
        padresNoSeHablan = padresNoSeHablan || o.padresNoSeHablan
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
