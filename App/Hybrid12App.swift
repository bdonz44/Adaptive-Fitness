import SwiftUI
import SwiftData
import UserNotifications
import Hybrid12Engine

@main
struct Hybrid12App: App {
    static let iCloudContainer = "iCloud.com.bdonz44.hybrid12"
    private let container: ModelContainer
    @State private var store: AppStore
    private let timer = RestTimer.shared
    @State private var hold = HoldTimer()
    @State private var rounds = RoundTimer()
    @State private var whoop = WhoopService()
    @State private var heart = HeartRateMonitor()
    @State private var progress = ProgressStore()
    @Environment(\.scenePhase) private var scenePhase
    /// Launch and coming back to the app both sync; never two at once.
    @State private var whoopSyncRunning = false

    init() {
        RestAlerts.endLeftovers()
        RoundTimer.cancelLeftovers()
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
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
        RestTimer.shared.workoutProvider = { [store] in store.lockScreenWorkoutActive }
        RestTimer.shared.tickHandler = { [store] in store.tickNextFromLockScreen() }
    }

    /// Fetches today's WHOOP numbers (at most every 20 min) and sets readiness from them.
    @MainActor
    private func syncWhoop() async {
        guard !whoopSyncRunning else { return }
        whoopSyncRunning = true
        defer { whoopSyncRunning = false }
        await whoop.sync()
        store.applyWhoop(whoop.today)
        await store.backfillWhoop { [whoop] start, end in await whoop.workouts(from: start, to: end) }
        await store.refreshWhoopCardio { [whoop] start, end in await whoop.workouts(from: start, to: end) }
        await store.refreshWhoopHistory { [whoop] in await whoop.history() }
        await store.refreshHealthFood { await HealthService.shared.foodDays(since: Date().addingTimeInterval(-60 * 86400)) }
        await store.refreshHealthVO2 { await HealthService.shared.vo2Max(since: Date().addingTimeInterval(-365 * 86400)) }
        store.refreshWidget(recovery: whoop.today?.recovery)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .environment(timer)
                .environment(hold)
                .environment(rounds)
                .environment(whoop)
                .environment(heart)
                .environment(progress)
                .modelContainer(container)
                .task {
                    // A workout still running after a relaunch gets its Lock Screen back.
                    RestTimer.shared.showWorkout()
                    WeeklyReviewNotice.schedule(store.adaptive.weeklyReview)
                    await syncWhoop()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await syncWhoop() } }
                }
        }
    }
}
