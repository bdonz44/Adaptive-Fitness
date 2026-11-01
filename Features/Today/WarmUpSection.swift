import SwiftUI
import Hybrid12Engine

/// "Step 1 · Ramp up" above "Step 2 · Work sets", built from the weight typed in set 1.
struct WarmUpSection: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer
    let item: SessionItem
    let liftID: String

    var body: some View {
        let work = store.entry(item.key).sets.first?.weight
        let steps = WarmUp.ramp(lift: liftID, workWeight: work)
        VStack(alignment: .leading, spacing: 6) {
            Text("Step 1 · Ramp up").font(.subheadline.weight(.semibold))
            if work == nil {
                Text(WarmUp.placeholderHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(steps.enumerated()), id: \.offset) { pair in
                stepRow(pair.offset, pair.element)
            }
            Text("Step 2 · Work sets")
                .font(.subheadline.weight(.semibold))
                .padding(.top, 6)
        }
    }

    private func stepRow(_ index: Int, _ step: WarmUpStep) -> some View {
        let ticked = store.draft.warmTicks.contains(index)
        return HStack {
            Text(step.label).monospacedDigit()
            if let plates = step.plates {
                Text(plates).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                store.toggleWarmTick(index)
                if !ticked { timer.start(seconds: WarmUp.restSeconds, label: "Warm-up rest") }
            } label: {
                Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(ticked ? Theme.done : Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .font(.subheadline)
    }
}
