import Foundation

/// Adaptive 4: coming back after missed days. Weeks never move by the calendar;
/// time off only makes the first sessions back lighter (and can restart the week).
///
/// | Days since last session | Response |
/// | 0-6   | Normal |
/// | 7-13  | First session back × 0.9 on all weights, no progression that session |
/// | 14-27 | × 0.85 for 2 sessions; restart the week at Day 1 |
/// | 28+   | × 0.8 for 2 sessions; restart the week; offer to restart the current phase |
public enum ReEntry {
    public struct Plan: Equatable, Sendable {
        /// Days between the last session before the break and the return.
        public var daysOff: Int
        public var factor: Double
        /// Lighter sessions left, counting today.
        public var sessionsLeft: Int
        /// True only before the first session back (the week should start over).
        public var restartWeek: Bool
        public var offerPhaseRestart: Bool
        public var percent: Int { Int((factor * 100).rounded()) }
    }

    /// `logDates`: every logged session (any order). Nil when nothing applies.
    public static func plan(logDates: [Date], now: Date, calendar: Calendar = .current) -> Plan? {
        let dates = logDates.filter { $0 <= now }.sorted(by: >)
        guard let last = dates.first else { return nil }
        let off = days(from: last, to: now, calendar: calendar)
        if off >= 7 {
            return tier(off).map { Plan(daysOff: off, factor: $0.factor, sessionsLeft: $0.sessions,
                                        restartWeek: off >= 14, offerPhaseRestart: off >= 28) }
        }
        // One session done since a long break: the second lighter session.
        if dates.count >= 2 {
            let before = days(from: dates[1], to: dates[0], calendar: calendar)
            if let t = tier(before), t.sessions >= 2 {
                return Plan(daysOff: before, factor: t.factor, sessionsLeft: t.sessions - 1,
                            restartWeek: false, offerPhaseRestart: false)
            }
        }
        return nil
    }

    static func tier(_ days: Int) -> (factor: Double, sessions: Int)? {
        switch days {
        case ..<7: return nil
        case ..<14: return (0.9, 1)
        case ..<28: return (0.85, 2)
        default: return (0.8, 2)
        }
    }

    static func days(from a: Date, to b: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: a), to: calendar.startOfDay(for: b)).day ?? 0
    }

    /// The Today banner. Pushy: it's a ramp back, not a day off.
    public static func message(_ p: Plan) -> String {
        if !p.restartWeek && p.sessionsLeft == 1 && p.daysOff >= 14 {
            return "Second session back. \(p.percent)% one more time, then we push again."
        }
        var text = "\(p.daysOff) days off. Today runs at \(p.percent)% with no weight increases"
        text += p.sessionsLeft > 1 ? " (this session and the next)." : "."
        if p.restartWeek { text += " The week starts over from Day 1." }
        return text + " Earn it back."
    }
}
