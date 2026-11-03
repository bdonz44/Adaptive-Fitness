import SwiftUI
import Hybrid12Engine

/// "Step 1 · Ramp up" above "Step 2 · Work sets". The steps come from today's
/// work weight (typed in set 1, else the suggestion), show the plates, and can be edited.
struct WarmUpSection: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer
    let item: SessionItem
    let liftID: String
    let session: Session

    var body: some View {
        let work = store.weight(for: item, set: 0, in: session)
        let steps = WarmUp.ramp(lift: liftID, workWeight: work)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step 1 · Ramp up").font(.subheadline.weight(.semibold))
                Spacer()
                if let work { Text("to \(lb(work)) lb").font(.caption).foregroundStyle(Theme.secondary) }
            }
            if work == nil {
                Text(WarmUp.placeholderHint)
                    .font(.caption)
                    .foregroundStyle(Theme.secondary)
            }
            ForEach(Array(steps.enumerated()), id: \.offset) { pair in
                stepRow(pair.offset, pair.element)
            }
            if store.draft.warmWeights != nil {
                Text("Edited weights stay for this session. Clear a box to go back to the plan.")
                    .font(.caption2).foregroundStyle(Theme.secondary)
            }
            Text("Step 2 · Work sets")
                .font(.subheadline.weight(.semibold))
                .padding(.top, 6)
        }
    }

    private func stepRow(_ index: Int, _ step: WarmUpStep) -> some View {
        let ticked = store.draft.warmTicks.contains(index)
        let edited = store.draft.warmWeight(step: index)
        let weight = edited ?? step.weight
        return HStack(spacing: 10) {
            if step.weight != nil || edited != nil {
                NumberField(placeholder: step.weight.map { lb($0) } ?? "–", value: edited ?? step.weight) { value in
                    // Typing the calculated number back (or clearing) returns to the plan.
                    store.setWarmWeight(value == step.weight ? nil : value, step: index)
                }
                Text("× \(step.reps)").monospacedDigit()
                VStack(alignment: .leading, spacing: 0) {
                    if let weight { Text(plates(weight)).font(.caption).foregroundStyle(Theme.secondary) }
                    if edited != nil { Text("edited").font(.caption2.weight(.bold)).foregroundStyle(Theme.accent) }
                }
            } else {
                Text(step.label).monospacedDigit()
            }
            Spacer()
            Button {
                hideKeyboard()
                store.toggleWarmTick(index)
                if !ticked { timer.start(seconds: WarmUp.restSeconds, label: "Warm-up rest") }
            } label: {
                Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(ticked ? Theme.done : Theme.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ticked ? "Warm-up step \(index + 1) done" : "Mark warm-up step \(index + 1) done")
        }
        .font(.subheadline)
    }

    private func plates(_ w: Double) -> String {
        let side = Plates.perSide(w)
        return side.isEmpty ? "Empty bar" : "\(Plates.text(w)) per side"
    }
}
