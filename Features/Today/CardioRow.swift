import SwiftUI
import Hybrid12Engine

/// Engine workouts, finishers and the easy run: rounds (or minutes) and a tick.
/// A ticked item with no rounds typed logs the planned rounds.
struct CardioRow: View {
    @Environment(AppStore.self) private var store
    let item: SessionItem
    @State private var showTimer = false

    var body: some View {
        let entry = store.entry(item.key)
        VStack(alignment: .leading, spacing: 10) {
            if item.kind != .run {
                Button { showTimer = true } label: {
                    HStack {
                        Image(systemName: "bell.fill")
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Round timer").font(.subheadline.weight(.heavy))
                            Text(RoundPlan.summary(RoundTimer.saved(for: item))).font(.caption)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(Theme.onAccent)
                    .padding(12)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: max(Theme.look.radius - 6, 2)))
                }
                .buttonStyle(.plain)
                .fullScreenCover(isPresented: $showTimer) { RoundTimerView(item: item) }
            }
            if item.kind == .finisher, let start = item.startWeight {
                HStack {
                    Text("Weight").font(.subheadline)
                    NumberField(placeholder: lb(start), value: entry.sets.first?.weight) { value in
                        store.update(item.key, sets: 1) { $0.sets[0].weight = value }
                    }
                    Text("lb").font(.caption).foregroundStyle(Theme.secondary)
                }
            }

            HStack {
                Text(roundsLabel).font(.subheadline)
                NumberField(placeholder: "\(item.rounds ?? 0)", value: entry.rounds.map { Double($0) }, decimal: false) { value in
                    store.update(item.key) { $0.rounds = value.map { Int($0) } }
                }
                Spacer()
                Button {
                    hideKeyboard()
                    store.update(item.key) { $0.ticked.toggle() }
                } label: {
                    Image(systemName: entry.ticked ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundStyle(entry.ticked ? Theme.done : Theme.secondary)
                }
                .buttonStyle(.plain)
            }

            if item.kind == .run {
                HStack {
                    Text("Miles").font(.subheadline)
                    NumberField(placeholder: "0", value: entry.miles) { value in
                        store.update(item.key) { $0.miles = value }
                    }
                }
                Picker("How did it feel?", selection: Binding(
                    get: { entry.runRating },
                    set: { rating in store.update(item.key) { $0.runRating = rating } }
                )) {
                    Text("Felt easy").tag(Optional(RunRating.feltEasy))
                    Text("Solid").tag(Optional(RunRating.solid))
                    Text("Too hard").tag(Optional(RunRating.tooHard))
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var roundsLabel: String {
        switch item.kind {
        case .run: return "Minutes"
        default: return item.unit == .min ? "Minutes done" : "Rounds done"
        }
    }
}
