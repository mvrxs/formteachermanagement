//
//  GestionTutorialApp.swift
//  GestionTutorial
//
//  App multiplataforma (macOS + iOS). En iOS los datos sincronizan con iCloud
//  (CloudKit privado, cifrado); en macOS el almacenamiento es local.
//

import SwiftUI
import SwiftData

@main
struct GestionTutorialApp: App {
    @AppStorage(ClaveAjuste.apariencia) private var apariencia = Apariencia.sistema.rawValue
    @AppStorage(ClaveAjuste.idioma) private var idioma = Idioma.sistema.rawValue

    @State private var gestorActualizaciones = GestorActualizaciones()

    init() {
        Ajustes.registrarPorDefecto()
    }

    private var localeSeleccionado: Locale? {
        Idioma(rawValue: idioma)?.locale
    }

    /// Contenedor SwiftData. En iOS usa CloudKit (base privada del usuario,
    /// cifrada por Apple); en macOS se mantiene local por el modelo de reparto.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Alumno.self,
            Tutoria.self,
            NecesidadEspecial.self,
        ])

        func crear(_ cloudKit: ModelConfiguration.CloudKitDatabase) throws -> ModelContainer {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: cloudKit)
            return try ModelContainer(for: schema, configurations: [config])
        }

        #if os(iOS)
        // Intenta CloudKit (iCloud privado, cifrado). Si no hay cuenta/entitlement
        // (p. ej. simulador sin iCloud), cae a almacenamiento local para no fallar.
        do {
            return try crear(.automatic)
        } catch {
            do { return try crear(.none) }
            catch { fatalError("No se pudo crear el ModelContainer: \(error)") }
        }
        #else
        do {
            return try crear(.none)
        } catch {
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
        #endif
    }()

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            ContentView()
                .preferredColorScheme(Apariencia(rawValue: apariencia)?.colorScheme)
                .environment(\.locale, localeSeleccionado ?? Locale.autoupdatingCurrent)
                .environment(gestorActualizaciones)
                .alertasActualizacion(gestorActualizaciones)
                .task { gestorActualizaciones.buscarAlArrancar() }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Buscar actualizaciones…") {
                    gestorActualizaciones.buscarManual()
                }
                .disabled(gestorActualizaciones.comprobando)
            }
        }

        Settings {
            AjustesView()
                .environment(\.locale, localeSeleccionado ?? Locale.autoupdatingCurrent)
                .environment(gestorActualizaciones)
                .alertasActualizacion(gestorActualizaciones)
        }
        .modelContainer(sharedModelContainer)
        #else
        WindowGroup {
            RaiziOS()
                .preferredColorScheme(Apariencia(rawValue: apariencia)?.colorScheme)
                .environment(\.locale, localeSeleccionado ?? Locale.autoupdatingCurrent)
                .environment(gestorActualizaciones)
        }
        .modelContainer(sharedModelContainer)
        #endif
    }
}
