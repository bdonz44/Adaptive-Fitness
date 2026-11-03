import SwiftUI
import SwiftData
import Hybrid12Engine

@main
struct Hybrid12App: App {
    static let iCloudContainer = "iCloud.com.bdonz44.hybrid12"
    private let container: ModelContainer
    @State private var store: AppStore
    private let timer = RestTimer.shared

    init() {
        RestAlerts.endLeftovers()
        let schema = Schema(Schema12.models)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-initCloudKitSchema") {
            CloudKitSchema.initialize(schema: schema, containerID: Self.iCloudContainer)
        }
        #endif
        let container: ModelContainer
        do {
            // Syncs through the private iCloud database when signed in to iCloud.
            container = try ModelContainer(for: schema, configurations: ModelConfiguration(
                schema: schema, cloudKitDatabase: .private(Self.iCloudContainer)))
        } catch {
            // Without iCloud the same on-device store still works.
            print("iCloud sync unavailable, using on-device storage: \(error)")
            do {
                container = try ModelContainer(for: schema, configurations: ModelConfiguration(
                    schema: schema, cloudKitDatabase: .none))
            } catch {
                fatalError("Could not open the database: \(error)")
            }
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
        RestTimer.shared.contextProvider = { [store] in store.restContext() }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .environment(timer)
                .modelContainer(container)
        }
    }
}
