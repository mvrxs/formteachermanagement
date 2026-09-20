//
//  TutoriasListView.swift
//  GestionTutorial
//
//  Registro global de tutorías, ordenable por fecha.
//

import SwiftUI
import SwiftData

struct TutoriasListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var seleccion: Tutoria?

    @Query private var tutorias: [Tutoria]
    @Query(sort: [SortDescriptor(\Alumno.apellidos), SortDescriptor(\Alumno.nombre)])
    private var alumnos: [Alumno]

    @State private var descendente = true
    @State private var soloPendientes = false

    private var ordenadas: [Tutoria] {
        var lista = tutorias
        if soloPendientes { lista = lista.filter { !$0.realizada } }
        return lista.sorted { descendente ? $0.fecha > $1.fecha : $0.fecha < $1.fecha }
    }

    var body: some View {
        List(selection: $seleccion) {
            ForEach(ordenadas) { tutoria in
                FilaTutoria(tutoria: tutoria)
                    .tag(tutoria)
                    .contextMenu {
                        Button(role: .destructive) {
                            borrarTutoria(tutoria)
                        } label: {
                            Label("Eliminar tutoría", systemImage: "trash")
                        }
                    }
            }
            .onDelete(perform: borrar)
        }
        #if os(macOS)
        .onDeleteCommand {
            if let seleccion { borrarTutoria(seleccion) }
        }
        #endif
        .navigationTitle("Tutorías")
        .subtituloNavegacion("\(tutorias.count) registradas")
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 420)
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("Orden", selection: $descendente) {
                        Text("Más recientes primero").tag(true)
                        Text("Más antiguas primero").tag(false)
                    }
                    Toggle("Solo pendientes", isOn: $soloPendientes)
                } label: {
                    Label("Filtros", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarSpacer(.fixed)
            ToolbarItem {
                Menu {
                    if alumnos.isEmpty {
                        Text("Primero añade alumnos")
                    } else {
                        ForEach(alumnos) { alumno in
                            Button(alumno.nombreCompleto) { nuevaTutoria(para: alumno) }
                        }
                    }
                } label: {
                    Label("Nueva tutoría", systemImage: "plus")
                }
            }
        }
        .overlay {
            if tutorias.isEmpty {
                ContentUnavailableView("Sin tutorías", systemImage: "calendar.badge.clock",
                                       description: Text("Crea una con + eligiendo un alumno."))
            }
        }
    }

    private func nuevaTutoria(para alumno: Alumno) {
        let t = Tutoria(modalidad: .presencial, alumno: alumno)
        modelContext.insert(t)
        seleccion = t
        if Ajustes.autoSyncNuevas {
            Task { _ = await SincronizadorCalendario.shared.sincronizar(t) }
        }
    }

    private func borrar(_ offsets: IndexSet) {
        for index in offsets {
            borrarTutoria(ordenadas[index])
        }
    }

    private func borrarTutoria(_ t: Tutoria) {
        if t == seleccion { seleccion = nil }
        let eventID = t.eventKitIdentifier
        modelContext.delete(t)
        if eventID != nil {
            Task { await SincronizadorCalendario.shared.eliminar(identificador: eventID) }
        }
    }
}

struct FilaTutoria: View {
    let tutoria: Tutoria

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tutoria.realizada ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(tutoria.realizada ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(tutoria.alumno?.nombreCompleto ?? "(Sin alumno)")
                    .fontWeight(.medium).lineLimit(1)
                HStack(spacing: 6) {
                    Text(tutoria.fecha.formatted(Formatos.fechaMedia))
                    Text("· \(tutoria.modalidad.rawValue) · \(tutoria.interlocutor.rawValue)")
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
