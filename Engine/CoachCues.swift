import Foundation

/// The in-workout coach: a target before each lift, a push on the last set,
/// and a call after every set (go up, hold, or drop for the rest).
public enum CoachCues {
    public enum Effort: String, Codable, CaseIterable, Sendable {
        case easy, solid, grind

        /// Reps left in the tank, stored as the item's RIR.
        public var rir: Int {
            switch self {
            case .easy: return 3
            case .solid: return 2
            case .grind: return 0
            }
        }
    }

    public struct Cue: Equatable, Sendable {
        public enum Tone: String, Sendable { case push, steady, ease, done }
        public var tone: Tone
        public var text: String
        /// A weight to use for the item's remaining sets, offered as a button.
        public var newWeight: Double?

        public init(tone: Tone, text: String, newWeight: Double?) {
            self.tone = tone
            self.text = text
            self.newWeight = newWeight
        }
    }

    /// What to beat today, from the last time this lift was logged.
    public static func target(item: SessionItem, record: LiftRecord?, weight: Double?, lightDay: Bool) -> String? {
        guard item.isLift else { return nil }
        if lightDay { return "Light day. Smooth reps, nothing to prove." }
        guard let last = record?.history.last, let lr = last.reps else {
            return "First time logging this. Find a weight that leaves 2 reps in the tank."
        }
        let lw = last.weight
        if let w = weight, let lw, item.equipment != .bw {
            if w > lw { return "Up \(Fmt.lb(w - lw)) lb from last time. Own every rep at \(Fmt.lb(w))." }
            if w < lw { return "Reset to \(Fmt.lb(w)). Fast, clean reps to build back." }
            return lr >= item.high
                ? "Same \(Fmt.lb(w)) as last time. Hit \(item.high) on every set and it goes up."
                : "Last time \(Fmt.lb(w)) × \(lr). Beat it: \(min(lr + 1, item.high))+ reps."
        }
        return lr >= item.high ? "You hit \(lr) last time. Slow the reps down or add a pause."
                               : "Last time \(lr). Beat it."
    }

    /// Said before the last work set of a main lift.
    public static func lastSetPush(item: SessionItem, lightDay: Bool) -> String? {
        guard item.kind == .main, !lightDay else { return nil }
        return "Last set. If the bar is moving fast, go past \(item.high). Extra reps count."
    }

    /// The call after a set. `setsLeft` is how many sets of this item remain.
    public static func afterSet(item: SessionItem, reps: Int?, weight: Double?, effort: Effort?,
                                setsLeft: Int, lightDay: Bool) -> Cue {
        let done = reps ?? item.high
        let step = stepFor(item, weight: weight)
        if setsLeft == 0 {
            if lightDay { return Cue(tone: .done, text: "Done. Banked an easy day.", newWeight: nil) }
            if done >= item.high && effort != .grind {
                return Cue(tone: .done, text: "\(item.name) done. Top of the range: that's how weights go up.", newWeight: nil)
            }
            return Cue(tone: .done, text: "\(item.name) done. Same weight next time, chase \(item.high).", newWeight: nil)
        }
        if lightDay { return Cue(tone: .steady, text: "Easy day. Same again, stay smooth.", newWeight: nil) }
        if done < item.low {
            if let w = weight, let step, w - step > 0 {
                let lower = w - step
                return Cue(tone: .ease, text: "Short of \(item.low). Drop to \(Fmt.lb(lower)) and finish strong.", newWeight: lower)
            }
            return Cue(tone: .ease, text: "Short of \(item.low). Take an extra 30 sec and go again.", newWeight: nil)
        }
        let tooEasy = done >= item.high + 2 || (done >= item.high && effort == .easy)
        if tooEasy, let w = weight, let step {
            return Cue(tone: .push, text: "Too easy. Go \(Fmt.lb(w + step)) next set.", newWeight: w + step)
        }
        if tooEasy {
            return Cue(tone: .push, text: "Too easy. Slow the lowering to 3 seconds next set.", newWeight: nil)
        }
        if effort == .grind {
            return Cue(tone: .steady, text: "That was a fight. Hold the weight, rest the full time.", newWeight: nil)
        }
        if done >= item.high {
            return Cue(tone: .push, text: "Top of the range. Same again: \(item.high) more.", newWeight: nil)
        }
        return Cue(tone: .steady, text: "\(done) in the bag. Chase \(min(done + 1, item.high)) next set.", newWeight: nil)
    }

    /// Weight step for an in-session change: 5 lb (10 lb for a barbell over 200), next bell for kettlebells.
    static func stepFor(_ item: SessionItem, weight: Double?) -> Double? {
        guard let w = weight else { return nil }
        switch item.equipment {
        case .bb: return w >= 200 ? 10 : 5
        case .db: return 5
        case .kb:
            let next = Suggestions.nextBellInCycle(w)
            return next > w ? next - w : nil
        default: return nil
        }
    }

    /// The nudge after a session: when to remind, and what to say.
    public static func nudge(after date: Date, next: Slot, calendar: Calendar = .current) -> (date: Date, text: String) {
        let twoDays = calendar.date(byAdding: .day, value: 2, to: date) ?? date
        let morning = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: twoDays) ?? twoDays
        let name = Program.plan(next).name
        return (morning, "Two days off. \(name) is up next. Get it in today.")
    }
}
