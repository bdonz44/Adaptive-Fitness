import SwiftUI
import Hybrid12Engine

struct ItemCard: View {
    @Environment(AppStore.self) private var store
    let item: SessionItem
    let session: Session

    var body: some View {
        let suggestion = store.suggestion(for: item, in: session)
        let isNow = store.nextOpenSet?.key == item.key
        let active = store.activeSets(item)
        let skipped = store.entry(item.key).skipped
        let finished = item.isLift && skipped == nil && store.entry(item.key).sets.prefix(active).filter(\.isDone).count >= active
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if !item.tag.isEmpty {
                    Text(item.tag)
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.name).font(.system(size: 18, weight: .bold, design: Theme.look.bodyDesign))
                        if finished { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.done) }
                        if let id = item.exerciseID { HowToButton(exerciseID: id) }
                    }
                    Text(prescription).font(.subheadline).foregroundStyle(Theme.secondary)
                }
                Spacer()
                if (item.kind == .accessory || item.kind == .engine || item.kind == .finisher) && skipped == nil && !item.isExtra && item.canSwap {
                    Button {
                        store.swap(item)
                    } label: {
                        Label("Swap", systemImage: "arrow.triangle.2.circlepath").font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                if item.isLift { ExerciseMenu(item: item) }
            }

            if let skipped {
                HStack {
                    Text("Skipped today · \(skipped)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondary)
                    Spacer()
                    Button("Bring it back") { store.skip(item, reason: nil) }
                        .font(.subheadline.weight(.bold))
                }
            } else if let last = store.lastSkip(item) {
                Label("Skipped last time (\(last.lowercased())).\(item.kind == .accessory ? " Tap Swap for a different move." : " Go light and see how it feels.")",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(hex: 0xF59E0B))
            }

            if skipped == nil {
            Text(item.detail)
                .font(.footnote)
                .foregroundStyle(Theme.secondary)

            if item.isLift {
                if !suggestion.reason.isEmpty || suggestion.weight != nil {
                    Text(suggestionLine(suggestion))
                        .font(.footnote.weight(.medium))
                }
                if item.kind == .main, let id = item.exerciseID {
                    WarmUpSection(item: item, liftID: id, session: session)
                }
                ForEach(0..<active, id: \.self) { i in
                    SetRow(item: item, index: i, suggestion: suggestion, session: session)
                }
            } else if item.isCardio {
                CardioRow(item: item)
            }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookCard(highlight: isNow)
        .opacity(skipped == nil ? 1 : 0.6)
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

/// All sets done, Remove a set, Skip exercise.
struct ExerciseMenu: View {
    @Environment(AppStore.self) private var store
    let item: SessionItem
    static let reasons = ["Pain", "No time", "No equipment", "Other"]

    var body: some View {
        let e = store.entry(item.key)
        Menu {
            if item.isExtra {
                Button(role: .destructive) { store.removeExtra(item) } label: {
                    Label("Remove from today", systemImage: "trash")
                }
            }
            if e.skipped == nil {
                Button { store.markAllDone(item) } label: { Label("All sets done", systemImage: "checkmark.circle.fill") }
                Button { store.removeSet(item) } label: { Label("Remove a set", systemImage: "minus.circle") }
                    .disabled(store.activeSets(item) <= 1)
                if (e.removedSets ?? 0) > 0 {
                    Button { store.restoreSets(item) } label: { Label("Put removed sets back", systemImage: "plus.circle") }
                }
                Menu {
                    ForEach(Self.reasons, id: \.self) { reason in
                        Button(reason) { store.skip(item, reason: reason) }
                    }
                } label: { Label("Skip exercise", systemImage: "forward.end") }
            } else {
                Button { store.skip(item, reason: nil) } label: { Label("Bring it back", systemImage: "arrow.uturn.backward") }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("More for \(item.name)")
    }
}
