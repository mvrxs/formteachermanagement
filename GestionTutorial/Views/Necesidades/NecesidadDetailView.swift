//
//  NecesidadDetailView.swift
//  GestionTutorial
//
//  Editor de una necesidad especial (edición en vivo vía @Bindable).
//

import SwiftUI
import SwiftData

struct NecesidadDetailView: View {
    @Bindable var necesidad: NecesidadEspecial

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TarjetaSeccion(titulo: "Tipo", simbolo: necesidad.tipo.simbolo) {
                    if let alumno = necesidad.alumno {
                        LabeledContent("Alumno", value: alumno.nombreCompleto)
                    }
                    Picker("Tipo de necesidad", selection: $necesidad.tipo) {
                        ForEach(TipoNecesidad.allCases) { tipo in
                            Label(tipo.rawValue, systemImage: tipo.simbolo).tag(tipo)
                        }
                    }
                }

                TarjetaSeccion(titulo: "Detalle", simbolo: "doc.text") {
                    CampoEtiquetado(etiqueta: "Descripción / diagnóstico", valor: $necesidad.descripcionDiagnostico, eje: .vertical)
                    Divider()
                    CampoEtiquetado(etiqueta: "Adaptaciones aplicadas", valor: $necesidad.adaptacionesAplicadas, eje: .vertical)
                    Divider()
                    CampoEtiquetado(etiqueta: "Observaciones", valor: $necesidad.observaciones, eje: .vertical)
                }
            }
            .padding(20)
        }
        .navigationTitle("Necesidad especial")
    }
}
