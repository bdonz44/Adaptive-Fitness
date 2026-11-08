import SwiftUI
import Hybrid12Engine

/// "What works for you": patterns from your WHOOP data and your lifts.
struct InsightsCard: View {
    @Environment(AppStore.self) private var store
    @Environment(WhoopService.self) private var whoop
    var limit: Int? = nil

    var body: some View {
        let look = Theme.look
        let all = store.insights
        let shown = limit.map { Array(all.prefix($0)) } ?? all
        if whoop.isConnected {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "What works for you", color: look.accent)
                if shown.isEmpty {
                    Text("Keep training with WHOOP on. After about 3 weeks of sessions this shows what makes you strongest: sleep, recovery, time of day.")
                        .font(.subheadline).foregroundStyle(look.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(shown) { i in
                    VStack(alignment: .leading, spacing: 3) {
                        Label(i.headline, systemImage: "lightbulb.fill").font(.headline)
                        Text(i.detail).font(.subheadline).foregroundStyle(look.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lookCard()
        }
    }
}
