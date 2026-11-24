import Foundation

public struct HistoryEntry: Codable, Equatable, Sendable {
    public var date: Date
    public var weight: Double?
    public var reps: Int?
    public var targetHi: Int?
    /// Reps left in the tank (v2).
    public var rir: Int?

    public init(date: Date, weight: Double?, reps: Int?, targetHi: Int?, rir: Int? = nil) {
        self.date = date
        self.weight = weight
        self.reps = reps
        self.targetHi = targetHi
        self.rir = rir
    }
}

public struct LiftRecord: Codable, Equatable, Sendable {
    public var exerciseID: String
    public var workingWeight: Double?
    public var fails: Int
    public var holds: Int
    public var note: String?
    /// Last 12 entries, oldest first.
    public var history: [HistoryEntry]
    /// First weight ever logged (history only keeps 12), for "heavier than where you started".
    public var firstWeight: Double?
    /// Why this lift was skipped last time it came up ("Pain"...), cleared once it's logged again.
    public var lastSkip: String?
    /// Plateau breaker sessions left (heavy triples), when a main lift got stuck.
    public var breaker: Int?
    /// The finished sets from the last session (for "beat last time").
    public var lastSets: [LoggedSet]?

    public init(exerciseID: String, workingWeight: Double? = nil, fails: Int = 0, holds: Int = 0,
                note: String? = nil, history: [HistoryEntry] = [], firstWeight: Double? = nil, breaker: Int? = nil) {
        self.breaker = breaker
        self.exerciseID = exerciseID
        self.workingWeight = workingWeight
        self.fails = fails
        self.holds = holds
        self.note = note
        self.history = history
        self.firstWeight = firstWeight
    }
}

public struct Suggestion: Equatable, Sendable {
    public var weight: Double?
    public var reason: String
}

public enum Suggestions {
    public static let bells: [Double] = [20, 35, 50]
    public static let dumbbellMin: Double = 5
    public static let dumbbellMax: Double = 35
    public static let barbellMin: Double = 45

    /// Related-lift ratios: lift -> (estimated from, ratio).
    public static let related: [String: (from: String, ratio: Double)] = [
        "fsquat": ("squat", 0.80),
        "squat": ("fsquat", 1.25),
        "incline": ("bench", 0.82),
        "floorpress": ("bench", 0.90),
        "bench": ("incline", 1.22),
        "pushpress": ("ohp", 1.20),
        "ohp": ("pushpress", 0.83),
        "rdl": ("deadlift", 0.60),
        "hipthrust": ("deadlift", 0.80),
        "goodmorning": ("squat", 0.35),
        "bbrow": ("pendlay", 1.05),
        "pendlay": ("bbrow", 0.95),
        "dbincline": ("dbfloor", 0.90),
        "dbfloor": ("dbincline", 1.10),
        "arnold": ("dbpress", 0.85),
        "dbpress": ("arnold", 1.15),
        "curl": ("hammer", 0.95),
        "hammer": ("curl", 1.05),
        "bulgarian": ("splitsq", 0.85),
        "splitsq": ("bulgarian", 1.15),
        "csrow": ("dbrow", 0.80),
        "dbrow": ("csrow", 1.20),
    ]

    /// Kettlebell starting bells (the nearest one you own).
    public static func defaultBell(_ id: String, gear: GearProfile = .standard) -> Double {
        let planned: Double
        switch id {
        case "kbswingh", "kbswing", "gobletsq", "suitcase", "gorilla": planned = 50
        case "kbbottoms": planned = 20
        default: planned = 35
        }
        return gear.bell(planned)
    }

    // MARK: Math

    /// Epley, reps capped at 12.
    public static func e1RM(weight: Double, reps: Int) -> Double {
        weight * (1 + Double(min(reps, 12)) / 30)
    }

    /// Highest e1RM across the last 3 history entries that have both weight and reps.
    /// With `countEffort`, reps left in the tank (logged RIR) count toward the estimate.
    public static func best1RM(_ record: LiftRecord?, countEffort: Bool = false) -> Double? {
        guard let record else { return nil }
        let usable = record.history.filter { ($0.weight ?? 0) > 0 && ($0.reps ?? 0) > 0 }.suffix(3)
        return usable.map { e in
            e1RM(weight: e.weight!, reps: e.reps! + (countEffort ? EffortRules.extraReps(e.rir) : 0))
        }.max()
    }

    /// Highest e1RM in the whole history (for "new best" checks; `best1RM` only looks at recent form).
    public static func allTimeBest1RM(_ record: LiftRecord?) -> Double? {
        record?.history.compactMap { e -> Double? in
            guard let w = e.weight, w > 0, let r = e.reps, r > 0 else { return nil }
            return e1RM(weight: w, reps: r)
        }.max()
    }

    /// Weight for a rep target, leaving `reserve` reps in the tank (2 by default).
    public static func weight(forReps reps: Int, e1RM: Double, reserve: Int = 2) -> Double {
        e1RM / (1 + Double(reps + reserve) / 30)
    }

    public static func round5(_ w: Double) -> Double { (w / 5).rounded() * 5 }

    public static func snapBell(_ w: Double, gear: GearProfile = .standard) -> Double { gear.bell(w) }

    /// Clamp to the equipment you own.
    public static func clamp(_ w: Double, equipment: Equipment, gear: GearProfile = .standard) -> Double {
        switch equipment {
        case .bb: return gear.barbellWeight(w)
        case .db: return gear.dumbbell(w)
        case .kb: return gear.bell(w)
        case .bw: return round5(w)
        }
    }

    /// Tapping the bell cycles through your bells (20, 35, 50 by default).
    public static func nextBellInCycle(_ w: Double, gear: GearProfile = .standard) -> Double { gear.nextBell(after: w) }

    // MARK: Suggestion

    public static func suggest(item: SessionItem, lifts: [String: LiftRecord], lightenToday: Bool,
                               catalog: Catalog = .bundled, adaptive: AdaptiveSettings = .off,
                               lightenFactor: Double = 0.9, lightenNote: String = " Lightened 10% for today.",
                               gear: GearProfile = .standard) -> Suggestion {
        let effort = adaptive.effortProgression
        guard item.isLift, let id = item.exerciseID, let eq = item.equipment else {
            return Suggestion(weight: nil, reason: "")
        }
        let record = lifts[id]
        switch eq {
        case .bw:
            return Suggestion(weight: nil, reason: record?.note ?? "")
        case .kb:
            return kettlebell(id: id, record: record, lightenToday: lightenToday, factor: lightenFactor, note: lightenNote, gear: gear)
        case .bb, .db:
            break
        }

        let target = item.high
        let base: Double
        var reason: String
        if let stored = record?.workingWeight, let last = record?.history.last, last.targetHi == target {
            base = stored
            reason = ""
            if let lw = last.weight, let lr = last.reps { reason = "Last time \(Fmt.lb(lw)) × \(lr). " }
            let lastWeight = last.weight ?? stored
            if stored > lastWeight {
                reason += "You earned the bump."
            } else if stored < lastWeight {
                reason += "Reset lower to build back."
            } else {
                reason += "Same weight, beat your reps."
            }
        } else if let best = best1RM(record, countEffort: effort) {
            base = weight(forReps: target, e1RM: best)
            reason = "From your recent best (estimated max \(Fmt.lb(round5(best))) lb)."
        } else if let rel = related[id], let relBest = best1RM(lifts[rel.from], countEffort: effort) {
            base = weight(forReps: target, e1RM: relBest * rel.ratio)
            reason = "Estimated from your \(catalog.exercise(rel.from)?.name ?? rel.from)."
        } else if let stored = record?.workingWeight {
            base = stored
            reason = "Last used \(Fmt.lb(stored)) lb."
        } else {
            return Suggestion(weight: nil, reason: "Pick a weight you could lift for 2 more reps than the target.")
        }

        var w = clamp(base, equipment: eq, gear: gear)
        if lightenToday {
            w = clamp(w * lightenFactor, equipment: eq, gear: gear)
            reason += lightenNote
        }
        return Suggestion(weight: w, reason: reason)
    }

    static func kettlebell(id: String, record: LiftRecord?, lightenToday: Bool,
                           factor: Double = 0.9, note: String = " Lightened 10% for today.",
                           gear: GearProfile = .standard) -> Suggestion {
        var bell: Double
        var reason: String
        if let stored = record?.workingWeight {
            bell = snapBell(stored, gear: gear)
            reason = bell >= gear.heaviestBell
                ? "Once you own every rep here, add reps."
                : "Your \(Fmt.lb(bell)) lb. Hit every rep and it moves you to the next bell."
        } else {
            bell = defaultBell(id, gear: gear)
            reason = "Start with the \(Fmt.lb(bell)) lb bell."
        }
        if lightenToday {
            bell = snapBell(bell * factor, gear: gear)
            reason += note
        }
        return Suggestion(weight: bell, reason: reason)
    }
}
