//
//  RaiziOS.swift
//  GestionTutorial
//
//  Raíz de la app en iOS/iPadOS: TabView con barra Liquid Glass (aplicada por el
//  sistema en iOS 26). Cada pestaña usa NavigationSplitView, que en iPhone se
//  colapsa a navegación por pila y en iPad muestra lista + detalle.
//

#if os(iOS)
import SwiftUI
import SwiftData

struct RaiziOS: View {
    @State private var alumnoSeleccionado: Alumno?
    @State private var tutoriaSeleccionada: Tutoria?
    @State private var necesidadSeleccionada: NecesidadEspecial?

    var body: some View {
        TabView {
            Tab("Alumnos", systemImage: "person.2.fill") {
                NavigationSplitView {
                    AlumnosListView(seleccion: $alumnoSeleccionado)
                } detail: {
                    if let alumno = alumnoSeleccionado {
                        AlumnoDetailView(alumno: alumno)
                            .id(alumno.persistentModelID)
                    } else {
                        PlaceholderDetalle(texto: "Selecciona un alumno", simbolo: "person.crop.circle")
                    }
                }
            }

            Tab("Tutorías", systemImage: "calendar.badge.clock") {
                NavigationSplitView {
                    TutoriasListView(seleccion: $tutoriaSeleccionada)
                } detail: {
                    if let tutoria = tutoriaSeleccionada {
                        TutoriaDetailView(tutoria: tutoria)
                            .id(tutoria.persistentModelID)
                    } else {
                        CalendarioTutoriasView(seleccion: $tutoriaSeleccionada)
                    }
                }
            }

            Tab("Necesidades", systemImage: "cross.case.fill") {
                NavigationSplitView {
                    NecesidadesListView(seleccion: $necesidadSeleccionada)
                } detail: {
                    if let necesidad = necesidadSeleccionada {
                        NecesidadDetailView(necesidad: necesidad)
                            .id(necesidad.persistentModelID)
                    } else {
                        PlaceholderDetalle(texto: "Selecciona una necesidad", simbolo: "cross.case")
                    }
                }
            }

            Tab("Ajustes", systemImage: "gearshape") {
                AjustesView()
            }
        }
    }
}
#endif
