//
//  NecesidadesListView.swift
//  GestionTutorial
//
//  Registro global de necesidades especiales.
//

import SwiftUI
import SwiftData

struct NecesidadesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var seleccion: NecesidadEspecial?

    @Query private var necesidades: [NecesidadEspecial]
    @Query(sort: [SortDescriptor(\Alumno.apellidos), SortDescriptor(\Alumno.nombre)])
    private var alumnos: [Alumno]

    private var ordenadas: [NecesidadEspecial] {
        necesidades.sorted {
            ($0.alumno?.nombreCompleto ?? "") < ($1.alumno?.nombreCompleto ?? "")
        }
    }

    var body: some View {
        List(selection: $seleccion) {
            ForEach(ordenadas) { necesidad in
                FilaNecesidad(necesidad: necesidad)
                    .tag(necesidad)
                    .contextMenu {
                        Button(role: .destructive) {
                            borrarNecesidad(necesidad)
                        } label: {
                            Label("Eliminar necesidad", systemImage: "trash")
                        }
                    }
            }
            .onDelete(perform: borrar)
        }
        .onDeleteCommand {
            if let seleccion { borrarNecesidad(seleccion) }
        }
        .navigationTitle("Necesidades")
        .navigationSubtitle("\(necesidades.count) registradas")
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 420)
        .toolbar {
            ToolbarItem {
                Menu {
                    if alumnos.isEmpty {
                        Text("Primero añade alumnos")
                    } else {
                        ForEach(alumnos) { alumno in
                            Button(alumno.nombreCompleto) { nueva(para: alumno) }
                        }
                    }
                } label: {
                    Label("Nueva necesidad", systemImage: "plus")
                }
            }
        }
        .overlay {
            if necesidades.isEmpty {
                ContentUnavailableView("Sin necesidades", systemImage: "cross.case",
                                       description: Text("Crea una con + eligiendo un alumno."))
            }
        }
    }

    private func nueva(para alumno: Alumno) {
        let n = NecesidadEspecial(alumno: alumno)
        modelContext.insert(n)
        seleccion = n
    }

    private func borrar(_ offsets: IndexSet) {
        for index in offsets {
            borrarNecesidad(ordenadas[index])
        }
    }

    private func borrarNecesidad(_ n: NecesidadEspecial) {
        if n == seleccion { seleccion = nil }
        modelContext.delete(n)
    }
}

struct FilaNecesidad: View {
    let necesidad: NecesidadEspecial

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: necesidad.tipo.simbolo)
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(necesidad.alumno?.nombreCompleto ?? "(Sin alumno)")
                    .fontWeight(.medium).lineLimit(1)
                Text(necesidad.tipo.rawValue)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
