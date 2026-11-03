import SwiftUI

struct RootTabView: View {
    @State private var tab = RootTabView.launchTab
    @AppStorage(Look.storageKey) private var lookName = Look.iron.rawValue
    @State private var showLook = false

    var body: some View {
        let look = Look(rawValue: lookName) ?? .iron
        tabs
            .environment(\.openLook, { showLook = true })
            // A new look rebuilds every screen with its colors and fonts.
            .id(look)
            // Outside the rebuilt screens, so it stays open while you try looks.
            .sheet(isPresented: $showLook) { LookSettingsView() }
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
            TodayView()
                .tabItem { Label("Today", systemImage: "dumbbell") }
                .tag(0)
            ProgressTab()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(1)
            PlanTab()
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(2)
        }
    }
}

extension RootTabView {
    /// Debug builds: `-tab 1` opens Progress, `-tab 2` opens Plan (for simulator screenshots).
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
