//
//  BusquedaAlumnos.swift
//  GestionTutorial
//
//  Búsqueda de alumnos por texto libre y por campos con sintaxis `campo:valor`.
//  Ej.: "localidad:Barcelona email:gmail", "emancipado:si", "experiencia:sector".
//

import Foundation

enum BusquedaAlumnos {

    /// Normaliza para comparar: sin acentos, minúsculas.
    private static func norm(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }

    /// Extractores de campo: cada grupo de claves apunta al texto de un campo.
    private static let grupos: [(claves: [String], valor: (Alumno) -> String)] = [
        (["nombre"],                        { $0.nombre }),
        (["apellidos", "apellido"],         { $0.apellidos }),
        (["dni", "nie", "documento", "doc"],{ $0.numeroDocumento }),
        (["telefono", "tel", "movil"],      { [$0.telefono, $0.telefonoTutor1, $0.telefonoTutor2, $0.telefonoTutorLegal].joined(separator: " ") }),
        (["email", "correo"],               { [$0.email, $0.emailTutor1, $0.emailTutor2].joined(separator: " ") }),
        (["direccion", "calle"],            { $0.direccionActual }),
        (["cp", "postal"],                  { $0.codigoPostal }),
        (["localidad", "poblacion"],        { [$0.localidadActual, $0.poblacionNacimiento].joined(separator: " ") }),
        (["padre"],                         { $0.nombrePadre }),
        (["madre"],                         { $0.nombreMadre }),
        (["tutor"],                         { $0.tutorLegal }),
        (["alergia", "alergias", "medico"], { $0.alergiasMedico }),
        (["observaciones", "obs", "nota", "notas"], { $0.observaciones }),
        (["empresa", "practicas", "fct"],   { ($0.tienePracticas ? "si " : "no ") + $0.empresaPracticas }),
        (["asignatura", "asignaturas", "convalidada", "convalidadas", "convalidacion"], { $0.asignaturasConvalidadas + ($0.inglesConvalidado ? " ingles" : "") }),
        (["experiencia"],                   { $0.tieneConvalidacionExperiencia ? $0.convalidacionExperiencia.rawValue : "ninguna" }),
        (["emancipado"],                    { $0.emancipado ? "si" : "no" }),
        (["ingles"],                        { $0.inglesConvalidado ? "si convalidado" : "no" }),
        (["autorizacion", "firma"],         { $0.autorizacionComunicacionFirmada ? "firmada si" : ($0.autorizacionPendiente ? "pendiente sin firmar no" : "no") }),
        (["edad", "mayor"],                 { "\($0.edad.map(String.init) ?? "") \($0.estadoEdad.rawValue)" }),
    ]

    /// Diccionario clave-normalizada -> extractor.
    private static let extractores: [String: (Alumno) -> String] = {
        var d: [String: (Alumno) -> String] = [:]
        for grupo in grupos {
            for clave in grupo.claves { d[norm(clave)] = grupo.valor }
        }
        return d
    }()

    /// Claves disponibles para sugerencias en el campo de búsqueda.
    static let clavesSugeridas: [String] = [
        "nombre", "apellidos", "dni", "telefono", "email", "localidad", "direccion",
        "cp", "padre", "madre", "tutor", "alergia", "observaciones", "empresa",
        "practicas", "asignatura", "experiencia", "emancipado", "ingles", "autorizacion",
    ]

    /// Todo el texto buscable de un alumno concatenado (para términos libres).
    private static func todo(_ a: Alumno) -> String {
        grupos.map { $0.valor(a) }.joined(separator: " ")
    }

    /// Filtra la lista. Los tokens se combinan con AND.
    static func filtrar(_ alumnos: [Alumno], texto: String) -> [Alumno] {
        let q = texto.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return alumnos }
        let tokens = q.split(separator: " ").map(String.init)
        return alumnos.filter { alumno in
            tokens.allSatisfy { coincide(alumno, token: $0) }
        }
    }

    private static func coincide(_ alumno: Alumno, token: String) -> Bool {
        if let sep = token.firstIndex(of: ":") {
            let clave = norm(String(token[..<sep]))
            let valor = norm(String(token[token.index(after: sep)...]))
            if let extractor = extractores[clave] {
                let campo = norm(extractor(alumno))
                return valor.isEmpty ? !campo.trimmingCharacters(in: .whitespaces).isEmpty : campo.contains(valor)
            }
            // Clave desconocida: buscar el token completo como término libre.
        }
        return norm(todo(alumno)).contains(norm(token))
    }
}
