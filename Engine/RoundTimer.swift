import Foundation

/// Boxing-style round timer: a get-ready countdown, then work and rest for each
/// round (no rest after the last). Also runs EMOMs (rest 0) and sprint intervals.
public enum RoundPlan {
    public static let getReady = 10
    /// The "10 seconds left" warning in each work round.
    public static let warning = 10

    public enum Kind: String, Equatable, Sendable { case getReady, work, rest }

    public struct Phase: Equatable, Sendable {
        public var kind: Kind
        /// 1-based round this phase belongs to (0 for get ready).
        public var round: Int
        public var seconds: Int
    }

    public struct Settings: Codable, Equatable, Sendable {
        public var rounds: Int
        public var work: Int
        public var rest: Int

        public init(rounds: Int, work: Int, rest: Int) {
            self.rounds = max(1, rounds)
            self.work = max(5, work)
            self.rest = max(0, rest)
        }

        public var totalSeconds: Int { RoundPlan.getReady + rounds * work + (rounds - 1) * rest }
    }

    /// Defaults for an engine workout or finisher: its data's work/rest, else the
    /// whole round as work with no rest.
    public static func defaults(for item: SessionItem) -> Settings {
        let rounds = max(1, item.rounds ?? 1)
        if let w = item.intervalWork { return Settings(rounds: rounds, work: w, rest: item.intervalRest ?? 0) }
        let perRound = Int(((item.minutesPerRound ?? 1) * 60).rounded())
        return Settings(rounds: rounds, work: perRound, rest: 0)
    }

    public static func phases(_ s: Settings) -> [Phase] {
        var out = [Phase(kind: .getReady, round: 0, seconds: getReady)]
        for r in 1...s.rounds {
            out.append(Phase(kind: .work, round: r, seconds: s.work))
            if r < s.rounds && s.rest > 0 { out.append(Phase(kind: .rest, round: r, seconds: s.rest)) }
        }
        return out
    }

    public struct Position: Equatable, Sendable {
        /// Index into the phases; nil when every round is over.
        public var phase: Int?
        /// Whole seconds left in the phase (rounded up).
        public var remaining: Int
        /// Work rounds fully finished.
        public var roundsDone: Int
        public var finished: Bool { phase == nil }
    }

    public static func position(_ phases: [Phase], elapsed: TimeInterval) -> Position {
        var t = max(0, elapsed)
        var done = 0
        for (i, p) in phases.enumerated() {
            let len = TimeInterval(p.seconds)
            if t < len { return Position(phase: i, remaining: Int((len - t).rounded(.up)), roundsDone: done) }
            if p.kind == .work { done += 1 }
            t -= len
        }
        return Position(phase: nil, remaining: 0, roundsDone: done)
    }

    /// Seconds from start at which each phase begins (for backup notifications).
    public static func phaseStarts(_ phases: [Phase]) -> [Int] {
        var t = 0
        return phases.map { p in defer { t += p.seconds }; return t }
    }

    /// What to log on the item: rounds, or minutes for minute-based items (EMOM).
    public static func logged(roundsDone: Int, settings s: Settings, unit: ExerciseUnit) -> Int {
        guard unit == .min else { return roundsDone }
        let seconds = roundsDone * s.work + max(0, roundsDone - 1) * s.rest
        return Int((Double(seconds) / 60).rounded())
    }

    /// "2:00 on · 1:00 off · 10 rounds · 30 min"
    public static func summary(_ s: Settings) -> String {
        func clock(_ x: Int) -> String { String(format: "%d:%02d", x / 60, x % 60) }
        let minutes = Int((Double(s.totalSeconds) / 60).rounded())
        let rest = s.rest > 0 ? " · \(clock(s.rest)) off" : ""
        return "\(clock(s.work)) on\(rest) · \(s.rounds) rounds · \(minutes) min"
    }
}
