import SwiftUI
import SwiftData

@main
struct clipclipApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Project.self,
            Track.self,
            Clip.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            let storeURL = modelConfiguration.url
            let auxiliarySuffixes = ["", "-wal", "-shm"]
            for suffix in auxiliarySuffixes {
                let file = storeURL.deletingLastPathComponent().appendingPathComponent(storeURL.lastPathComponent + suffix)
                try? FileManager.default.removeItem(at: file)
            }
            do {
                print("Deleted existing model files. Attempting to create ModelContainer again.")
                return try ModelContainer(for: schema, configurations: [modelConfiguration])

            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
    }
}
