import SwiftUI
import Hybrid12Engine

struct SetRow: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer
    let item: SessionItem
    let index: Int
    let suggestion: Suggestion
    let session: Session

    var body: some View {
        let entry = store.entry(item.key)
        let set = index < entry.sets.count ? entry.sets[index] : LoggedSet()
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18)

            weightControl(set)

            NumberField(placeholder: "\(item.high)", value: set.reps.map { Double($0) }, decimal: false) { value in
                store.update(item.key, sets: item.sets) { $0.sets[index].reps = value.map { Int($0) } }
            }
            Text(unitWord(item.unit))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                toggle(set)
            } label: {
                Image(systemName: set.ticked ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(set.ticked ? Theme.done : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.ticked ? "Set \(index + 1) done" : "Mark set \(index + 1) done")
        }
    }

    @ViewBuilder
    private func weightControl(_ set: LoggedSet) -> some View {
        switch item.equipment ?? .bw {
        case .kb:
            let bell = set.weight ?? suggestion.weight ?? 35
            Button {
                store.setWeight(Suggestions.nextBellInCycle(bell), item: item, set: index, applyToLater: true)
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
                NumberField(placeholder: suggestion.weight.map { lb($0) } ?? "lb", value: set.weight) { value in
                    store.setWeight(value, item: item, set: index)
                }
                Text("lb").font(.caption).foregroundStyle(.secondary)
            }
        default:
            EmptyView()
        }
    }

    private func toggle(_ set: LoggedSet) {
        let ticking = !set.ticked
        hideKeyboard()
        store.update(item.key, sets: item.sets) { e in
            e.sets[index].ticked = ticking
            if ticking, e.sets[index].weight == nil, item.equipment != .bw, let w = suggestion.weight {
                e.sets[index].weight = w
            }
        }
        guard ticking else { return }
        if item.startsPair,
           let partner = session.items.first(where: { $0.pair == item.pair && $0.position == 1 }) {
            timer.start(seconds: RestTimer.transitionSeconds, label: "Transition to \(partner.name)")
        } else {
            timer.start(seconds: item.restSeconds, label: "Rest")
        }
    }
}

/// Numeric text field that keeps what you type (like "2.") and saves the number.
struct NumberField: View {
    let placeholder: String
    let value: Double?
    var decimal: Bool = true
    let onChange: (Double?) -> Void

    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(decimal ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .frame(width: 64)
            .padding(.vertical, 8)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 8))
            .onAppear { text = Self.format(value) }
            .onChange(of: value) { _, newValue in
                if Self.parse(text) != newValue { text = Self.format(newValue) }
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

    private static func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private static func format(_ value: Double?) -> String {
        value.map { lb($0) } ?? ""
    }
}
