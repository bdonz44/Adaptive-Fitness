import Foundation

// MARK: - Beat last time

/// Last session's matching set, shown next to today's: "Last 185 × 6".
public enum Ghost {
    public static func last(_ record: LiftRecord?, set index: Int) -> (weight: Double?, reps: Int)? {
        guard let record else { return nil }
        if let sets = record.lastSets, !sets.isEmpty {
            let s = sets[min(index, sets.count - 1)]
            return s.reps.map { (s.weight, $0) }
        }
        // Lifts logged before every set was saved: the top set from last time.
        guard let h = record.history.last, let r = h.reps else { return nil }
        return (h.weight, r)
    }

    public enum Verdict: Equatable, Sendable { case beat, matched, short }

    /// Today's set against last time's: more weight or more reps (by estimated max) beats it.
    public static func verdict(weight: Double?, reps: Int, against last: (weight: Double?, reps: Int)) -> Verdict {
        let now = weight.map { Suggestions.e1RM(weight: $0, reps: reps) } ?? Double(reps)
        let then = last.weight.map { Suggestions.e1RM(weight: $0, reps: last.reps) } ?? Double(last.reps)
        if now > then + 0.01 { return .beat }
        if abs(now - then) <= 0.01 { return .matched }
        return .short
    }

    /// "185 × 6" or "12 reps"
    public static func text(_ last: (weight: Double?, reps: Int), unit: ExerciseUnit) -> String {
        if let w = last.weight, w > 0 { return "\(Fmt.lb(w)) × \(last.reps)" }
        return unit == .sec ? "\(last.reps) sec" : "\(last.reps) reps"
    }
}

// MARK: - Lift history

public struct LiftStats: Equatable, Sendable {
    public struct Point: Equatable, Sendable { public var date: Date; public var weight: Double; public var reps: Int; public var e1RM: Double }
    public var sessions: [Point]
    public var best: Point?
    /// Heaviest top set at each rep count (1-15).
    public var repBests: [(reps: Int, weight: Double, date: Date)]

    public static func == (a: LiftStats, b: LiftStats) -> Bool { a.sessions == b.sessions }

    public init(_ record: LiftRecord?) {
        sessions = (record?.history ?? []).compactMap { h in
            guard let w = h.weight, w > 0, let r = h.reps, r > 0 else { return nil }
            return Point(date: h.date, weight: w, reps: r, e1RM: Suggestions.e1RM(weight: w, reps: r))
        }
        best = sessions.max { $0.e1RM < $1.e1RM }
        var byReps: [Int: Point] = [:]
        for p in sessions where p.reps <= 15 {
            if (byReps[p.reps]?.weight ?? 0) < p.weight { byReps[p.reps] = p }
        }
        repBests = byReps.keys.sorted().map { (reps: $0, weight: byReps[$0]!.weight, date: byReps[$0]!.date) }
    }
}

// MARK: - Milestones

public struct Milestone: Equatable, Identifiable, Sendable {
    public enum Kind: String, Sendable { case sessions, streak, plates, club, bodyweight, program }
    public var id: String
    public var kind: Kind
    public var title: String
    public var detail: String
    public var progress: Double
    public var target: Double
    public var achieved: Bool { progress >= target }
    public var fraction: Double { min(1, progress / max(target, 1)) }
}

public enum Milestones {
    public struct Facts: Sendable {
        public var sessions: Int
        public var bestStreak: Int
        public var lifts: [String: LiftRecord]
        public var weighIns: [WeighIn]
        public var blocksFinished: Int
        public init(sessions: Int, bestStreak: Int, lifts: [String: LiftRecord], weighIns: [WeighIn], blocksFinished: Int) {
            self.sessions = sessions; self.bestStreak = bestStreak; self.lifts = lifts
            self.weighIns = weighIns; self.blocksFinished = blocksFinished
        }
    }

    static let plates: [(id: String, name: String, targets: [Double])] = [
        ("bench", "Bench", [135, 185, 225, 275, 315]),
        ("squat", "Squat", [135, 225, 315, 405]),
        ("deadlift", "Deadlift", [225, 315, 405, 495]),
        ("ohp", "Overhead Press", [95, 135, 185]),
    ]

    /// Heaviest weight actually lifted for at least one rep.
    static func heaviest(_ r: LiftRecord?) -> Double {
        let hist = (r?.history ?? []).filter { ($0.reps ?? 0) > 0 }.compactMap(\.weight).max() ?? 0
        let last = (r?.lastSets ?? []).filter { ($0.reps ?? 0) > 0 }.compactMap(\.weight).max() ?? 0
        return max(hist, last)
    }

    public static func all(_ f: Facts) -> [Milestone] {
        var out: [Milestone] = []
        for n in [10, 25, 50, 100, 250] {
            out.append(Milestone(id: "sessions-\(n)", kind: .sessions, title: "\(n) sessions",
                                 detail: "Logged \(n) workouts.", progress: Double(f.sessions), target: Double(n)))
        }
        for n in [2, 4, 8, 12] {
            out.append(Milestone(id: "streak-\(n)", kind: .streak, title: "\(n) full weeks in a row",
                                 detail: "Every session, \(n) weeks running.", progress: Double(f.bestStreak), target: Double(n)))
        }
        for p in plates {
            let top = heaviest(f.lifts[p.id])
            for t in p.targets {
                out.append(Milestone(id: "\(p.id)-\(Int(t))", kind: .plates, title: "\(p.name) \(Fmt.lb(t))",
                                     detail: "Lifted \(Fmt.lb(t)) lb for a rep or more.", progress: top, target: t))
            }
        }
        let total = ["squat", "bench", "deadlift"].map { Suggestions.best1RM(f.lifts[$0]) ?? 0 }.reduce(0, +)
        for t in [750.0, 1000, 1200] {
            out.append(Milestone(id: "club-\(Int(t))", kind: .club, title: "\(t == 1000 ? "1,000" : Fmt.lb(t))-lb club",
                                 detail: "Squat + bench + deadlift estimated maxes add up to \(Fmt.lb(t)).",
                                 progress: total, target: t))
        }
        let w = f.weighIns.sorted { $0.date < $1.date }
        let lost = max(0, (w.first?.pounds ?? 0) - (w.map(\.pounds).min() ?? w.first?.pounds ?? 0))
        for t in [5.0, 10, 20, 30] {
            out.append(Milestone(id: "lost-\(Int(t))", kind: .bodyweight, title: "Down \(Fmt.lb(t)) lb",
                                 detail: "\(Fmt.lb(t)) lb below your first weigh-in.", progress: lost, target: t))
        }
        out.append(Milestone(id: "block-1", kind: .program, title: "Finished a 12-week block",
                             detail: "All 12 weeks of a program.", progress: Double(f.blocksFinished), target: 1))
        return out
    }

    /// Achieved now but not in `known` (shown as new on the Finish screen).
    public static func newlyAchieved(_ f: Facts, known: Set<String>) -> [Milestone] {
        all(f).filter { $0.achieved && !known.contains($0.id) }
    }
}

// MARK: - Strength standards by age

/// Bodyweight multiples for a man's estimated max at about 30, from common strength-standard tables
/// (Strength Level / ExRx ballpark), adjusted by an age coefficient after 40 (in the spirit of the
/// masters-lifting age coefficients). Approximate guides, not percentiles.
public enum StrengthStandards {
    public static let tiers = ["Beginner", "Novice", "Intermediate", "Advanced", "Elite"]

    static let multiples: [String: [Double]] = [
        "squat": [0.75, 1.25, 1.5, 2.25, 2.75],
        "bench": [0.5, 0.75, 1.25, 1.5, 2.0],
        "deadlift": [1.0, 1.5, 2.0, 2.5, 3.0],
        "ohp": [0.35, 0.55, 0.8, 1.05, 1.35],
    ]
    public static let lifts = ["squat", "bench", "deadlift", "ohp"]

    /// How much easier each tier gets with age: 1.0 up to 40, about 1.06 at 45, 1.14 at 50, 1.36 at 60.
    public static func ageFactor(_ age: Int) -> Double {
        let over = Double(max(0, age - 40))
        return 1 + 0.010 * over + 0.0004 * over * over
    }

    public static func age(born: Date, now: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.year], from: born, to: now).year ?? 0
    }

    /// Tier weights for a lift at a bodyweight and age.
    public static func weights(_ lift: String, bodyweight: Double, age: Int) -> [Double] {
        (multiples[lift] ?? []).map { Suggestions.round5($0 * bodyweight / ageFactor(age)) }
    }

    public struct Standing: Equatable, Sendable {
        public var tier: String?
        public var next: String?
        public var nextWeight: Double?
        public var ratio: Double
    }

    public static func standing(_ lift: String, e1RM: Double, bodyweight: Double, age: Int) -> Standing {
        let w = weights(lift, bodyweight: bodyweight, age: age)
        let reached = w.lastIndex { e1RM >= $0 }
        let nextIndex = (reached ?? -1) + 1
        return Standing(tier: reached.map { tiers[$0] }, next: nextIndex < tiers.count ? tiers[nextIndex] : nil,
                        nextWeight: nextIndex < w.count ? w[nextIndex] : nil, ratio: e1RM / max(bodyweight, 1))
    }
}
