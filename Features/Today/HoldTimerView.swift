import AudioToolbox
import SwiftUI
import Hybrid12Engine

/// Full-screen countdown for a timed hold. At zero it logs the seconds,
/// ticks the set and starts the rest. Stop early logs what you held.
struct HoldTimerView: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var rest
    @Environment(HoldTimer.self) private var hold
    @State private var lastBeep = -1
    @State private var phaseShown = -1

    var body: some View {
        let look = Theme.look
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let pos = hold.position(at: context.date)
            let phase = pos.phase.map { hold.phases[$0] }
            VStack(spacing: 24) {
                Text(hold.target?.name ?? "").font(look.title(34)).multilineTextAlignment(.center)
                    .padding(.top, 40)
                Text(phase?.label.uppercased() ?? "DONE")
                    .font(.system(size: 18, weight: .heavy, design: look.bodyDesign))
                    .tracking(2)
                    .foregroundStyle(color(phase?.kind))
                ZStack {
                    Circle().stroke(look.field, lineWidth: 18)
                    Circle()
                        .trim(from: 0, to: fraction(pos, phase))
                        .stroke(color(phase?.kind), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(pos.finished ? "✓" : "\(pos.remaining)")
                        .font(look.number(130))
                        .monospacedDigit()
                        .foregroundStyle(look.text)
                }
                .frame(width: 300, height: 300)
                Text("Target \(hold.target?.seconds ?? 0) sec\(hold.phases.count > 2 ? " each side" : "")")
                    .font(.subheadline).foregroundStyle(look.secondary)
                Spacer()
                HStack(spacing: 10) {
                    Button { hold.cancel() } label: {
                        Text("Cancel").font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(look.card, in: RoundedRectangle(cornerRadius: max(look.radius - 4, 2)))
                            .overlay(RoundedRectangle(cornerRadius: max(look.radius - 4, 2)).stroke(look.line))
                    }
                    .buttonStyle(.plain)
                    Button { finish(held: stopValue(pos)) } label: {
                        Text(phase?.kind == .countIn ? "Get ready…" : "Stop · log \(stopValue(pos)) sec").accentButton(height: 60)
                    }
                    .buttonStyle(.plain)
                    .disabled(phase?.kind == .countIn)
                    .opacity(phase?.kind == .countIn ? 0.5 : 1)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(look.background)
            .onChange(of: pos) { _, p in react(p) }
        }
    }

    /// Beeps on the last 3 seconds of each phase and at each change; logs at the end.
    private func react(_ p: HoldPlan.Position) {
        if p.finished {
            AudioServicesPlaySystemSound(1016)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            finish(held: hold.target?.seconds ?? p.held)
            return
        }
        let index = p.phase ?? -1
        if index != phaseShown {
            if phaseShown >= 0 {
                AudioServicesPlaySystemSound(1057)
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            phaseShown = index
            lastBeep = -1
        }
        if p.remaining <= 3, p.remaining != lastBeep {
            lastBeep = p.remaining
            AudioServicesPlaySystemSound(1103)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func stopValue(_ p: HoldPlan.Position) -> Int {
        guard let target = hold.target else { return 0 }
        if p.finished { return target.seconds }
        // Second side counts what's held on it; first side or a plain hold counts so far.
        return max(p.held, 1)
    }

    private func finish(held: Int) {
        guard let target = hold.target else { return }
        hold.cancel()
        let session = store.session
        guard let item = session.item(target.key) else { return }
        SetTick.toggle(item, set: target.set, in: session, store: store, timer: rest, reps: held)
    }

    private func fraction(_ p: HoldPlan.Position, _ phase: HoldPlan.Phase?) -> Double {
        guard let phase else { return 1 }
        return Double(p.remaining) / Double(max(phase.seconds, 1))
    }

    private func color(_ kind: HoldPlan.Kind?) -> Color {
        switch kind {
        case .hold: return Theme.accent
        case .countIn, .switchSides: return Color(hex: 0xFBBF24)
        case nil: return Theme.done
        }
    }
}

/// Starts the hold timer for a timed set.
enum HoldStart {
    static func start(_ item: SessionItem, set index: Int, store: AppStore, hold: HoldTimer) {
        let set = store.entry(item.key).sets[safe: index]
        hold.start(.init(key: item.key, set: index, seconds: set?.reps ?? set?.plannedReps ?? item.high, name: item.name),
                   eachSide: item.side)
    }
}
