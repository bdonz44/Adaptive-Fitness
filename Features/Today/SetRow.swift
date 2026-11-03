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
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.secondary)
                .frame(width: 18)

            weightControl(set)

            NumberField(placeholder: "\(item.high)", value: set.reps.map { Double($0) }, decimal: false) { value in
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
                .accessibilityLabel("Start \(set.reps ?? item.high) second timer for set \(index + 1)")
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

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(decimal ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .frame(width: 64)
            .padding(.vertical, 8)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: max(Theme.look.radius / 2, 2)))
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
