import SwiftUI
import UIKit
import Hybrid12Engine

/// Set rounds, work and rest, then run the round timer full screen.
struct RoundTimerView: View {
    @Environment(AppStore.self) private var store
    @Environment(RoundTimer.self) private var timer
    @Environment(HeartRateMonitor.self) private var heart
    @State private var push = HeartPush()
    @Environment(\.dismiss) private var dismiss
    let item: SessionItem
    @State private var settings: RoundPlan.Settings
    @State private var lastPhase = -1
    @State private var warned = -1

    init(item: SessionItem) {
        self.item = item
        _settings = State(initialValue: RoundTimer.saved(for: item))
    }

    var body: some View {
        Group {
            if timer.isRunning && timer.itemKey == item.key { running } else { setup }
        }
        .background(Theme.background)
    }

    // MARK: Setup

    private var setup: some View {
        let look = Theme.look
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button("Close") { dismiss() }.font(.headline)
                Spacer()
            }
            Text(look.uppercaseTitles ? item.name.uppercased() : item.name).font(look.title(38))
            Text(item.detail).font(.subheadline).foregroundStyle(look.secondary)
            stepper("Rounds", value: "\(settings.rounds)",
                    minus: { settings = .init(rounds: settings.rounds - 1, work: settings.work, rest: settings.rest) },
                    plus: { settings = .init(rounds: settings.rounds + 1, work: settings.work, rest: settings.rest) })
            stepper("Round", value: clock(settings.work),
                    minus: { settings = .init(rounds: settings.rounds, work: settings.work - step(settings.work), rest: settings.rest) },
                    plus: { settings = .init(rounds: settings.rounds, work: settings.work + step(settings.work), rest: settings.rest) })
            stepper("Rest", value: settings.rest == 0 ? "None" : clock(settings.rest),
                    minus: { settings = .init(rounds: settings.rounds, work: settings.work, rest: settings.rest - step(settings.rest)) },
                    plus: { settings = .init(rounds: settings.rounds, work: settings.work, rest: settings.rest + step(settings.rest + 1)) })
            Text(RoundPlan.summary(settings)).font(.subheadline.weight(.semibold)).foregroundStyle(look.accent)
            let planned = RoundPlan.defaults(for: item)
            if planned.work != settings.work || planned.rest != settings.rest {
                Button("Back to the plan (\(clock(planned.work)) on, \(planned.rest == 0 ? "no rest" : clock(planned.rest) + " off"))") {
                    settings = .init(rounds: settings.rounds, work: planned.work, rest: planned.rest)
                }
                .font(.footnote)
            }
            Spacer()
            Button {
                RoundTimer.save(settings, for: item)
                timer.start(settings, item: item)
                lastPhase = -1
            } label: { Text("Start").accentButton(height: 64) }
                .buttonStyle(.plain)
            Text("Your round and rest times are remembered for \(item.name).")
                .font(.caption).foregroundStyle(look.secondary)
        }
        .padding(20)
    }

    private func stepper(_ label: String, value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        let look = Theme.look
        return HStack(spacing: 14) {
            Text(label).font(.headline).frame(width: 80, alignment: .leading)
            Spacer()
            roundButton("minus", label: "Less \(label.lowercased())", action: minus)
            Text(value).font(look.number(38)).monospacedDigit().frame(minWidth: 96)
            roundButton("plus", label: "More \(label.lowercased())", action: plus)
        }
        .padding(14)
        .lookCard()
    }

    private func roundButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title3.weight(.bold))
                .frame(width: 48, height: 48)
                .background(Theme.field, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// 15 sec steps up to 2 min, then 30 sec.
    private func step(_ seconds: Int) -> Int { seconds > 120 ? 30 : 15 }

    // MARK: Running

    private var running: some View {
        let look = Theme.look
        return TimelineView(.periodic(from: .now, by: 0.2)) { context in
            let pos = timer.position(at: context.date)
            let phase = pos.phase.map { timer.phases[$0] }
            let color = phaseColor(phase?.kind)
            VStack(spacing: 20) {
                Text(timer.name).font(.headline).foregroundStyle(look.secondary).padding(.top, 30)
                Text(roundLine(phase, pos))
                    .font(look.title(40))
                Text(phaseName(phase?.kind))
                    .font(.system(size: 30, weight: .black, design: look.bodyDesign))
                    .tracking(4)
                    .foregroundStyle(color)
                Text(clock(pos.finished ? 0 : pos.remaining))
                    .font(look.number(150))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(phase?.kind == .work && pos.remaining <= RoundPlan.warning ? color : look.text)
                HStack(spacing: 4) {
                    ForEach(1...timer.settings.rounds, id: \.self) { r in
                        Capsule().fill(r <= pos.roundsDone ? look.accent : (r == phase?.round && phase?.kind == .work ? color : look.field))
                            .frame(height: 10)
                    }
                }
                LiveHeartBar(target: phase?.kind == .work ? HeartRate.target(for: item) : nil)
                Spacer()
                if pos.finished {
                    Button { finish(pos.roundsDone) } label: { Text("Log \(pos.roundsDone) rounds").accentButton(height: 64) }
                        .buttonStyle(.plain)
                } else {
                    HStack(spacing: 10) {
                        control(timer.isPaused ? "Resume" : "Pause", filled: true) {
                            timer.isPaused ? timer.resume() : timer.pause()
                        }
                        control(phase?.kind == .rest || phase?.kind == .getReady ? "Skip rest" : "End round", filled: false) {
                            timer.skip()
                        }
                    }
                    Button("Stop and log \(pos.roundsDone) rounds") { finish(pos.roundsDone) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(look.secondary)
                        .frame(minHeight: 44)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(phase?.kind == .work ? color.opacity(0.12) : look.background)
            .onChange(of: pos) { _, p in react(p) }
            .onChange(of: heart.lastReading) { _, _ in
                push.update(bpm: heart.freshBPM(), max: heart.maxHR, target: HeartRate.target(for: item),
                            working: phase?.kind == .work && !timer.isPaused)
            }
        }
    }

    private func react(_ p: RoundPlan.Position) {
        let index = p.phase ?? timer.phases.count
        if index != lastPhase {
            if lastPhase >= 0 {
                let kind = p.phase.map { timer.phases[$0].kind }
                timer.play(kind == .work ? "bell-start" : "bell-end")
                UINotificationFeedbackGenerator().notificationOccurred(kind == .work ? .warning : .success)
            }
            lastPhase = index
            warned = -1
        }
        if let i = p.phase, timer.phases[i].kind == .work, p.remaining == RoundPlan.warning, warned != i,
           timer.phases[i].seconds > RoundPlan.warning {
            warned = i
            timer.play("clack")
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        if let i = p.phase, timer.phases[i].kind != .work, p.remaining <= 3, p.remaining > 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func finish(_ rounds: Int) {
        let logged = RoundPlan.logged(roundsDone: rounds, settings: timer.settings, unit: item.unit)
        timer.stop()
        store.update(item.key) { e in
            e.rounds = logged
            e.ticked = logged > 0
        }
        dismiss()
    }

    private func control(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        let look = Theme.look
        return Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: look.bodyDesign))
                .foregroundStyle(filled ? look.onAccent : look.text)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(filled ? look.accent : look.card, in: RoundedRectangle(cornerRadius: max(look.radius - 4, 2)))
                .overlay(RoundedRectangle(cornerRadius: max(look.radius - 4, 2)).stroke(filled ? .clear : look.line))
        }
        .buttonStyle(.plain)
    }

    private func roundLine(_ phase: RoundPlan.Phase?, _ pos: RoundPlan.Position) -> String {
        guard let phase else { return "All \(timer.settings.rounds) rounds" }
        switch phase.kind {
        case .getReady: return "Round 1 of \(timer.settings.rounds)"
        case .work: return "Round \(phase.round) of \(timer.settings.rounds)"
        case .rest: return "Round \(phase.round + 1) next"
        }
    }

    private func phaseName(_ kind: RoundPlan.Kind?) -> String {
        switch kind {
        case .getReady: return timer.isPaused ? "PAUSED" : "GET READY"
        case .work: return timer.isPaused ? "PAUSED" : "WORK"
        case .rest: return timer.isPaused ? "PAUSED" : "REST"
        case nil: return "DONE"
        }
    }

    private func phaseColor(_ kind: RoundPlan.Kind?) -> Color {
        switch kind {
        case .work: return Color(hex: 0xEF4444)
        case .rest: return Color(hex: 0x22C55E)
        case .getReady: return Color(hex: 0xFBBF24)
        case nil: return Theme.done
        }
    }

    private func clock(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}
