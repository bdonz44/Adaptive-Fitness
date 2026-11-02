import SwiftUI
import SwiftData

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
