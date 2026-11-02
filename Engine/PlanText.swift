import Foundation

/// Plan tab text: the three phases, the 12 weeks of the current cycle and the sessions.
public enum PlanText {
    public static func focus(_ phase: Phase) -> String {
        switch phase {
        case .foundation: return "Heavier compound lifts, clean technique, set baseline numbers."
        case .build: return "More sets and supersets; extra shoulder, chest, arm and back volume."
        case .define: return "Faster pace, shorter rest, longer finishers; lean out, hold muscle."
        }
    }

    /// "Weeks 1-4"
    public static func weeks(_ phase: Phase) -> String {
        let start = phase.rawValue * 4 + 1
        return "Weeks \(start)-\(start + 3)"
    }

    /// "Main 4 × 5, rest 2:30 · Accessories 3 × 10-12, rest 1:15 · 2 superset pairs"
    public static func scheme(_ phase: Phase) -> String {
        let s = PhaseScheme.of(phase)
        return "Main \(s.mainSets) × \(range(s.mainLow, s.mainHigh)), rest \(clock(s.mainRest))"
            + " · Accessories \(s.accSets) × \(range(s.accLow, s.accHigh)), rest \(clock(s.accRest))"
            + " · \(s.pairs) superset pairs"
    }

    public enum WeekStatus: Equatable, Sendable { case past, current, upcoming }

    public struct PlanWeek: Equatable, Sendable, Identifiable {
        /// Week within the cycle, 1-12.
        public var wk: Int
        public var phase: Phase
        public var isDeload: Bool
        public var status: WeekStatus
        public var id: Int { wk }
    }

    /// The 12 weeks of the cycle that contains `week`.
    public static func cycleWeeks(current week: Int) -> [PlanWeek] {
        let now = ProgramWeek(week)
        return (1...12).map { wk in
            let pw = ProgramWeek(wk)
            let status: WeekStatus = wk < now.wk ? .past : (wk == now.wk ? .current : .upcoming)
            return PlanWeek(wk: wk, phase: pw.phase, isDeload: pw.isDeload, status: status)
        }
    }

    /// One line per session for a phase, in week order:
    /// "Day 1 · Upper Physique: Overhead Press + 2 superset pairs + finisher"
    public static func sessions(_ phase: Phase, runMinutes: Int = Program.defaultRunMinutes,
                                catalog: Catalog = .bundled) -> [String] {
        (Program.order + [.R]).map { slot in
            let plan = Program.plan(slot)
            let label = plan.day.map { "Day \($0) · \(plan.name)" } ?? plan.name
            var parts: [String] = []
            if let id = plan.mainLift(for: phase) {
                parts.append(catalog.exercise(id)?.name ?? id)
            }
            switch slot {
            case .C:
                parts.append("Engine workout")
                parts.append("1 core pair")
            case .R:
                return "\(label): \(runMinutes) min at a conversational pace. Never counts toward the five."
            default:
                parts.append("\(PhaseScheme.of(phase).pairs) superset pairs")
                parts.append("finisher")
            }
            return "\(label): " + parts.joined(separator: " + ")
        }
    }

    static func range(_ low: Int, _ high: Int) -> String { low == high ? "\(low)" : "\(low)-\(high)" }

    /// 150 -> "2:30"
    static func clock(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
}
