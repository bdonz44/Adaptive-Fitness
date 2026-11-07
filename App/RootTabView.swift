import SwiftUI

struct RootTabView: View {
    @State private var tab = RootTabView.launchTab
    @AppStorage(Look.storageKey) private var lookName = Look.iron.rawValue
    @State private var showLook = false
    @Bindable private var router = NotificationRouter.shared

    var body: some View {
        let look = Look(rawValue: lookName) ?? .iron
        tabs
            .environment(\.openLook, { showLook = true })
            // A new look rebuilds every screen with its colors and fonts.
            .id(look)
            // Outside the rebuilt screens, so it stays open while you try looks.
            .sheet(isPresented: $showLook) { LookSettingsView() }
            .sheet(isPresented: $router.showWeeklyReview) { WeeklyReviewView() }
            .onAppear { Self.styleBars(look) }
            .preferredColorScheme(look.scheme)
            .tint(look.accent)
    }

    /// Navigation and tab bars in the look's colors and title font.
    static func styleBars(_ look: Look) {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(look.background)
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: UIColor(look.text), .font: look.uiTitleFont(17)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(look.text), .font: look.uiTitleFont(36)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(look.background)
        tab.shadowColor = UIColor(look.line)
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.iconColor = UIColor(look.secondary)
            item.normal.titleTextAttributes = [.foregroundColor: UIColor(look.secondary)]
            item.selected.iconColor = UIColor(look.accent)
            item.selected.titleTextAttributes = [.foregroundColor: UIColor(look.accent)]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            HomeView(go: { tab = 1 })
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            TodayView()
                .tabItem { Label("Today", systemImage: "dumbbell") }
                .tag(1)
            ProgressTab()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(2)
            PlanTab()
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(3)
        }
    }
}

extension RootTabView {
    /// Debug builds: `-tab 1` opens Today, `-tab 2` Progress, `-tab 3` Plan (for simulator screenshots). Home is 0.
    static var launchTab: Int {
        #if DEBUG
        return UserDefaults.standard.integer(forKey: "tab")
        #else
        return 0
        #endif
    }
}

private struct OpenLookKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Opens the Look settings sheet.
    var openLook: () -> Void {
        get { self[OpenLookKey.self] }
        set { self[OpenLookKey.self] = newValue }
    }
}
