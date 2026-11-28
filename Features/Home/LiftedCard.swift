import SwiftUI
import Charts
import Hybrid12Engine

/// Pounds lifted: this week against last, 12 weeks of bars, and the lifetime total.
struct LiftedCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let look = Theme.look
        let weeks = store.poundsByWeek
        let now = store.poundsThisWeek
        let last = store.poundsLastWeek
        let lifetime = store.poundsLifetime
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Pounds lifted", color: look.accent)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Int(now.rounded()).formatted()).font(look.number(40)).monospacedDigit()
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text("lb this week").font(.caption).foregroundStyle(look.secondary)
                }
                Spacer()
                if last > 0 {
                    let pct = (now - last) / last * 100
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%+.0f%%", pct)).font(.title3.weight(.bold))
                            .foregroundStyle(pct >= 0 ? look.done : look.secondary)
                        Text("vs last week").font(.caption).foregroundStyle(look.secondary)
                    }
                }
            }
            if weeks.contains(where: { $0.pounds > 0 }) {
                Chart(Array(weeks.enumerated()), id: \.offset) { i, w in
                    BarMark(x: .value("Week", w.start, unit: .weekOfYear), y: .value("lb", w.pounds))
                        .foregroundStyle(i == weeks.count - 1 ? look.accent : look.accent.opacity(0.45))
                }
                .chartYAxis(.hidden)
                .frame(height: 90)
            }
            if lifetime > 0 {
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Text(Volume.short(lifetime)).font(look.number(28))
                    Text("lb lifetime").font(.subheadline).foregroundStyle(look.secondary)
                    Spacer()
                }
                if let c = Volume.comparison(lifetime) {
                    Text(c).font(.subheadline.weight(.semibold))
                }
                if let best = store.bestSessionPounds {
                    Text("Biggest session: \(Int(best.pounds.rounded()).formatted()) lb on \(best.date.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption).foregroundStyle(look.secondary)
                }
            } else {
                Text("Every set with a weight counts: weight × reps. Finish a session and it starts adding up.")
                    .font(.caption).foregroundStyle(look.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookCard()
    }
}
