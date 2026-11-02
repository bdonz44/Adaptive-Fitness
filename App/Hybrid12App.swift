import SwiftUI
import SwiftData
import Hybrid12Engine

@main
struct Hybrid12App: App {
    private let container: ModelContainer
    @State private var store: AppStore
    @State private var timer = RestTimer()

    init() {
        let schema = Schema(Schema12.models)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
        } catch {
            fatalError("Could not open the database: \(error)")
        }
        self.container = container
        let store = AppStore(context: ModelContext(container))
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedDemo") { store.seedDemo() }
        // `-importFile /path/to/hybrid12-data.json` imports a web app export at launch.
        if let path = UserDefaults.standard.string(forKey: "importFile"),
           let data = FileManager.default.contents(atPath: path) {
            do { store.importWebData(try Importer.parse(data)) } catch { print("Import failed: \(error)") }
        }
        #endif
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .environment(timer)
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
