import Foundation

/// The timed-hold plan: a 3 sec count-in, the hold, and for each-side moves a
/// 5 sec switch and the second side.
public enum HoldPlan {
    public static let countIn = 3
    public static let switchSides = 5

    public enum Kind: String, Equatable, Sendable { case countIn, hold, switchSides }

    public struct Phase: Equatable, Sendable {
        public var kind: Kind
        public var seconds: Int
        /// "Get set", "Hold", "Left side", "Switch sides", "Right side".
        public var label: String
    }

    public static func phases(seconds: Int, eachSide: Bool) -> [Phase] {
        let hold = max(1, seconds)
        var out = [Phase(kind: .countIn, seconds: countIn, label: "Get set")]
        if eachSide {
            out.append(Phase(kind: .hold, seconds: hold, label: "First side"))
            out.append(Phase(kind: .switchSides, seconds: switchSides, label: "Switch sides"))
            out.append(Phase(kind: .hold, seconds: hold, label: "Second side"))
        } else {
            out.append(Phase(kind: .hold, seconds: hold, label: "Hold"))
        }
        return out
    }

    public struct Position: Equatable, Sendable {
        /// Nil once every phase is over.
        public var phase: Int?
        /// Whole seconds left in the phase (rounded up).
        public var remaining: Int
        /// Seconds held so far on the side being held (for an early stop).
        public var held: Int
        public var finished: Bool { phase == nil }
    }

    /// Where the timer is `elapsed` seconds after Start.
    public static func position(_ phases: [Phase], elapsed: TimeInterval) -> Position {
        var t = max(0, elapsed)
        var heldBefore = 0
        for (i, p) in phases.enumerated() {
            let len = TimeInterval(p.seconds)
            if t < len {
                let held = p.kind == .hold ? Int(t) : 0
                return Position(phase: i, remaining: Int((len - t).rounded(.up)), held: held)
            }
            if p.kind == .hold { heldBefore = p.seconds }
            t -= len
        }
        return Position(phase: nil, remaining: 0, held: heldBefore)
    }
}
