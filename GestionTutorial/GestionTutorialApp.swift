//
//  GestionTutorialApp.swift
//  GestionTutorial
//
//  Created by Marcos on 13/09/2026.
//

import SwiftUI
import SwiftData

@main
struct GestionTutorialApp: App {
    @AppStorage(ClaveAjuste.apariencia) private var apariencia = Apariencia.sistema.rawValue
    @AppStorage(ClaveAjuste.idioma) private var idioma = Idioma.sistema.rawValue

    init() {
        Ajustes.registrarPorDefecto()
    }

    private var localeSeleccionado: Locale? {
        Idioma(rawValue: idioma)?.locale
    }

    /// Contenedor SwiftData 100% local (sin CloudKit). Datos sensibles de menores.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Alumno.self,
            Tutoria.self,
            NecesidadEspecial.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(Apariencia(rawValue: apariencia)?.colorScheme)
                .environment(\.locale, localeSeleccionado ?? Locale.autoupdatingCurrent)
        }
        .modelContainer(sharedModelContainer)

        Settings {
            AjustesView()
                .environment(\.locale, localeSeleccionado ?? Locale.autoupdatingCurrent)
        }
        .modelContainer(sharedModelContainer)
    }
}
