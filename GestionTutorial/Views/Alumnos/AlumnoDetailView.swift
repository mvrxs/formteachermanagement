//
//  AlumnoDetailView.swift
//  GestionTutorial
//
//  Ficha completa y editable de un alumno (edición en vivo vía @Bindable).
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AlumnoDetailView: View {
    @Bindable var alumno: Alumno
    @Environment(\.modelContext) private var modelContext

    @State private var tutoriaEnEdicion: Tutoria?
    @State private var necesidadEnEdicion: NecesidadEspecial?
    @State private var mostrarSelectorFoto = false
    @State private var errorFoto: String?

    /// Binding puente para la fecha de nacimiento opcional.
    private var tieneFechaNacimiento: Binding<Bool> {
        Binding(
            get: { alumno.fechaNacimiento != nil },
            set: { activo in
                alumno.fechaNacimiento = activo ? (alumno.fechaNacimiento ?? Date(timeIntervalSince1970: 1_072_915_200)) : nil
            }
        )
    }

    private var fechaNacimientoBinding: Binding<Date> {
        Binding(
            get: { alumno.fechaNacimiento ?? .now },
            set: { alumno.fechaNacimiento = $0 }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                cabecera
                avisos
                tarjetaIdentidad
                tarjetaContacto
                tarjetaFamilia
                tarjetaPracticas
                tarjetaAutorizaciones
                tarjetaSalud
                tarjetaTutorias
                tarjetaNecesidades
            }
            .padding(20)
        }
        .navigationTitle(alumno.nombreCompleto)
        .sheet(item: $tutoriaEnEdicion) { tutoria in
            EditorEnSheet(titulo: "Tutoría") { TutoriaDetailView(tutoria: tutoria) }
        }
        .sheet(item: $necesidadEnEdicion) { necesidad in
            EditorEnSheet(titulo: "Necesidad") { NecesidadDetailView(necesidad: necesidad) }
        }
        .fileImporter(
            isPresented: $mostrarSelectorFoto,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { cargarFoto($0) }
        .alert("No se pudo cargar la imagen", isPresented: .constant(errorFoto != nil)) {
            Button("OK") { errorFoto = nil }
        } message: {
            Text(errorFoto ?? "")
        }
    }

    // MARK: - Cabecera

    private var cabecera: some View {
        HStack(spacing: 16) {
            avatarConMenu
            VStack(alignment: .leading, spacing: 6) {
                Text(alumno.nombreCompleto)
                    .font(.title.bold())
                HStack(spacing: 8) {
                    if alumno.tipoDocumento != .desconocido {
                        Text(alumno.tipoDocumento.rawValue).fontWeight(.semibold)
                    }
                    Text(alumno.numeroDocumento.isEmpty ? "Sin documento" : alumno.numeroDocumento)
                        .foregroundStyle(alumno.numeroDocumento.isEmpty ? .secondary : .primary)
                }
                .font(.subheadline)
            }
            Spacer()
        }
    }

    /// Avatar con menú para elegir, cambiar o quitar la foto.
    private var avatarConMenu: some View {
        Menu {
            Button {
                mostrarSelectorFoto = true
            } label: {
                Label(alumno.foto == nil ? "Añadir foto…" : "Cambiar foto…", systemImage: "photo")
            }
            if alumno.foto != nil {
                Button(role: .destructive) {
                    alumno.foto = nil
                } label: {
                    Label("Quitar foto", systemImage: "trash")
                }
            }
        } label: {
            AvatarAlumno(foto: alumno.foto, tamano: 64)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .tint)
                        .font(.title3)
                        .background(.background, in: .circle)
                }
        }
        .buttonStyle(.plain)
        .help("Añadir o cambiar la foto del alumno")
    }

    private func cargarFoto(_ resultado: Result<[URL], Error>) {
        switch resultado {
        case .success(let urls):
            guard let url = urls.first else { return }
            let acceso = url.startAccessingSecurityScopedResource()
            defer { if acceso { url.stopAccessingSecurityScopedResource() } }
            if let datos = ImagenUtil.jpegRedimensionado(desde: url) {
                alumno.foto = datos
            } else {
                errorFoto = "El archivo no es una imagen válida."
            }
        case .failure(let error):
            errorFoto = error.localizedDescription
        }
    }

    // MARK: - Avisos (chips calculados)

    private var avisos: some View {
        ViewThatFits(in: .horizontal) {
            chipsAvisos
            ScrollView(.horizontal, showsIndicators: false) { chipsAvisos }
        }
    }

    private var chipsAvisos: some View {
        HStack(spacing: 8) {
            if let edad = alumno.edad {
                Chip(texto: "\(edad) años", simbolo: "birthday.cake", tinte: .blue)
            }
            if alumno.esMayorDeEdad {
                Chip(texto: "Mayor de edad", simbolo: "checkmark.seal", tinte: .green)
            } else if let fecha = alumno.cumple18DuranteCurso {
                Chip(texto: "Cumple 18 el \(fecha.formatted(Formatos.fechaMedia))", simbolo: "18.circle", tinte: .orange)
            } else if let fecha = alumno.fechaCumple18 {
                Chip(texto: "18 años: \(fecha.formatted(Formatos.fechaMedia))", simbolo: "calendar", tinte: .secondary)
            }
            if alumno.padresSeparados {
                Chip(texto: "Padres separados", simbolo: "person.2.slash", tinte: .purple)
            }
            if alumno.padresNoSeHablan {
                Chip(texto: "No se hablan", simbolo: "exclamationmark.bubble", tinte: .pink)
            }
            if !alumno.alergiasMedico.isEmpty {
                Chip(texto: "Alergias/médico", simbolo: "cross.case", tinte: .red)
            }
            switch alumno.estadoAutorizacion {
            case .firmada:
                Chip(texto: "Autorización firmada", simbolo: "checkmark.circle", tinte: .green)
            case .pendiente:
                Chip(texto: "Autorización pendiente", simbolo: "clock", tinte: .orange)
            case .rechazada:
                Chip(texto: "No firma autorización", simbolo: "exclamationmark.triangle", tinte: .red)
            case .noAplica:
                EmptyView()
            }
            if alumno.inglesConvalidado {
                Chip(texto: "Inglés convalidado", simbolo: "graduationcap", tinte: .teal)
            }
            if alumno.emancipado {
                Chip(texto: "Emancipado", simbolo: "house", tinte: .indigo)
            }
            if alumno.tieneConvalidacionExperiencia {
                Chip(texto: "Exp. \(alumno.convalidacionExperiencia.porcentaje)%",
                     simbolo: "briefcase", tinte: .blue)
            }
            if alumno.horasExperienciaInsuficientes {
                Chip(texto: "< 1000 h", simbolo: "exclamationmark.triangle", tinte: .orange)
            }
            if alumno.tienePracticas {
                Chip(texto: "Prácticas", simbolo: "building.2", tinte: .cyan)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Tarjetas de datos

    private var tarjetaIdentidad: some View {
        TarjetaSeccion(titulo: "Identidad", simbolo: "person.text.rectangle") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    CampoEtiquetado(etiqueta: "Apellidos", valor: $alumno.apellidos)
                    CampoEtiquetado(etiqueta: "Nombre", valor: $alumno.nombre)
                }
                GridRow {
                    CampoEtiquetado(etiqueta: "Nº documento (DNI/NIE)", valor: $alumno.numeroDocumento)
                    CampoEtiquetado(etiqueta: "Población de nacimiento", valor: $alumno.poblacionNacimiento)
                }
            }
            Divider()
            Toggle("Tiene fecha de nacimiento registrada", isOn: tieneFechaNacimiento)
                .toggleStyle(.switch)
            if alumno.fechaNacimiento != nil {
                DatePicker("Fecha de nacimiento", selection: fechaNacimientoBinding, displayedComponents: .date)
                    .datePickerStyle(.field)
                    .environment(\.locale, Locale(identifier: "es_ES"))
            }
        }
    }

    private var tarjetaContacto: some View {
        TarjetaSeccion(titulo: "Contacto del alumno", simbolo: "envelope") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    CampoEtiquetado(etiqueta: "Teléfono", valor: $alumno.telefono)
                    CampoEtiquetado(etiqueta: "Email", valor: $alumno.email)
                }
                GridRow {
                    CampoEtiquetado(etiqueta: "Dirección actual", valor: $alumno.direccionActual)
                    CampoEtiquetado(etiqueta: "Código postal", valor: $alumno.codigoPostal)
                }
                GridRow {
                    CampoEtiquetado(etiqueta: "Localidad actual", valor: $alumno.localidadActual)
                    Color.clear.frame(height: 0)
                }
            }
        }
    }

    private var tarjetaFamilia: some View {
        TarjetaSeccion(titulo: "Familia y tutores", simbolo: "person.2") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    CampoEtiquetado(etiqueta: "Nombre del padre", valor: $alumno.nombrePadre)
                    CampoEtiquetado(etiqueta: "Nombre de la madre", valor: $alumno.nombreMadre)
                }
                GridRow {
                    CampoEtiquetado(etiqueta: "Teléfono tutor 1", valor: $alumno.telefonoTutor1)
                    CampoEtiquetado(etiqueta: "Email tutor 1", valor: $alumno.emailTutor1)
                }
                GridRow {
                    CampoEtiquetado(etiqueta: "Teléfono tutor 2", valor: $alumno.telefonoTutor2)
                    CampoEtiquetado(etiqueta: "Email tutor 2", valor: $alumno.emailTutor2)
                }
                GridRow {
                    CampoEtiquetado(etiqueta: "Tutor legal (si aplica)", valor: $alumno.tutorLegal)
                    CampoEtiquetado(etiqueta: "Teléfono tutor legal", valor: $alumno.telefonoTutorLegal)
                }
            }
            Divider()
            HStack(spacing: 24) {
                Toggle("Padres separados", isOn: $alumno.padresSeparados)
                Toggle("No se hablan", isOn: $alumno.padresNoSeHablan)
                Toggle("Emancipado", isOn: $alumno.emancipado)
            }
            .toggleStyle(.checkbox)
        }
    }

    private var tarjetaPracticas: some View {
        TarjetaSeccion(titulo: "Prácticas y convalidaciones", simbolo: "briefcase") {
            Toggle("Tiene prácticas (FCT)", isOn: $alumno.tienePracticas)
                .toggleStyle(.switch)
            if alumno.tienePracticas {
                CampoEtiquetado(etiqueta: "Empresa de prácticas", valor: $alumno.empresaPracticas)
            }
            Divider()
            Picker("Convalidación por experiencia laboral", selection: $alumno.convalidacionExperiencia) {
                ForEach(ConvalidacionExperiencia.allCases) { Text($0.rawValue).tag($0) }
            }
            if alumno.tieneConvalidacionExperiencia {
                HStack(spacing: 8) {
                    Text("Horas en vida laboral")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Horas", value: $alumno.horasVidaLaboral, format: .number)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                    Text("/ 1000 requeridas")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if alumno.horasExperienciaInsuficientes {
                    Label("Aún no llega a las 1000 h necesarias para convalidar.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Divider()
            CampoEtiquetado(etiqueta: "Asignaturas convalidadas", valor: $alumno.asignaturasConvalidadas, eje: .vertical)
        }
    }

    private var tarjetaAutorizaciones: some View {
        TarjetaSeccion(titulo: "Autorizaciones y académico", simbolo: "checkmark.seal") {
            Toggle("Autorización de comunicación (mayor de edad) firmada", isOn: $alumno.autorizacionComunicacionFirmada)
            Toggle("No quiere firmar la autorización", isOn: $alumno.rechazaFirmarAutorizacion)
                .disabled(alumno.autorizacionComunicacionFirmada)
            switch alumno.estadoAutorizacion {
            case .pendiente:
                Label("Es mayor de edad y aún no consta la autorización firmada.",
                      systemImage: "clock.fill")
                    .font(.caption).foregroundStyle(.orange)
            case .rechazada:
                Label("El alumno se niega a firmar la autorización.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red)
            case .firmada, .noAplica:
                EmptyView()
            }
            Divider()
            Toggle("Inglés convalidado / exento", isOn: $alumno.inglesConvalidado)
        }
        .toggleStyle(.switch)
    }

    private var tarjetaSalud: some View {
        TarjetaSeccion(titulo: "Salud y observaciones", simbolo: "note.text") {
            CampoEtiquetado(etiqueta: "Alergias / cuestiones médicas", valor: $alumno.alergiasMedico, eje: .vertical)
            Divider()
            CampoEtiquetado(etiqueta: "Observaciones", valor: $alumno.observaciones, eje: .vertical)
        }
    }

    // MARK: - Tutorías del alumno (inline)

    private var tarjetaTutorias: some View {
        TarjetaSeccion(titulo: "Tutorías (\(alumno.tutorias.count))", simbolo: "calendar.badge.clock") {
            let ordenadas = alumno.tutorias.sorted { $0.fecha > $1.fecha }
            if ordenadas.isEmpty {
                Text("Sin tutorías registradas.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(ordenadas) { tutoria in
                    Button { tutoriaEnEdicion = tutoria } label: {
                        HStack {
                            Image(systemName: tutoria.realizada ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundStyle(tutoria.realizada ? .green : .secondary)
                            Text(tutoria.fecha.formatted(Formatos.fechaMedia))
                            Text("· \(tutoria.modalidad.rawValue) · \(tutoria.interlocutor.rawValue)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !tutoria.temasTratados.isEmpty {
                                Text(tutoria.temasTratados).lineLimit(1).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                let t = Tutoria(modalidad: Ajustes.modalidadDefecto, alumno: alumno)
                modelContext.insert(t)
                tutoriaEnEdicion = t
                if Ajustes.autoSyncNuevas {
                    Task { _ = await SincronizadorCalendario.shared.sincronizar(t) }
                }
            } label: {
                Label("Añadir tutoría", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Necesidades del alumno (inline)

    private var tarjetaNecesidades: some View {
        TarjetaSeccion(titulo: "Necesidades especiales (\(alumno.necesidades.count))", simbolo: "cross.case") {
            if alumno.necesidades.isEmpty {
                Text("Sin necesidades registradas.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(alumno.necesidades) { necesidad in
                    Button { necesidadEnEdicion = necesidad } label: {
                        HStack {
                            Image(systemName: necesidad.tipo.simbolo)
                                .foregroundStyle(.tint)
                            Text(necesidad.tipo.rawValue).fontWeight(.medium)
                            if !necesidad.descripcionDiagnostico.isEmpty {
                                Text("· \(necesidad.descripcionDiagnostico)")
                                    .foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                let n = NecesidadEspecial(alumno: alumno)
                modelContext.insert(n)
                necesidadEnEdicion = n
            } label: {
                Label("Añadir necesidad", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
    }
}

/// Contenedor de sheet con botón "Hecho" para reutilizar los editores de detalle.
struct EditorEnSheet<Contenido: View>: View {
    var titulo: String
    @ViewBuilder var contenido: Contenido
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            contenido
                .navigationTitle(titulo)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Hecho") { dismiss() }
                    }
                }
        }
        .frame(minWidth: 520, minHeight: 480)
    }
}
