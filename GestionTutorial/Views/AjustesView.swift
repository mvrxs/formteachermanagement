//
//  AjustesView.swift
//  GestionTutorial
//
//  Ventana de preferencias (⌘,). Escena `Settings` en la app.
//

import SwiftUI

struct AjustesView: View {
    @State private var seccion: SeccionAjuste? = .general
    @State private var busqueda = ""

    private var secciones: [SeccionAjuste] {
        busqueda.isEmpty
            ? SeccionAjuste.allCases
            : SeccionAjuste.allCases.filter { $0.titulo.localizedCaseInsensitiveContains(busqueda) }
    }

    var body: some View {
        NavigationSplitView {
            List(secciones, selection: $seccion) { s in
                Label(s.titulo, systemImage: s.simbolo).tag(s)
            }
            .searchable(text: $busqueda, placement: .sidebar, prompt: "Buscar")
            .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 230)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch seccion ?? .general {
                case .general:    AjustesGeneral()
                case .calendario: AjustesCalendario()
                case .curso:      AjustesCurso()
                case .acercaDe:   AjustesAcercaDe()
                }
            }
            .navigationTitle((seccion ?? .general).titulo)
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 660, height: 380)
    }
}

enum SeccionAjuste: String, CaseIterable, Identifiable {
    case general, calendario, curso, acercaDe
    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .general:    return "General"
        case .calendario: return "Calendario"
        case .curso:      return "Curso"
        case .acercaDe:   return "Acerca de"
        }
    }

    var simbolo: String {
        switch self {
        case .general:    return "gearshape"
        case .calendario: return "calendar"
        case .curso:      return "graduationcap"
        case .acercaDe:   return "info.circle"
        }
    }
}

// MARK: - Acerca de

private struct AjustesAcercaDe: View {
    @Environment(GestorActualizaciones.self) private var gestor

    private var version: String {
        let corta = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(corta) (\(build))"
    }

    private var nombreApp: String {
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
            ?? "GestionTutorial"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text(nombreApp)
                .font(.title2.bold())

            HStack(spacing: 6) {
                Text("Versión \(version)")
                Text("ALPHA")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.orange.opacity(0.2), in: .capsule)
                    .foregroundStyle(.orange)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Button {
                gestor.buscarManual()
            } label: {
                if gestor.comprobando {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Comprobando…")
                    }
                } else {
                    Text("Buscar actualizaciones")
                }
            }
            .disabled(gestor.comprobando)

            Divider().padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text("Repositorio")
                    .font(.caption).foregroundStyle(.secondary)
                Link("github.com/mvrxs/formteachermanagement",
                     destination: URL(string: "https://github.com/mvrxs/formteachermanagement")!)
                    .font(.callout)
            }

            Text("© 2026 MvrxStudio · Todos los derechos reservados.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - General

private struct AjustesGeneral: View {
    @AppStorage(ClaveAjuste.apariencia) private var apariencia = Apariencia.sistema.rawValue
    @AppStorage(ClaveAjuste.idioma) private var idioma = Idioma.sistema.rawValue

    var body: some View {
        Form {
            Picker("Apariencia", selection: $apariencia) {
                ForEach(Apariencia.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            Section {
                Picker("Idioma", selection: $idioma) {
                    ForEach(Idioma.ordenados) { Text($0.nombre).tag($0.rawValue) }
                }
                .onChange(of: idioma) { _, nuevo in aplicarIdioma(nuevo) }
            } footer: {
                Text("Cambia el idioma de la app. Algunos textos del sistema pueden requerir reiniciar la app.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    /// Escribe la preferencia de idioma a nivel de sistema (AppleLanguages).
    private func aplicarIdioma(_ raw: String) {
        let idioma = Idioma(rawValue: raw) ?? .sistema
        if let codigo = idioma.codigo {
            UserDefaults.standard.set([codigo], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }
}

// MARK: - Calendario

private struct AjustesCalendario: View {
    @AppStorage(ClaveAjuste.autoSyncNuevas) private var autoSync = false
    @AppStorage(ClaveAjuste.duracionEventoMin) private var duracion = 60
    @AppStorage(ClaveAjuste.recordatorioMin) private var recordatorio = -1

    private let duraciones = [30, 45, 60, 90, 120]
    private let recordatorios = [-1, 0, 5, 10, 15, 30, 60]

    var body: some View {
        Form {
            Section {
                Toggle("Sincronizar automáticamente las tutorías nuevas", isOn: $autoSync)
            } footer: {
                Text("Al crear una tutoría se añadirá sola a tu Calendario de macOS. Si lo dejas apagado, puedes sincronizar cada una desde su ficha.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Picker("Duración del evento", selection: $duracion) {
                    ForEach(duraciones, id: \.self) { Text("\($0) min").tag($0) }
                }
                Picker("Recordatorio", selection: $recordatorio) {
                    ForEach(recordatorios, id: \.self) { min in
                        Text(etiquetaRecordatorio(min)).tag(min)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func etiquetaRecordatorio(_ min: Int) -> String {
        switch min {
        case ..<0:  return "Ninguno"
        case 0:     return "A la hora del evento"
        default:    return "\(min) min antes"
        }
    }
}

// MARK: - Curso académico

private struct AjustesCurso: View {
    @AppStorage(ClaveAjuste.cursoInicio) private var inicioRaw = Date().timeIntervalSinceReferenceDate
    @AppStorage(ClaveAjuste.cursoFin) private var finRaw = Date().timeIntervalSinceReferenceDate

    var body: some View {
        Form {
            Section {
                DatePicker("Inicio del curso", selection: bindingFecha($inicioRaw), displayedComponents: .date)
                DatePicker("Fin del curso", selection: bindingFecha($finRaw), displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "es_ES"))
            } footer: {
                Text("Rango usado para marcar qué alumnos cumplen 18 años durante el curso.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .environment(\.locale, Locale(identifier: "es_ES"))
        .padding()
    }

    private func bindingFecha(_ raw: Binding<Double>) -> Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: raw.wrappedValue) },
            set: { raw.wrappedValue = $0.timeIntervalSinceReferenceDate }
        )
    }
}
