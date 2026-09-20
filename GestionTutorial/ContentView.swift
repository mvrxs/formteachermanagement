//
//  ContentView.swift
//  GestionTutorial
//
//  Ventana raíz: barra lateral Liquid Glass + contenido según sección.
//

import SwiftUI
import SwiftData

#if os(macOS)
enum Seccion: String, CaseIterable, Identifiable {
    case alumnos = "Alumnos"
    case tutorias = "Tutorías"
    case necesidades = "Necesidades"

    var id: String { rawValue }

    var simbolo: String {
        switch self {
        case .alumnos:     return "person.2.fill"
        case .tutorias:    return "calendar.badge.clock"
        case .necesidades: return "cross.case.fill"
        }
    }
}

struct ContentView: View {
    @State private var seccion: Seccion = .alumnos
    @State private var alumnoSeleccionado: Alumno?
    @State private var tutoriaSeleccionada: Tutoria?
    @State private var necesidadSeleccionada: NecesidadEspecial?

    var body: some View {
        NavigationSplitView {
            // Barra lateral de secciones
            List(Seccion.allCases, selection: $seccion) { seccion in
                Label(seccion.rawValue, systemImage: seccion.simbolo)
                    .tag(seccion)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 185, max: 220)
            .navigationTitle("1SMX-A")
        } content: {
            // Columna central: lista según sección
            switch seccion {
            case .alumnos:
                AlumnosListView(seleccion: $alumnoSeleccionado)
            case .tutorias:
                TutoriasListView(seleccion: $tutoriaSeleccionada)
            case .necesidades:
                NecesidadesListView(seleccion: $necesidadSeleccionada)
            }
        } detail: {
            // Columna de detalle
            switch seccion {
            case .alumnos:
                if let alumno = alumnoSeleccionado {
                    AlumnoDetailView(alumno: alumno)
                        .id(alumno.persistentModelID)
                } else {
                    PlaceholderDetalle(texto: "Selecciona un alumno", simbolo: "person.crop.circle")
                }
            case .tutorias:
                if let tutoria = tutoriaSeleccionada {
                    TutoriaDetailView(tutoria: tutoria)
                        .id(tutoria.persistentModelID)
                        .toolbar {
                            ToolbarItem(placement: .navigation) {
                                Button {
                                    tutoriaSeleccionada = nil
                                } label: {
                                    Label("Calendario", systemImage: "chevron.left")
                                }
                            }
                        }
                } else {
                    CalendarioTutoriasView(seleccion: $tutoriaSeleccionada)
                }
            case .necesidades:
                if let necesidad = necesidadSeleccionada {
                    NecesidadDetailView(necesidad: necesidad)
                        .id(necesidad.persistentModelID)
                } else {
                    PlaceholderDetalle(texto: "Selecciona una necesidad", simbolo: "cross.case")
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Alumno.self, Tutoria.self, NecesidadEspecial.self], inMemory: true)
}
#endif

/// Placeholder de columna de detalle. Compartido macOS/iOS.
struct PlaceholderDetalle: View {
    var texto: String
    var simbolo: String

    var body: some View {
        ContentUnavailableView(texto, systemImage: simbolo)
    }
}
