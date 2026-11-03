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
        if lightDay { return "Light day. Crisp reps, perfect form. Save the fight for next week." }
        guard let last = record?.history.last, let lr = last.reps else {
            return "First time logging this. Find a weight that leaves 2 reps in the tank, then we push."
        }
        let lw = last.weight
        if let w = weight, let lw, item.equipment != .bw {
            if w > lw { return "Up \(Fmt.lb(w - lw)) lb from last time. You earned it. Own every rep at \(Fmt.lb(w))." }
            if w < lw { return "Reset to \(Fmt.lb(w)). Make it look easy, then we climb again." }
            return lr >= item.high
                ? "Same \(Fmt.lb(w)) as last time. \(item.high) on every set and it goes up. No excuses."
                : "Last time \(Fmt.lb(w)) × \(lr). Not today. Beat it: \(min(lr + 1, item.high))+ reps."
        }
        return lr >= item.high ? "You hit \(lr) last time. Too easy. Slow every rep down and add a pause."
                               : "Last time \(lr). Beat it. One more rep, minimum."
    }

    /// Said before the last work set of every lift.
    public static func lastSetPush(item: SessionItem, lightDay: Bool) -> String? {
        guard item.isLift, !lightDay else { return nil }
        if item.kind != .main { return "Last set. Every rep you can get, clean form, then put it down." }
        return "Last set. Empty the tank: go past \(item.high) if the bar is still moving. Every extra rep counts."
    }

    /// The call after a set. `setsLeft` is how many sets of this item remain.
    public static func afterSet(item: SessionItem, reps: Int?, weight: Double?, effort: Effort?,
                                setsLeft: Int, lightDay: Bool) -> Cue {
        let done = reps ?? item.high
        let step = stepFor(item, weight: weight)
        if setsLeft == 0 {
            if lightDay { return Cue(tone: .done, text: "Done. Easy day banked. Next week we go hard.", newWeight: nil) }
            if done >= item.high && effort != .grind {
                return Cue(tone: .done, text: "\(item.name) done. Top of the range. That weight is going up.", newWeight: nil)
            }
            return Cue(tone: .done, text: "\(item.name) done. Same weight next time, and you're taking \(item.high).", newWeight: nil)
        }
        if lightDay { return Cue(tone: .steady, text: "Easy day. Same again, perfect reps.", newWeight: nil) }
        if done < item.low {
            if let w = weight, let step, w - step > 0 {
                let lower = w - step
                return Cue(tone: .ease, text: "Short of \(item.low). Drop to \(Fmt.lb(lower)) and finish every set strong. No quitting.", newWeight: lower)
            }
            return Cue(tone: .ease, text: "Short of \(item.low). Take 30 extra seconds and get it back.", newWeight: nil)
        }
        let tooEasy = done > item.high || (done >= item.high && effort == .easy)
        if tooEasy, let w = weight, let step {
            return Cue(tone: .push, text: "Too easy. Go \(Fmt.lb(w + step)) next set. Prove it.", newWeight: w + step)
        }
        if tooEasy {
            return Cue(tone: .push, text: "Too easy. 3-second lowering next set. Make it hurt.", newWeight: nil)
        }
        if effort == .grind {
            return Cue(tone: .steady, text: "That was a fight. Good. Hold the weight, full rest, win the next one.", newWeight: nil)
        }
        if done >= item.high {
            return Cue(tone: .push, text: "Top of the range. Do it again: \(item.high) more, no drop-off.", newWeight: nil)
        }
        return Cue(tone: .steady, text: "\(done) in the bag. Next set: \(min(done + 1, item.high)). Go get it.", newWeight: nil)
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
        return (morning, "Two days off. \(name) is waiting. No more excuses: get it in today.")
    }
}
