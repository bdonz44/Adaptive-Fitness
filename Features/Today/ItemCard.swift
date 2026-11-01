import SwiftUI
import Hybrid12Engine

struct ItemCard: View {
    @Environment(AppStore.self) private var store
    let item: SessionItem
    let session: Session

    var body: some View {
        let suggestion = store.suggestion(for: item, in: session)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if !item.tag.isEmpty {
                    Text(item.tag)
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.headline)
                    Text(prescription).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if item.kind == .accessory || item.kind == .engine || item.kind == .finisher {
                    Button {
                        store.swap(item)
                    } label: {
                        Label("Swap", systemImage: "arrow.triangle.2.circlepath").font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text(item.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if item.isLift {
                if !suggestion.reason.isEmpty || suggestion.weight != nil {
                    Text(suggestionLine(suggestion))
                        .font(.footnote.weight(.medium))
                }
                if item.kind == .main, let id = item.exerciseID {
                    WarmUpSection(item: item, liftID: id)
                }
                ForEach(0..<item.sets, id: \.self) { i in
                    SetRow(item: item, index: i, suggestion: suggestion, session: session)
                }
            } else if item.isCardio {
                CardioRow(item: item)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var prescription: String {
        switch item.kind {
        case .main, .accessory:
            let range = item.low == item.high ? "\(item.high)" : "\(item.low)-\(item.high)"
            var text = "\(item.sets) × \(range) \(unitWord(item.unit))"
            if item.side { text += " each side" }
            if item.restSeconds > 0 { text += " · rest \(RestTimer.clock(TimeInterval(item.restSeconds)))" }
            return text
        case .engine:
            let rounds = item.rounds ?? 0
            let minutes = Int((Double(rounds) * (item.minutesPerRound ?? 2)).rounded())
            return "\(rounds) rounds · about \(minutes) min"
        case .finisher:
            let rounds = item.rounds ?? 0
            return item.unit == .min ? "\(rounds) min" : "\(rounds) rounds"
        case .run:
            return "\(item.rounds ?? 0) min easy"
        }
    }

    private func suggestionLine(_ s: Suggestion) -> String {
        guard let w = s.weight else { return s.reason }
        return "Use \(lb(w)) lb. \(s.reason)"
    }
}

func unitWord(_ unit: ExerciseUnit) -> String {
    switch unit {
    case .reps: return "reps"
    case .sec: return "sec"
    case .yd: return "yd"
    case .min: return "min"
    case .rounds: return "rounds"
    }
}

/// 135 -> "135", 27.5 -> "27.5"
func lb(_ w: Double) -> String {
    w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w)
}
