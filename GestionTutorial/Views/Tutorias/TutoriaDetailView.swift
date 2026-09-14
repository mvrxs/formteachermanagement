//
//  TutoriaDetailView.swift
//  GestionTutorial
//
//  Editor de una tutoría (edición en vivo vía @Bindable).
//

import SwiftUI
import SwiftData

struct TutoriaDetailView: View {
    @Bindable var tutoria: Tutoria

    @State private var sincronizando = false
    @State private var mensajeError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TarjetaSeccion(titulo: "Datos de la sesión", simbolo: "calendar") {
                    if let alumno = tutoria.alumno {
                        LabeledContent("Alumno", value: alumno.nombreCompleto)
                    }
                    DatePicker("Fecha", selection: $tutoria.fecha, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, Locale(identifier: "es_ES"))
                    Toggle("Se realizó", isOn: $tutoria.realizada)
                        .toggleStyle(.switch)
                    Picker("Modalidad", selection: $tutoria.modalidad) {
                        ForEach(Modalidad.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Con quién", selection: $tutoria.interlocutor) {
                        ForEach(Interlocutor.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if tutoria.interlocutor == .otro {
                        CampoEtiquetado(etiqueta: "Especificar", valor: $tutoria.interlocutorOtro)
                    }
                }

                tarjetaCalendario

                TarjetaSeccion(titulo: "Contenido", simbolo: "text.bubble") {
                    CampoEtiquetado(etiqueta: "Temas tratados", valor: $tutoria.temasTratados, eje: .vertical)
                    Divider()
                    CampoEtiquetado(etiqueta: "Acuerdos / próximos pasos", valor: $tutoria.acuerdos, eje: .vertical)
                }

                TarjetaSeccion(titulo: "Notas / transcripción", simbolo: "waveform") {
                    Text("Pega aquí el resumen de la grabación.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $tutoria.notasTranscripcion)
                        .font(.body)
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 8))
                }
            }
            .padding(20)
        }
        .navigationTitle("Tutoría")
        .onChange(of: tutoria.fecha) { _, _ in resincronizarSiProcede() }
        .onChange(of: tutoria.modalidadRaw) { _, _ in resincronizarSiProcede() }
        .onChange(of: tutoria.interlocutorRaw) { _, _ in resincronizarSiProcede() }
        .onChange(of: tutoria.temasTratados) { _, _ in resincronizarSiProcede() }
        .onChange(of: tutoria.acuerdos) { _, _ in resincronizarSiProcede() }
        .alert("Calendario de macOS", isPresented: .constant(mensajeError != nil)) {
            Button("OK") { mensajeError = nil }
        } message: {
            Text(mensajeError ?? "")
        }
    }

    private var tarjetaCalendario: some View {
        TarjetaSeccion(titulo: "Calendario de macOS", simbolo: "calendar.badge.plus") {
            Toggle("Sincronizar con el Calendario de macOS", isOn: Binding(
                get: { tutoria.eventKitIdentifier != nil },
                set: { activar in activar ? activarSync() : desactivarSync() }
            ))
            .toggleStyle(.switch)
            .disabled(sincronizando)

            if sincronizando {
                Label("Sincronizando…", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption).foregroundStyle(.secondary)
            } else if tutoria.eventKitIdentifier != nil {
                Label("Este evento está en tu Calendario y se actualiza al editar la tutoría.",
                      systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            } else {
                Text("Crea el evento en tu Calendario nativo (1 h desde la hora indicada).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Sincronización

    private func activarSync() {
        sincronizando = true
        Task {
            let error = await SincronizadorCalendario.shared.sincronizar(tutoria)
            sincronizando = false
            if let error { mensajeError = error }
        }
    }

    private func desactivarSync() {
        let id = tutoria.eventKitIdentifier
        tutoria.eventKitIdentifier = nil
        Task { await SincronizadorCalendario.shared.eliminar(identificador: id) }
    }

    /// Si la tutoría ya está sincronizada, propaga los cambios al evento.
    private func resincronizarSiProcede() {
        guard tutoria.eventKitIdentifier != nil, !sincronizando else { return }
        Task { _ = await SincronizadorCalendario.shared.sincronizar(tutoria) }
    }
}
