import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "dumbbell") }
            ComingSoonView(title: "Progress", detail: "Weigh-ins, waist, cardio, charts and the coach check arrive in milestone 3.")
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            ComingSoonView(title: "Plan", detail: "The 12-week plan, jump to week and start over arrive in milestone 3.")
                .tabItem { Label("Plan", systemImage: "calendar") }
        }
    }
}

struct ComingSoonView: View {
    let title: String
    let detail: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "hammer")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(detail)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .navigationTitle(title)
        }
    }
}

enum Theme {
    static let accent = Color.orange
    static let card = Color(white: 0.11)
    static let field = Color(white: 0.17)
    static let done = Color.green
}
