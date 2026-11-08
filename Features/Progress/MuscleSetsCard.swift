import SwiftUI
import Hybrid12Engine

/// Hard sets per muscle in the last 7 days against the 10-20 range.
struct MuscleSetsCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let look = Theme.look
        let sets = store.muscleSets()
        Card(title: "Sets per muscle · last 7 days") {
            BodyMap(sets: sets)
            Text("10-20 hard sets a week is the growth range. Helpers count half.")
                .font(.caption).foregroundStyle(look.secondary)
            ForEach(Muscle.allCases, id: \.self) { m in
                let n = sets[m] ?? 0
                HStack(spacing: 10) {
                    Text(m.name).font(.subheadline).frame(width: 92, alignment: .leading)
                    GeometryReader { g in
                        let scale = g.size.width / 25
                        ZStack(alignment: .leading) {
                            Capsule().fill(look.field)
                            Rectangle().fill(look.done.opacity(0.18))
                                .frame(width: (MuscleMap.high - MuscleMap.low) * scale)
                                .offset(x: MuscleMap.low * scale)
                            Capsule().fill(color(n, look))
                                .frame(width: max(4, min(25, n) * scale))
                        }
                    }
                    .frame(height: 12)
                    Text(n == n.rounded() ? "\(Int(n))" : String(format: "%.1f", n))
                        .font(.subheadline.weight(.bold)).monospacedDigit().frame(width: 36, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(m.name) \(Int(n.rounded())) sets")
            }
        }
    }

    private func color(_ n: Double, _ look: Look) -> Color {
        n < MuscleMap.low ? Color(hex: 0x60A5FA) : n <= MuscleMap.high ? look.done : look.accent
    }
}
