import SwiftUI

struct RootTabView: View {
    @State private var tab = RootTabView.launchTab

    var body: some View {
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

enum Theme {
    static let accent = Color.orange
    static let card = Color(white: 0.11)
    static let field = Color(white: 0.17)
    static let done = Color.green
}
