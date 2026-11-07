import SwiftUI
import UIKit
import Hybrid12Engine

/// Live heart rate with the zone, and the target band during work.
/// Shown on the round timer, the rest screen and Today when live heart rate is on.
struct LiveHeartBar: View {
    @Environment(HeartRateMonitor.self) private var heart
    /// Target during work (% of max); nil shows just the zone.
    var target: ClosedRange<Int>?
    var compact = false

    var body: some View {
        if heart.isEnabled {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                content(bpm: heart.freshBPM(at: context.date))
            }
        }
    }

    @ViewBuilder
    private func content(bpm: Int?) -> some View {
        let look = Theme.look
        let max = heart.maxHR
        let status = bpm.flatMap { b in target.map { HeartRate.status(bpm: b, max: max, target: $0) } }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(bpm == nil ? look.secondary : Self.zoneColor(HeartRate.zone(bpm: bpm!, max: max)))
                    .symbolEffect(.pulse, isActive: bpm != nil)
                Text(bpm.map(String.init) ?? "--")
                    .font(look.number(compact ? 28 : 44)).monospacedDigit()
                Text("bpm").font(.caption.weight(.semibold)).foregroundStyle(look.secondary)
                if let b = bpm {
                    Text("Zone \(HeartRate.zone(bpm: b, max: max)) · \(HeartRate.percent(bpm: b, max: max))%")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(look.secondary)
                }
                Spacer()
                if let status {
                    Text(Self.label(status))
                        .font(.system(size: compact ? 13 : 16, weight: .black, design: look.bodyDesign))
                        .tracking(1)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .foregroundStyle(status == .inZone ? look.onAccent : .white)
                        .background(Self.statusColor(status), in: Capsule())
                } else if bpm == nil {
                    Text(stateText).font(.caption).foregroundStyle(look.secondary)
                }
            }
            if !compact {
                bar(bpm: bpm, max: max)
                if let target {
                    Text("Target \(HeartRate.targetText(target, max: max)) (\(target.lowerBound)-\(target.upperBound)% of max \(max))")
                        .font(.caption).foregroundStyle(look.secondary)
                }
            }
        }
        .padding(compact ? 12 : 14)
        .lookCard()
        .accessibilityElement(children: .combine)
    }

    /// 50-100% of max, with the target band shaded and a marker at the current rate.
    private func bar(bpm: Int?, max: Int) -> some View {
        GeometryReader { g in
            let x = { (pct: Int) -> CGFloat in CGFloat(Swift.min(100, Swift.max(50, pct)) - 50) / 50 * g.size.width }
            ZStack(alignment: .leading) {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { z in
                        Rectangle().fill(Self.zoneColor(z).opacity(0.35))
                    }
                }
                .clipShape(Capsule())
                if let t = target {
                    Capsule().stroke(Theme.text, lineWidth: 2)
                        .frame(width: x(t.upperBound) - x(t.lowerBound))
                        .offset(x: x(t.lowerBound))
                }
                if let b = bpm {
                    Circle().fill(Theme.text)
                        .frame(width: 16, height: 16)
                        .offset(x: x(HeartRate.percent(bpm: b, max: max)) - 8)
                        .animation(.easeOut(duration: 0.4), value: b)
                }
            }
        }
        .frame(height: 16)
    }

    private var stateText: String {
        switch heart.state {
        case .off: return "Off"
        case .bluetoothOff: return "Bluetooth is off"
        case .notAllowed: return "Bluetooth not allowed"
        case .searching: return "Looking for WHOOP…"
        case .connecting: return "Connecting…"
        case .connected: return "No reading yet"
        }
    }

    static func label(_ s: HeartRate.Status) -> String {
        switch s {
        case .below: return "PUSH"
        case .inZone: return "IN ZONE"
        case .above: return "EASE UP"
        }
    }

    static func statusColor(_ s: HeartRate.Status) -> Color {
        switch s {
        case .below: return Color(hex: 0x2563EB)
        case .inZone: return Theme.done
        case .above: return Color(hex: 0xDC2626)
        }
    }

    static func zoneColor(_ zone: Int) -> Color {
        switch zone {
        case 0, 1: return Color(hex: 0x60A5FA)
        case 2: return Color(hex: 0x22C55E)
        case 3: return Color(hex: 0xFACC15)
        case 4: return Color(hex: 0xF97316)
        default: return Color(hex: 0xEF4444)
        }
    }
}

/// Buzzes when heart rate sits under the target during work: after 8 seconds below,
/// then at most every 20 seconds until it's back in the zone.
struct HeartPush {
    private var belowSince: Date?
    private var lastBuzz: Date?

    mutating func update(bpm: Int?, max: Int, target: ClosedRange<Int>?, working: Bool, now: Date = Date()) {
        guard working, let bpm, let target, HeartRate.status(bpm: bpm, max: max, target: target) == .below else {
            belowSince = nil
            return
        }
        let since = belowSince ?? now
        belowSince = since
        guard now.timeIntervalSince(since) >= 8, now.timeIntervalSince(lastBuzz ?? .distantPast) >= 20 else { return }
        lastBuzz = now
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

/// The WHOOP card on the Finish screen: WHOOP's strain and zones for this session,
/// or the live heart rate the app recorded while WHOOP finishes scoring.
struct FinishHeartCard: View {
    @Environment(WhoopService.self) private var whoop
    @Environment(HeartRateMonitor.self) private var heart
    @Environment(AppStore.self) private var store
    let summary: FinishSummary
    @State private var workout: WhoopWorkout?
    @State private var checking = false
    @State private var checked = false

    var body: some View {
        let look = Theme.look
        if whoop.isConnected || summary.heart != nil {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: workout != nil ? "WHOOP" : "Heart rate", color: look.accent)
                if let w = workout {
                    HStack(spacing: 18) {
                        stat(w.strain.map { String(format: "%.1f", $0) } ?? "--", "Strain")
                        stat(w.averageHR.map(String.init) ?? "--", "Avg bpm")
                        stat(w.maxHR.map(String.init) ?? "--", "Max bpm")
                        if let c = w.calories { stat("\(c)", "Calories") }
                    }
                    zones(w.zoneSeconds)
                } else if let h = summary.heart {
                    HStack(spacing: 18) {
                        stat("\(h.average)", "Avg bpm")
                        stat("\(h.peak)", "Max bpm")
                        stat(minutes(h.hardSeconds), "Zone 4-5")
                    }
                    zones(h.zoneSeconds)
                }
                if workout == nil && whoop.isConnected {
                    HStack {
                        Text(checking ? "Checking WHOOP…"
                             : checked ? "WHOOP hasn't scored this workout yet. Start an activity in WHOOP next time, or check again in a few minutes."
                             : "")
                            .font(.caption).foregroundStyle(look.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        if checked && !checking {
                            Button("Check again") { Task { await check() } }.font(.caption.weight(.bold))
                        }
                    }
                }
            }
            .padding(16)
            .lookCard()
            .task { await check() }
        }
    }

    private func check() async {
        guard whoop.isConnected, let start = summary.startedAt else { checked = true; return }
        checking = true
        defer { checking = false; checked = true }
        let list = await whoop.workouts(from: start.addingTimeInterval(-1800), to: summary.finishedAt.addingTimeInterval(1800))
        workout = list.flatMap { WhoopWorkout.match($0, start: start, end: summary.finishedAt) }
        if let w = workout { store.attachWhoop(w, toLogAt: summary.finishedAt) }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.look.number(28)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(Theme.secondary)
        }
    }

    /// Minutes in zones 1-5 as a stacked bar with labels.
    private func zones(_ seconds: [Double]) -> some View {
        let total = max(seconds.dropFirst().reduce(0, +), 1)
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { z in
                        Rectangle().fill(LiveHeartBar.zoneColor(z))
                            .frame(width: max(0, g.size.width * seconds[z] / total - 2))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)
            HStack {
                ForEach(1...5, id: \.self) { z in
                    Text("Z\(z) \(minutes(seconds[z]))").font(.caption2.monospacedDigit()).foregroundStyle(Theme.secondary)
                    if z < 5 { Spacer(minLength: 2) }
                }
            }
        }
    }

    private func minutes(_ s: Double) -> String { "\(Int((s / 60).rounded()))m" }
}

/// "Start workout" before the session begins; a running clock after.
struct WorkoutClock: View {
    @Environment(AppStore.self) private var store
    var compact = false

    var body: some View {
        let look = Theme.look
        if let start = store.draft.startedAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 8) {
                    Image(systemName: "stopwatch.fill").foregroundStyle(look.accent)
                    Text(Self.elapsed(from: start, to: context.date))
                        .font(look.number(compact ? 22 : 30)).monospacedDigit()
                    if !compact {
                        Text("since \(start.formatted(date: .omitted, time: .shortened))")
                            .font(.caption).foregroundStyle(look.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, compact ? 0 : 14).padding(.vertical, compact ? 0 : 10)
                .background(compact ? Color.clear : look.card, in: RoundedRectangle(cornerRadius: max(look.radius - 6, 2)))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Workout time \(Self.elapsed(from: start, to: context.date))")
            }
        } else if !compact {
            Button { store.startWorkout() } label: {
                Label("Start workout", systemImage: "play.fill").accentButton(height: 60)
            }
            .buttonStyle(.plain)
        }
    }

    /// "12:34" or "1:02:03"
    static func elapsed(from start: Date, to now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(start)))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
                         : String(format: "%d:%02d", s / 60, s % 60)
    }
}
