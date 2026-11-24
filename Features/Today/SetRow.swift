import SwiftUI
import Hybrid12Engine

struct SetRow: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer
    @Environment(HoldTimer.self) private var hold
    let item: SessionItem
    let index: Int
    let suggestion: Suggestion
    let session: Session

    var body: some View {
        let entry = store.entry(item.key)
        let set = index < entry.sets.count ? entry.sets[index] : LoggedSet()
        VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.secondary)
                .frame(width: 18)

            weightControl(set)

            NumberField(placeholder: "\(set.plannedReps ?? item.high)", value: set.reps.map { Double($0) }, decimal: false) { value in
                store.update(item.key, sets: item.sets) { $0.sets[index].reps = value.map { Int($0) } }
            }
            Text(unitWord(item.unit))
                .font(.caption)
                .foregroundStyle(Theme.secondary)

            Spacer()

            if item.unit == .sec && !set.isDone {
                Button {
                    hideKeyboard()
                    HoldStart.start(item, set: index, store: store, hold: hold)
                } label: {
                    Label("Start", systemImage: "timer")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 10).frame(minHeight: 36)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start \(set.reps ?? set.plannedReps ?? item.high) second timer for set \(index + 1)")
            }

            Button {
                toggle(set)
            } label: {
                Image(systemName: set.ticked ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(set.ticked ? Theme.done : Theme.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.ticked ? "Set \(index + 1) done" : "Mark set \(index + 1) done")
        }
            GhostLine(item: item, set: set, index: index).padding(.leading, 28)
        }
    }

    @ViewBuilder
    private func weightControl(_ set: LoggedSet) -> some View {
        switch item.equipment ?? .bw {
        case .kb:
            let bell = set.weight ?? suggestion.weight ?? 35
            Button {
                store.setWeight(Suggestions.nextBellInCycle(bell, gear: store.gear), item: item, set: index, applyToLater: true)
            } label: {
                Text("\(lb(bell)) lb")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .frame(width: 74)
                    .padding(.vertical, 8)
                    .background(Theme.field, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Tap to change the bell")
        case .bb, .db:
            HStack(spacing: 4) {
                NumberField(placeholder: suggestion.weight.map { lb($0) } ?? "–", value: set.weight) { value in
                    store.setWeight(value, item: item, set: index)
                }
                Text("lb").font(.caption).foregroundStyle(Theme.secondary)
            }
        default:
            EmptyView()
        }
    }

    private func toggle(_ set: LoggedSet) {
        hideKeyboard()
        SetTick.toggle(item, set: index, in: session, store: store, timer: timer)
    }
}

/// Numeric text field that keeps what you type (like "2.") and saves the number.
struct NumberField: View {
    let placeholder: String
    let value: Double?
    var decimal: Bool = true
    let onChange: (Double?) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .focused($focused)
            .keyboardType(decimal ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .frame(width: 64)
            .padding(.vertical, 8)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: max(Theme.look.radius / 2, 2)))
            .onAppear { text = Self.format(value) }
            .onChange(of: value) { _, newValue in
                // Not while typing: clearing a box whose value falls back to a suggestion
                // would refill it mid-edit ("95" + "100" -> "95100").
                guard !focused else { return }
                if Self.parse(text) != newValue { text = Self.format(newValue) }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused, Self.parse(text) != value { text = Self.format(value) }
            }
            .onChange(of: text) { _, newText in
                let trimmed = newText.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    if value != nil { onChange(nil) }
                    return
                }
                guard let parsed = Self.parse(trimmed) else { return }
                if parsed != value { onChange(parsed) }
            }
    }

    private static func parse(_ text: String) -> Double? { typedNumber(text) }

    private static func format(_ value: Double?) -> String {
        value.map { lb($0) } ?? ""
    }
}

/// "Last time 185 × 6", and once the set is done: beat it, matched, or short.
struct GhostLine: View {
    @Environment(AppStore.self) private var store
    let item: SessionItem
    let set: LoggedSet
    let index: Int
    var big = false

    var body: some View {
        if item.isLift, let id = item.exerciseID, let last = Ghost.last(store.lifts[id], set: index) {
            let look = Theme.look
            HStack(spacing: 6) {
                Text("Last time \(Ghost.text(last, unit: item.unit))")
                    .font(big ? .subheadline.weight(.semibold) : .caption)
                    .foregroundStyle(look.secondary)
                if set.isDone, let reps = set.reps {
                    let v = Ghost.verdict(weight: item.equipment == .bw ? nil : set.weight, reps: reps, against: last)
                    Label(v == .beat ? "Beat it" : v == .matched ? "Matched" : "Short",
                          systemImage: v == .beat ? "arrow.up.circle.fill" : v == .matched ? "equal.circle.fill" : "arrow.down.circle")
                        .font((big ? Font.subheadline : .caption).weight(.bold))
                        .foregroundStyle(v == .beat ? look.done : v == .matched ? look.text : look.secondary)
                } else if !set.isDone {
                    Text("Beat it.").font((big ? Font.subheadline : .caption).weight(.bold)).foregroundStyle(look.accent)
                }
            }
        }
    }
}
