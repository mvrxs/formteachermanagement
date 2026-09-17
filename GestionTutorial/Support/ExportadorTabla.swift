//
//  ExportadorTabla.swift
//  GestionTutorial
//
//  Exporta la lista de alumnos a CSV (compatible con Excel es_ES) o a Excel
//  nativo (.xlsx, OOXML empaquetado con ZipWriter). Una fila por alumno.
//

import Foundation

enum ExportadorTabla {

    /// Una columna: cabecera + cómo obtener su valor de un alumno + si es numérica.
    private struct Columna {
        let titulo: String
        let valor: (Alumno) -> String
        var numerica = false
    }

    // MARK: - Definición de columnas

    private static let columnas: [Columna] = [
        Columna(titulo: "Apellidos")              { $0.apellidos },
        Columna(titulo: "Nombre")                 { $0.nombre },
        Columna(titulo: "Fecha nacimiento")       { $0.fechaNacimiento.map(fecha) ?? "" },
        Columna(titulo: "Edad", valor: { $0.edad.map(String.init) ?? "" }, numerica: true),
        Columna(titulo: "Población nacimiento")   { $0.poblacionNacimiento },
        Columna(titulo: "Nº documento")           { $0.numeroDocumento },
        Columna(titulo: "Tipo documento")         { $0.tipoDocumento == .desconocido ? "" : $0.tipoDocumento.rawValue },
        Columna(titulo: "Teléfono")               { $0.telefono },
        Columna(titulo: "Email")                  { $0.email },
        Columna(titulo: "Dirección")              { $0.direccionActual },
        Columna(titulo: "Código postal")          { $0.codigoPostal },
        Columna(titulo: "Localidad")              { $0.localidadActual },
        Columna(titulo: "Nombre padre")           { $0.nombrePadre },
        Columna(titulo: "Nombre madre")           { $0.nombreMadre },
        Columna(titulo: "Tel. tutor 1")           { $0.telefonoTutor1 },
        Columna(titulo: "Email tutor 1")          { $0.emailTutor1 },
        Columna(titulo: "Tel. tutor 2")           { $0.telefonoTutor2 },
        Columna(titulo: "Email tutor 2")          { $0.emailTutor2 },
        Columna(titulo: "Tutor legal")            { $0.tutorLegal },
        Columna(titulo: "Tel. tutor legal")       { $0.telefonoTutorLegal },
        Columna(titulo: "Padres separados")       { sino($0.padresSeparados) },
        Columna(titulo: "Padres no se hablan")    { sino($0.padresNoSeHablan) },
        Columna(titulo: "Mayor de edad")          { sino($0.esMayorDeEdad) },
        Columna(titulo: "Cumple 18 este curso")   { $0.cumple18DuranteCurso.map(fecha) ?? "" },
        Columna(titulo: "Autorización")           { autorizacion($0.estadoAutorizacion) },
        Columna(titulo: "Inglés convalidado")     { sino($0.inglesConvalidado) },
        Columna(titulo: "Prácticas (FCT)")        { sino($0.tienePracticas) },
        Columna(titulo: "Empresa prácticas")      { $0.empresaPracticas },
        Columna(titulo: "Convalidación experiencia") { $0.convalidacionExperiencia == .ninguna ? "" : $0.convalidacionExperiencia.rawValue },
        Columna(titulo: "Horas vida laboral", valor: { $0.horasVidaLaboral == 0 ? "" : String($0.horasVidaLaboral) }, numerica: true),
        Columna(titulo: "Asignaturas convalidadas") { unaLinea($0.asignaturasConvalidadas) },
        Columna(titulo: "Emancipado")             { sino($0.emancipado) },
        Columna(titulo: "Alergias / médico")      { unaLinea($0.alergiasMedico) },
        Columna(titulo: "Necesidades especiales") { $0.necesidades.map { $0.tipo.rawValue }.joined(separator: " | ") },
        Columna(titulo: "Nº tutorías", valor: { String($0.tutorias.count) }, numerica: true),
        Columna(titulo: "Observaciones")          { unaLinea($0.observaciones) },
    ]

    // MARK: - CSV

    /// CSV con separador `;` y BOM UTF-8 para que Excel (es_ES) lo abra directo.
    static func csv(alumnos: [Alumno]) -> Data {
        let sep = ";"
        var lineas: [String] = []
        lineas.append(columnas.map { escaparCSV($0.titulo, sep: sep) }.joined(separator: sep))
        for a in alumnos {
            lineas.append(columnas.map { escaparCSV($0.valor(a), sep: sep) }.joined(separator: sep))
        }
        let texto = lineas.joined(separator: "\r\n")
        var datos = Data([0xEF, 0xBB, 0xBF])   // BOM UTF-8
        datos.append(Data(texto.utf8))
        return datos
    }

    private static func escaparCSV(_ v: String, sep: String) -> String {
        let necesitaComillas = v.contains(sep) || v.contains("\"") || v.contains("\n") || v.contains("\r")
        guard necesitaComillas else { return v }
        return "\"\(v.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    // MARK: - Excel (.xlsx)

    static func xlsx(alumnos: [Alumno]) -> Data {
        var zip = ZipWriter()
        zip.agregar("[Content_Types].xml", datos(xlsxContentTypes))
        zip.agregar("_rels/.rels", datos(xlsxRels))
        zip.agregar("xl/workbook.xml", datos(xlsxWorkbook))
        zip.agregar("xl/_rels/workbook.xml.rels", datos(xlsxWorkbookRels))
        zip.agregar("xl/worksheets/sheet1.xml", datos(hojaXML(alumnos: alumnos)))
        return zip.finalizar()
    }

    private static func hojaXML(alumnos: [Alumno]) -> String {
        var filas = ""
        // Cabecera (fila 1).
        filas += fila(1, columnas.map { celda($0.titulo, numerica: false) })
        // Datos.
        for (i, a) in alumnos.enumerated() {
            let celdas = columnas.map { celda($0.valor(a), numerica: $0.numerica) }
            filas += fila(i + 2, celdas)
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <sheetData>\(filas)</sheetData></worksheet>
        """
    }

    private static func fila(_ n: Int, _ celdas: [String]) -> String {
        var s = "<row r=\"\(n)\">"
        for (i, c) in celdas.enumerated() {
            let ref = "\(columnaLetra(i))\(n)"
            s += c.replacingOccurrences(of: "{REF}", with: ref)
        }
        return s + "</row>"
    }

    /// Celda: número (`t="n"`) o texto en línea (`t="inlineStr"`). Vacías se omiten.
    private static func celda(_ valor: String, numerica: Bool) -> String {
        if valor.isEmpty { return "" }
        if numerica {
            return "<c r=\"{REF}\" t=\"n\"><v>\(valor)</v></c>"
        }
        return "<c r=\"{REF}\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escaparXML(valor))</t></is></c>"
    }

    /// Índice de columna 0-based → letras de Excel (0→A, 25→Z, 26→AA…).
    private static func columnaLetra(_ idx: Int) -> String {
        var n = idx
        var s = ""
        repeat {
            s = String(UnicodeScalar(UInt8(65 + n % 26))) + s
            n = n / 26 - 1
        } while n >= 0
        return s
    }

    private static let xlsxContentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
    <Default Extension="xml" ContentType="application/xml"/>\
    <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
    <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
    </Types>
    """

    private static let xlsxRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\
    </Relationships>
    """

    private static let xlsxWorkbook = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
    <sheets><sheet name="Alumnos" sheetId="1" r:id="rId1"/></sheets></workbook>
    """

    private static let xlsxWorkbookRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\
    </Relationships>
    """

    // MARK: - Utilidades

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    private static func fecha(_ d: Date) -> String { df.string(from: d) }
    private static func sino(_ b: Bool) -> String { b ? "Sí" : "No" }
    private static func unaLinea(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
    }

    private static func autorizacion(_ e: EstadoAutorizacion) -> String {
        switch e {
        case .firmada:   return "Firmada"
        case .pendiente: return "Pendiente"
        case .rechazada: return "Se niega"
        case .noAplica:  return ""
        }
    }

    private static func escaparXML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func datos(_ xml: String) -> Data {
        Data(xml.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
    }
}
