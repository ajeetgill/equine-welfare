//
//  equine_welfareApp.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 19/02/25.
//

import SwiftUI
import SwiftData

@main
struct equine_welfareApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Assessment.self,
            Section.self,
            Subsection.self,
            Requirement.self,
            Horse.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            ModelContainer.shared = container
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // UI-test hooks: launch arguments (set only by the UI test runner)
        // that reset state so visual tests are deterministic. No effect on
        // normal launches.
        if CommandLine.arguments.contains("--uitest-reset-auth") {
            PocketBaseService.shared.signOut()
        }
        if CommandLine.arguments.contains("--uitest-wipe-data") {
            try? ModelContext(sharedModelContainer).delete(model: Assessment.self)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
        }
    }
}

extension ModelContainer {
    static var shared: ModelContainer!
}
