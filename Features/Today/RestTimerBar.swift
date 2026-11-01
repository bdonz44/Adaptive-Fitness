import SwiftUI

struct RestTimerBar: View {
    @Environment(RestTimer.self) private var timer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = timer.remaining(at: context.date)
            let finished = remaining <= 0
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(timer.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(finished ? "Go" : RestTimer.clock(remaining))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(finished ? Theme.done : Color.primary)
                }
                Spacer()
                Button("+30s") { timer.addThirty() }
                    .buttonStyle(.bordered)
                Button("Done") { timer.done() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .sensoryFeedback(.success, trigger: finished) { old, new in !old && new }
        }
    }
}
