import SwiftUI
import Hybrid12Engine

/// Bottom bar while resting. Tap the time to open the full-screen timer.
struct RestTimerBar: View {
    @Environment(RestTimer.self) private var timer
    var expand: () -> Void = {}

    var body: some View {
        let look = Theme.look
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = timer.remaining(at: context.date)
            let finished = remaining <= 0
            HStack(spacing: 12) {
                Button(action: expand) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(timer.label)
                            .font(.caption)
                            .foregroundStyle(look.secondary)
                            .lineLimit(1)
                        Text(finished ? "Go" : RestTimer.clock(remaining))
                            .font(look.number(34))
                            .monospacedDigit()
                            .foregroundStyle(finished ? look.done : look.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the full-screen timer")
                Button("+30s") { timer.addThirty() }
                    .font(.subheadline.weight(.bold))
                    .frame(width: 64, height: 44)
                    .background(look.field, in: RoundedRectangle(cornerRadius: max(look.radius - 6, 2)))
                    .buttonStyle(.plain)
                Button("Done") { timer.done() }
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(look.onAccent)
                    .frame(width: 64, height: 44)
                    .background(look.accent, in: RoundedRectangle(cornerRadius: max(look.radius - 6, 2)))
                    .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(look.card.opacity(0.97))
            .overlay(alignment: .top) { Rectangle().fill(look.line).frame(height: 1) }
            .sensoryFeedback(.success, trigger: finished) { old, new in !old && new }
        }
    }
}

/// Full-screen rest: a countdown ring, the next set and big buttons.
struct RestView: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer
    let close: () -> Void

    var body: some View {
        let look = Theme.look
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = timer.remaining(at: context.date)
            let total = max(timer.total, 1)
            let finished = remaining <= 0
            VStack(spacing: 22) {
                HStack {
                    Button(action: close) {
                        Image(systemName: "chevron.down").font(.title3.weight(.bold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    Spacer()
                    SectionLabel(text: timer.label)
                    Spacer()
                    WorkoutClock(compact: true).fixedSize()
                }
                ZStack {
                    Circle().stroke(look.field, lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: remaining / total)
                        .stroke(finished ? look.done : look.accent, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Text(finished ? "Go" : RestTimer.clock(remaining))
                            .font(look.number(92))
                            .monospacedDigit()
                            .foregroundStyle(finished ? look.done : look.text)
                        Text("of \(RestTimer.clock(total))").font(.subheadline).foregroundStyle(look.secondary)
                    }
                }
                .frame(width: 290, height: 290)
                .padding(.top, 10)

                LiveHeartBar(compact: true)
                CoachCueCard()
                if let next = nextLine {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: "Next")
                        Text(next).font(.headline)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lookCard()
                }
                Spacer()
                HStack(spacing: 10) {
                    bigButton("−15s", filled: false) { timer.minusFifteen() }
                    bigButton("+30s", filled: false) { timer.addThirty() }
                    bigButton(finished ? "Go" : "Skip", filled: true) { timer.done() }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(look.background)
            .sensoryFeedback(.success, trigger: finished) { old, new in !old && new }
        }
    }

    private var nextLine: String? {
        let next = store.restContext().next
        return next.isEmpty ? nil : next
    }

    private func bigButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        let look = Theme.look
        return Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .heavy, design: look.bodyDesign))
                .foregroundStyle(filled ? look.onAccent : look.text)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(filled ? look.accent : look.card, in: RoundedRectangle(cornerRadius: max(look.radius - 4, 2)))
                .overlay(RoundedRectangle(cornerRadius: max(look.radius - 4, 2)).stroke(filled ? .clear : look.line))
        }
        .buttonStyle(.plain)
    }
}
