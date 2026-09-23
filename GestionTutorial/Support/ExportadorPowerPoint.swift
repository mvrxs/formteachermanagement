//
//  ExportadorPowerPoint.swift
//  GestionTutorial
//
//  Genera un .pptx (OOXML) desde cero: portada con el logo de la escuela + una
//  ficha por alumno (edad, dónde vive, necesidades, salud, prácticas, tutorías).
//  No usa librerías externas: construye las partes XML y las empaqueta con ZipWriter.
//

import Foundation
import ImageIO

enum ExportadorPowerPoint {

    // Dimensiones de diapositiva 16:9 en EMU (914400 EMU = 1 pulgada).
    private static let anchoSlide = 12192000
    private static let altoSlide  = 6858000

    // Colores corporativos Monlau.
    private static let azul   = "12459B"
    private static let amarillo = "FFD400"
    private static let gris   = "3A3A3C"
    private static let grisClaro = "6E6E73"

    /// Punto de entrada: devuelve los bytes del .pptx.
    static func generar(alumnos: [Alumno], grupo: String, logoPNG: Data?) -> Data {
        var zip = ZipWriter()

        // Diapositiva 1 = portada; 2..N+1 = ficha por alumno.
        let numSlides = alumnos.count + 1

        let hayFotos = alumnos.contains { $0.foto != nil }

        // --- Partes fijas del paquete ---
        zip.agregar("[Content_Types].xml", contentTypes(numSlides: numSlides, hayLogo: logoPNG != nil, hayFotos: hayFotos).datosXML)
        zip.agregar("_rels/.rels", relsRaiz.datosXML)
        zip.agregar("ppt/presentation.xml", presentation(numSlides: numSlides).datosXML)
        zip.agregar("ppt/_rels/presentation.xml.rels", presentationRels(numSlides: numSlides).datosXML)
        zip.agregar("ppt/presProps.xml", presProps.datosXML)
        zip.agregar("ppt/theme/theme1.xml", theme1.datosXML)
        zip.agregar("ppt/slideMasters/slideMaster1.xml", slideMaster.datosXML)
        zip.agregar("ppt/slideMasters/_rels/slideMaster1.xml.rels", slideMasterRels.datosXML)
        zip.agregar("ppt/slideLayouts/slideLayout1.xml", slideLayout.datosXML)
        zip.agregar("ppt/slideLayouts/_rels/slideLayout1.xml.rels", slideLayoutRels.datosXML)

        if let logoPNG {
            zip.agregar("ppt/media/image1.png", logoPNG)
        }

        // --- Portada ---
        zip.agregar("ppt/slides/slide1.xml", xmlPortada(grupo: grupo, total: alumnos.count, hayLogo: logoPNG != nil).datosXML)
        zip.agregar("ppt/slides/_rels/slide1.xml.rels", slideRels(hayLogo: logoPNG != nil).datosXML)

        // --- Ficha por alumno ---
        for (i, alumno) in alumnos.enumerated() {
            let n = i + 2
            var fotoArchivo: String?
            var fotoAspecto: Double?
            if let foto = alumno.foto {
                fotoArchivo = "foto\(n).jpg"
                zip.agregar("ppt/media/\(fotoArchivo!)", foto)
                fotoAspecto = aspecto(foto)
            }
            zip.agregar("ppt/slides/slide\(n).xml",
                        xmlFichaAlumno(alumno, hayLogo: logoPNG != nil, fotoAspecto: fotoAspecto).datosXML)
            zip.agregar("ppt/slides/_rels/slide\(n).xml.rels",
                        slideRels(hayLogo: logoPNG != nil, fotoArchivo: fotoArchivo).datosXML)
        }

        return zip.finalizar()
    }

    // MARK: - Portada

    private static func xmlPortada(grupo: String, total: Int, hayLogo: Bool) -> String {
        var formas = ""

        // Fondo azul a sangre.
        formas += rectangulo(id: 2, x: 0, y: 0, cx: anchoSlide, cy: altoSlide, color: azul)
        // Banda amarilla decorativa inferior.
        formas += rectangulo(id: 3, x: 0, y: altoSlide - 160000, cx: anchoSlide, cy: 160000, color: amarillo)

        var siguienteId = 4

        // Logo centrado.
        if hayLogo {
            let anchoLogo = 3200000
            let altoLogo = Int(Double(anchoLogo) * 887.0 / 1024.0)
            formas += imagen(id: siguienteId,
                             x: (anchoSlide - anchoLogo) / 2, y: 900000,
                             cx: anchoLogo, cy: altoLogo)
            siguienteId += 1
        }

        // Título del grupo.
        formas += cuadroTexto(
            id: siguienteId, x: 800000, y: 4500000, cx: anchoSlide - 1600000, cy: 900000,
            parrafos: [parrafo([run(grupo.isEmpty ? "Grupo" : grupo, size: 4400, bold: true, color: "FFFFFF")], alineacion: "ctr")]
        )
        siguienteId += 1

        // Subtítulo: curso, total y fecha de exportación.
        let sub = "\(cursoTexto())   ·   \(total) alumno\(total == 1 ? "" : "s")   ·   \(fechaHoy())"
        formas += cuadroTexto(
            id: siguienteId, x: 800000, y: 5450000, cx: anchoSlide - 1600000, cy: 600000,
            parrafos: [parrafo([run(sub, size: 1800, bold: false, color: "D8E1F0")], alineacion: "ctr")]
        )

        return envolturaSlide(formas: formas)
    }

    // MARK: - Ficha de alumno

    private static func xmlFichaAlumno(_ a: Alumno, hayLogo: Bool, fotoAspecto: Double?) -> String {
        var formas = ""

        // Cabecera azul con el nombre.
        formas += rectangulo(id: 2, x: 0, y: 0, cx: anchoSlide, cy: 1150000, color: azul)
        formas += cuadroTexto(
            id: 3, x: 420000, y: 250000, cx: anchoSlide - 2400000, cy: 700000,
            parrafos: [parrafo([run(a.nombreCompleto, size: 2800, bold: true, color: "FFFFFF")], alineacion: "l")],
            centradoVertical: true
        )

        var siguienteId = 4

        // Logo pequeño en la esquina superior derecha.
        if hayLogo {
            let altoLogo = 720000
            let anchoLogo = Int(Double(altoLogo) * 1024.0 / 887.0)
            formas += imagen(id: siguienteId,
                             x: anchoSlide - 420000 - anchoLogo, y: 215000,
                             cx: anchoLogo, cy: altoLogo)
            siguienteId += 1
        }

        // Foto del alumno a la derecha (si tiene), con proporción preservada.
        var anchoCuerpo = anchoSlide - 1040000
        if let aspecto = fotoAspecto {
            let maxW = 2500000, maxH = 3000000
            var w = maxW
            var h = Int(Double(maxW) / aspecto)
            if h > maxH { h = maxH; w = Int(Double(maxH) * aspecto) }
            let px = anchoSlide - 460000 - w
            let py = 1500000
            formas += imagen(id: siguienteId, x: px, y: py, cx: w, cy: h,
                             rId: "rIdFoto", name: "Foto", redondeada: true, borde: true)
            siguienteId += 1
            anchoCuerpo = px - 520000 - 280000   // deja hueco para la foto
        }

        // Cuerpo con los datos.
        let parrafos = parrafosFicha(a)
        formas += cuadroTexto(
            id: siguienteId, x: 520000, y: 1420000, cx: anchoCuerpo, cy: altoSlide - 1720000,
            parrafos: parrafos, autoAjuste: true
        )

        return envolturaSlide(formas: formas)
    }

    /// Construye las líneas de contenido de la ficha de un alumno.
    private static func parrafosFicha(_ a: Alumno) -> [String] {
        var ps: [String] = []

        // --- Identidad / edad ---
        ps.append(subtitulo("Datos personales"))
        var identidad: [String] = []
        if let edad = a.edad { identidad.append("\(edad) años") }
        if let f = a.fechaNacimiento { identidad.append("Nacido/a el \(fecha(f))") }
        if !a.poblacionNacimiento.isEmpty { identidad.append("en \(a.poblacionNacimiento)") }
        if !identidad.isEmpty { ps.append(vinneta(identidad.joined(separator: " · "))) }

        // Estado de edad / autorización.
        switch a.estadoEdad {
        case .mayor:
            ps.append(vinneta("Mayor de edad", color: "1E7F3C"))
        case .cumpleEsteCurso:
            if let f = a.cumple18DuranteCurso {
                ps.append(vinneta("Cumple 18 el \(fecha(f)) (este curso)", color: "B25E00"))
            } else {
                ps.append(vinneta("Cumple 18 este curso", color: "B25E00"))
            }
        case .menor:
            ps.append(vinneta("Menor de edad", color: grisClaro))
        }
        if a.esMayorDeEdad || a.estadoAutorizacion != .noAplica {
            switch a.estadoAutorizacion {
            case .firmada:   ps.append(vinneta("Autorización de comunicación: firmada", color: "1E7F3C"))
            case .pendiente: ps.append(vinneta("Autorización de comunicación: PENDIENTE de firmar", color: "B25E00"))
            case .rechazada: ps.append(vinneta("Autorización de comunicación: se niega a firmar", color: "B00020"))
            case .noAplica:  break
            }
        }
        if !a.numeroDocumento.isEmpty {
            ps.append(vinneta("\(a.tipoDocumento.rawValue): \(a.numeroDocumento)"))
        }

        // --- Dónde vive ---
        var domicilio: [String] = []
        if !a.direccionActual.isEmpty { domicilio.append(a.direccionActual) }
        let cpLoc = [a.codigoPostal, a.localidadActual].filter { !$0.isEmpty }.joined(separator: " ")
        if !cpLoc.isEmpty { domicilio.append(cpLoc) }
        if !domicilio.isEmpty {
            ps.append(subtitulo("Dónde vive"))
            ps.append(vinneta(domicilio.joined(separator: ", ")))
        }
        if a.padresSeparados || a.padresNoSeHablan {
            var fam: [String] = []
            if a.padresSeparados { fam.append("padres separados") }
            if a.padresNoSeHablan { fam.append("padres no se hablan") }
            ps.append(vinneta("Situación familiar: \(fam.joined(separator: ", "))", color: "B25E00"))
        }

        // --- Salud ---
        if !a.alergiasMedico.isEmpty {
            ps.append(subtitulo("Salud"))
            ps.append(vinneta(truncar(a.alergiasMedico, 260), color: "B00020"))
        }

        // --- Necesidades especiales ---
        if !a.necesidades.isEmpty {
            ps.append(subtitulo("Necesidades especiales"))
            for n in a.necesidades {
                var linea = n.tipo.rawValue
                if !n.descripcionDiagnostico.isEmpty {
                    linea += " — \(truncar(n.descripcionDiagnostico, 160))"
                }
                ps.append(vinneta(linea, color: "5B3E9B"))
                if !n.adaptacionesAplicadas.isEmpty {
                    ps.append(vinneta("Adaptaciones: \(truncar(n.adaptacionesAplicadas, 180))", nivel: 1, size: 1300, color: grisClaro))
                }
            }
        }

        // --- Prácticas ---
        if a.tienePracticas {
            ps.append(subtitulo("Prácticas (FCT)"))
            ps.append(vinneta(a.empresaPracticas.isEmpty ? "Realiza prácticas" : "Empresa: \(a.empresaPracticas)"))
        }

        // --- Tutorías resumidas ---
        if !a.tutorias.isEmpty {
            let ordenadas = a.tutorias.sorted { $0.fecha > $1.fecha }
            ps.append(subtitulo("Tutorías (\(a.tutorias.count))"))
            for t in ordenadas.prefix(5) {
                var partes: [String] = [fecha(t.fecha), t.modalidad.rawValue]
                if !t.temasTratados.isEmpty { partes.append(truncar(t.temasTratados, 120)) }
                else if !t.acuerdos.isEmpty { partes.append(truncar(t.acuerdos, 120)) }
                ps.append(vinneta(partes.joined(separator: " · "), size: 1300))
            }
            if a.tutorias.count > 5 {
                ps.append(vinneta("… y \(a.tutorias.count - 5) más", nivel: 1, size: 1200, color: grisClaro))
            }
        }

        if ps.isEmpty {
            ps.append(vinneta("Sin datos adicionales", color: grisClaro))
        }
        return ps
    }

    // MARK: - Helpers de párrafo

    /// Subtítulo de sección (azul, en negrita, con espacio superior).
    private static func subtitulo(_ texto: String) -> String {
        parrafo([run(texto, size: 1600, bold: true, color: azul)], espacioAntes: 500)
    }

    /// Viñeta con texto normal.
    private static func vinneta(_ texto: String, nivel: Int = 0, size: Int = 1400, color: String? = nil) -> String {
        parrafo([run(texto, size: size, bold: false, color: color ?? gris)], vinneta: true, nivel: nivel, espacioAntes: 200)
    }

    private static func run(_ texto: String, size: Int, bold: Bool, color: String) -> String {
        """
        <a:r><a:rPr lang="es-ES" sz="\(size)" b="\(bold ? 1 : 0)"><a:solidFill><a:srgbClr val="\(color)"/></a:solidFill><a:latin typeface="Helvetica Neue"/></a:rPr><a:t>\(escapar(texto))</a:t></a:r>
        """
    }

    private static func parrafo(_ runs: [String], vinneta: Bool = false, nivel: Int = 0, alineacion: String = "l", espacioAntes: Int = 0) -> String {
        var pPr = "<a:pPr"
        if alineacion != "l" { pPr += " algn=\"\(alineacion)\"" }
        if nivel > 0 { pPr += " lvl=\"\(nivel)\"" }
        if vinneta {
            let marL = 228600 + nivel * 228600
            pPr += " marL=\"\(marL)\" indent=\"-228600\""
        } else {
            pPr += " marL=\"0\" indent=\"0\""
        }
        pPr += ">"
        if espacioAntes > 0 { pPr += "<a:spcBef><a:spcPts val=\"\(espacioAntes)\"/></a:spcBef>" }
        pPr += vinneta ? "<a:buFont typeface=\"Arial\"/><a:buChar char=\"•\"/>" : "<a:buNone/>"
        pPr += "</a:pPr>"
        return "<a:p>\(pPr)\(runs.joined())</a:p>"
    }

    // MARK: - Helpers de forma

    private static func rectangulo(id: Int, x: Int, y: Int, cx: Int, cy: Int, color: String) -> String {
        """
        <p:sp><p:nvSpPr><p:cNvPr id="\(id)" name="rect\(id)"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\
        <p:spPr><a:xfrm><a:off x="\(x)" y="\(y)"/><a:ext cx="\(cx)" cy="\(cy)"/></a:xfrm>\
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="\(color)"/></a:solidFill>\
        <a:ln><a:noFill/></a:ln></p:spPr>\
        <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:endParaRPr lang="es-ES"/></a:p></p:txBody></p:sp>
        """
    }

    private static func imagen(id: Int, x: Int, y: Int, cx: Int, cy: Int, rId: String = "rIdImg", name: String = "Logo", redondeada: Bool = false, borde: Bool = false) -> String {
        let geom = redondeada ? "roundRect" : "rect"
        let ln = borde ? "<a:ln w=\"12700\"><a:solidFill><a:srgbClr val=\"\(azul)\"/></a:solidFill></a:ln>" : ""
        return """
        <p:pic><p:nvPicPr><p:cNvPr id="\(id)" name="\(name)"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>\
        <p:blipFill><a:blip r:embed="\(rId)"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>\
        <p:spPr><a:xfrm><a:off x="\(x)" y="\(y)"/><a:ext cx="\(cx)" cy="\(cy)"/></a:xfrm>\
        <a:prstGeom prst="\(geom)"><a:avLst/></a:prstGeom>\(ln)</p:spPr></p:pic>
        """
    }

    /// Proporción ancho/alto de una imagen (para no deformarla en la diapositiva).
    private static func aspecto(_ datos: Data) -> Double? {
        guard let src = CGImageSourceCreateWithData(datos as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Double,
              let h = props[kCGImagePropertyPixelHeight] as? Double, h > 0 else { return nil }
        return w / h
    }

    private static func cuadroTexto(id: Int, x: Int, y: Int, cx: Int, cy: Int, parrafos: [String], alineacion: String = "l", centradoVertical: Bool = false, autoAjuste: Bool = false) -> String {
        var bodyPr = "<a:bodyPr wrap=\"square\" lIns=\"0\" tIns=\"0\" rIns=\"0\" bIns=\"0\""
        if centradoVertical { bodyPr += " anchor=\"ctr\"" }
        bodyPr += ">"
        bodyPr += autoAjuste ? "<a:normAutofit/>" : "<a:noAutofit/>"
        bodyPr += "</a:bodyPr>"
        return """
        <p:sp><p:nvSpPr><p:cNvPr id="\(id)" name="txt\(id)"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>\
        <p:spPr><a:xfrm><a:off x="\(x)" y="\(y)"/><a:ext cx="\(cx)" cy="\(cy)"/></a:xfrm>\
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/></p:spPr>\
        <p:txBody>\(bodyPr)<a:lstStyle/>\(parrafos.joined())</p:txBody></p:sp>
        """
    }

    /// Envuelve el árbol de formas en la estructura de una diapositiva.
    private static func envolturaSlide(formas: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\
        <p:cSld><p:spTree>\
        <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\
        <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>\
        \(formas)\
        </p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>
        """
    }

    // MARK: - Partes fijas del paquete

    private static func contentTypes(numSlides: Int, hayLogo: Bool, hayFotos: Bool) -> String {
        var overrides = ""
        for n in 1...numSlides {
            overrides += "<Override PartName=\"/ppt/slides/slide\(n).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>"
        }
        let png = hayLogo ? "<Default Extension=\"png\" ContentType=\"image/png\"/>" : ""
        let jpg = hayFotos ? "<Default Extension=\"jpg\" ContentType=\"image/jpeg\"/>" : ""
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
        <Default Extension="xml" ContentType="application/xml"/>\(png)\(jpg)\
        <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>\
        <Override PartName="/ppt/presProps.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presProps+xml"/>\
        <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>\
        <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>\
        <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>\
        \(overrides)</Types>
        """
    }

    private static let relsRaiz = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>\
    </Relationships>
    """

    private static func presentation(numSlides: Int) -> String {
        var sldIds = ""
        for n in 1...numSlides {
            // r:id de slides empieza en rId2 (rId1 = master).
            sldIds += "<p:sldId id=\"\(255 + n)\" r:id=\"rId\(n + 1)\"/>"
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\
        <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>\
        <p:sldIdLst>\(sldIds)</p:sldIdLst>\
        <p:sldSz cx="\(anchoSlide)" cy="\(altoSlide)" type="screen16x9"/>\
        <p:notesSz cx="6858000" cy="9144000"/></p:presentation>
        """
    }

    private static func presentationRels(numSlides: Int) -> String {
        var rels = "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"slideMasters/slideMaster1.xml\"/>"
        for n in 1...numSlides {
            rels += "<Relationship Id=\"rId\(n + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide\(n).xml\"/>"
        }
        let idProps = numSlides + 2
        rels += "<Relationship Id=\"rId\(idProps)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/presProps\" Target=\"presProps.xml\"/>"
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\(rels)</Relationships>
        """
    }

    private static func slideRels(hayLogo: Bool, fotoArchivo: String? = nil) -> String {
        var rels = "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/>"
        if hayLogo {
            rels += "<Relationship Id=\"rIdImg\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"../media/image1.png\"/>"
        }
        if let fotoArchivo {
            rels += "<Relationship Id=\"rIdFoto\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"../media/\(fotoArchivo)\"/>"
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\(rels)</Relationships>
        """
    }

    private static let presProps = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <p:presentationPr xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"/>
    """

    private static let slideMaster = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\
    <p:cSld><p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg>\
    <p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\
    <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>\
    </p:spTree></p:cSld>\
    <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>\
    <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>\
    <p:txStyles>\
    <p:titleStyle><a:lvl1pPr algn="l"><a:defRPr sz="4400" b="1"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/></a:defRPr></a:lvl1pPr></p:titleStyle>\
    <p:bodyStyle><a:lvl1pPr><a:defRPr sz="1800"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/></a:defRPr></a:lvl1pPr>\
    <a:lvl2pPr><a:defRPr sz="1600"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill></a:defRPr></a:lvl2pPr></p:bodyStyle>\
    <p:otherStyle><a:lvl1pPr><a:defRPr sz="1800"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill></a:defRPr></a:lvl1pPr></p:otherStyle>\
    </p:txStyles></p:sldMaster>
    """

    private static let slideMasterRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>\
    <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>\
    </Relationships>
    """

    private static let slideLayout = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">\
    <p:cSld name="En blanco"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\
    <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>\
    </p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>
    """

    private static let slideLayoutRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>\
    </Relationships>
    """

    private static let theme1 = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Monlau">\
    <a:themeElements>\
    <a:clrScheme name="Monlau">\
    <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>\
    <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>\
    <a:dk2><a:srgbClr val="12459B"/></a:dk2>\
    <a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>\
    <a:accent1><a:srgbClr val="12459B"/></a:accent1>\
    <a:accent2><a:srgbClr val="FFD400"/></a:accent2>\
    <a:accent3><a:srgbClr val="5B3E9B"/></a:accent3>\
    <a:accent4><a:srgbClr val="1E7F3C"/></a:accent4>\
    <a:accent5><a:srgbClr val="B25E00"/></a:accent5>\
    <a:accent6><a:srgbClr val="B00020"/></a:accent6>\
    <a:hlink><a:srgbClr val="0563C1"/></a:hlink>\
    <a:folHlink><a:srgbClr val="954F72"/></a:folHlink>\
    </a:clrScheme>\
    <a:fontScheme name="Monlau">\
    <a:majorFont><a:latin typeface="Helvetica Neue"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>\
    <a:minorFont><a:latin typeface="Helvetica Neue"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>\
    </a:fontScheme>\
    <a:fmtScheme name="Office">\
    <a:fillStyleLst>\
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>\
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>\
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>\
    </a:fillStyleLst>\
    <a:lnStyleLst>\
    <a:ln w="6350" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln>\
    <a:ln w="12700" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln>\
    <a:ln w="19050" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln>\
    </a:lnStyleLst>\
    <a:effectStyleLst>\
    <a:effectStyle><a:effectLst/></a:effectStyle>\
    <a:effectStyle><a:effectLst/></a:effectStyle>\
    <a:effectStyle><a:effectLst/></a:effectStyle>\
    </a:effectStyleLst>\
    <a:bgFillStyleLst>\
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>\
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>\
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>\
    </a:bgFillStyleLst>\
    </a:fmtScheme></a:themeElements></a:theme>
    """

    // MARK: - Utilidades

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    private static func fecha(_ d: Date) -> String { df.string(from: d) }
    private static func fechaHoy() -> String { df.string(from: .now) }

    private static func cursoTexto() -> String {
        let cal = Calendar.current
        let a1 = cal.component(.year, from: Ajustes.cursoInicio)
        let a2 = cal.component(.year, from: Ajustes.cursoFin)
        return "Curso \(a1)/\(a2)"
    }

    private static func truncar(_ s: String, _ max: Int) -> String {
        let limpio = s.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return limpio.count <= max ? limpio : String(limpio.prefix(max - 1)) + "…"
    }

    private static func escapar(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&apos;")
    }
}

private extension String {
    /// Bytes UTF-8 del XML, quitando la indentación inicial del literal multilínea.
    var datosXML: Data {
        Data(self.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
    }
}
