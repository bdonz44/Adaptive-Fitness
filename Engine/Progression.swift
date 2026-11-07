import Foundation

public struct LoggedSet: Codable, Equatable, Sendable {
    public var weight: Double?
    public var reps: Int?
    public var ticked: Bool

    public init(weight: Double? = nil, reps: Int? = nil, ticked: Bool = false) {
        self.weight = weight
        self.reps = reps
        self.ticked = ticked
    }
}

public enum RunRating: String, Codable, Sendable {
    case feltEasy, solid, tooHard
}

/// What was logged for one session item (keyed by `SessionItem.key`).
public struct LoggedItem: Codable, Equatable, Sendable {
    public var sets: [LoggedSet]
    /// Rounds typed for engine/finisher items; minutes for the run.
    public var rounds: Int?
    public var ticked: Bool
    public var rir: Int?
    public var runRating: RunRating?
    public var miles: Double?
    /// Sets taken off today's list (from the end).
    public var removedSets: Int?
    /// Set when the whole exercise was skipped today: "Pain", "No time", "No equipment", "Other".
    public var skipped: String?
    /// Only on the "_session" entry of a saved log: the session's heart rate.
    public var heart: SessionHeart?

    public init(sets: [LoggedSet] = [], rounds: Int? = nil, ticked: Bool = false,
                rir: Int? = nil, runRating: RunRating? = nil, miles: Double? = nil,
                removedSets: Int? = nil, skipped: String? = nil) {
        self.removedSets = removedSets
        self.skipped = skipped
        self.sets = sets
        self.rounds = rounds
        self.ticked = ticked
        self.rir = rir
        self.runRating = runRating
        self.miles = miles
    }
}

/// How a lift's logged sets read.
public struct SetReading: Equatable, Sendable {
    public var usedWeight: Double?
    public var topReps: Int
    public var hitAll: Bool
    public var miss: Bool
    public var countedSets: Int
}

public enum ChangeDirection: String, Sendable {
    case up, down, same
}

public struct LiftChange: Equatable, Sendable {
    public var exerciseID: String
    public var name: String
    public var from: Double?
    public var to: Double?
    public var direction: ChangeDirection
    public var note: String?
}

public struct ProgressResult: Equatable, Sendable {
    public var lifts: [String: LiftRecord]
    public var changes: [LiftChange]
    public var cardioMinutes: Int
    /// New stored run length (only changes after a run).
    public var runMinutes: Int
}

public enum Progression {
    public static let historyLimit = 12

    public static let maxDumbbellNote = "At your heaviest dumbbells. Add 2 reps per set or take 3 seconds on the way down."
    public static let droppedTenNote = "Dropped 10% after two tough sessions."
    public static let stuckNote = "Stuck 3 sessions. Dropped 5%."
    public static let ownFiftyNote = "You own the 50. Add 2 reps per set or slow it down."
    public static let chaseRepsNote = "chase reps"

    /// A set counts if it was ticked or has reps typed. A ticked set with blank reps logs the top of the range.
    public static func read(sets: [LoggedSet], low: Int, high: Int, prescribedSets: Int) -> SetReading? {
        let counted: [(weight: Double?, reps: Int)] = sets
            .filter { $0.ticked || $0.reps != nil }
            .map { ($0.weight, $0.reps ?? high) }
        guard !counted.isEmpty else { return nil }

        // Used weight = the weight logged on the most sets (ties go to the heavier).
        var counts: [Double: Int] = [:]
        for s in counted { counts[s.weight ?? -1, default: 0] += 1 }
        let best = counts.max { a, b in a.value != b.value ? a.value < b.value : a.key < b.key }!.key
        let used: Double? = best < 0 ? nil : best

        let atUsed = counted.filter { $0.weight == used }
        let top = atUsed.map(\.reps).max() ?? 0
        let hitAll = atUsed.allSatisfy { $0.reps >= high } && atUsed.count >= min(prescribedSets, 3)
        let miss = atUsed.contains { $0.reps < low }
        return SetReading(usedWeight: used, topReps: top, hitAll: hitAll, miss: miss, countedSets: counted.count)
    }

    /// Minutes a cardio item adds: rounds if the unit is minutes, otherwise rounds × minutes per round.
    /// A ticked item with no rounds typed logs the planned rounds.
    public static func cardioMinutes(item: SessionItem, entry: LoggedItem?) -> Double {
        guard item.isCardio, let entry else { return 0 }
        let rounds = entry.rounds ?? (entry.ticked ? (item.rounds ?? 0) : 0)
        if item.unit == .min { return Double(rounds) }
        return Double(rounds) * (item.minutesPerRound ?? 2)
    }

    /// Next easy-run length.
    public static func nextRunMinutes(planned: Int, logged: Int, rating: RunRating?, current: Int, beat: Bool) -> Int {
        if rating == .tooHard || logged < planned - 3 { return max(20, planned - 5) }
        if rating == .feltEasy && logged >= planned && !beat { return min(50, planned + 5) }
        return max(planned, current)
    }

    /// Remembers why lifts were skipped today, so the next session can flag them.
    public static func applySkips(session: Session, entries: [String: LoggedItem], lifts: [String: LiftRecord]) -> [String: LiftRecord] {
        var lifts = lifts
        for item in session.items where item.isLift {
            guard let reason = entries[item.key]?.skipped, let id = item.exerciseID else { continue }
            var rec = lifts[id] ?? LiftRecord(exerciseID: id)
            rec.lastSkip = reason
            lifts[id] = rec
        }
        return lifts
    }

    /// Applies a finished session to the stored lifts.
    public static func progress(session: Session, entries: [String: LoggedItem], lifts: [String: LiftRecord],
                                date: Date, runMinutes: Int, catalog: Catalog = .bundled,
                                adaptive: AdaptiveSettings = .off) -> ProgressResult {
        var lifts = lifts
        var changes: [LiftChange] = []
        var cardio = 0.0
        var nextRun = runMinutes
        let noProgression = session.isLightDay

        for item in session.items {
            let entry = entries[item.key]

            if item.isCardio {
                cardio += cardioMinutes(item: item, entry: entry)
                if item.kind == .run, let entry {
                    let planned = item.rounds ?? runMinutes
                    let logged = entry.rounds ?? (entry.ticked ? planned : 0)
                    if logged > 0 || entry.ticked {
                        nextRun = nextRunMinutes(planned: planned, logged: logged, rating: entry.runRating,
                                                 current: runMinutes, beat: session.readiness == .beat)
                    }
                }
                continue
            }

            guard item.isLift, let id = item.exerciseID, let eq = item.equipment, let log = entry,
                  let reading = read(sets: log.sets, low: item.low, high: item.high, prescribedSets: item.sets)
            else { continue }

            var rec = lifts[id] ?? LiftRecord(exerciseID: id)
            let previous = rec.workingWeight
            let used = reading.usedWeight

            rec.history.append(HistoryEntry(date: date, weight: used, reps: reading.topReps, targetHi: item.high, rir: log.rir))
            rec.lastSkip = nil
            if rec.history.count > historyLimit { rec.history.removeFirst(rec.history.count - historyLimit) }
            if rec.firstWeight == nil, let used, eq != .bw { rec.firstWeight = used }

            var note: String? = nil
            if noProgression {
                // Weights hold and counters do not change. A first-ever log still stores its weight.
                if rec.workingWeight == nil, eq != .bw { rec.workingWeight = used }
            } else {
                switch eq {
                case .bb, .db:
                    if let used {
                        let effort = adaptive.effortProgression ? EffortRules.step(reading: reading, rir: log.rir) : .normal
                        note = barbellOrDumbbell(&rec, item: item, eq: eq, used: used, reading: reading,
                                                 catalog: catalog, effort: effort)
                    }
                case .kb:
                    if let used { note = kettlebell(&rec, id: id, used: used, reading: reading) }
                case .bw:
                    if reading.hitAll {
                        let trx = catalog.exercise(id)?.category == Catalog.trxCategory
                        note = trx && item.unit == .reps ? trxHarderNote : harderNote(item.unit)
                    }
                }
                rec.note = note
            }
            lifts[id] = rec

            let from = previous ?? used
            let to = rec.workingWeight
            let direction: ChangeDirection
            if let f = from, let t = to, t > f { direction = .up }
            else if let f = from, let t = to, t < f { direction = .down }
            else { direction = .same }
            changes.append(LiftChange(exerciseID: id, name: item.name, from: from, to: to, direction: direction, note: note))
        }

        return ProgressResult(lifts: lifts, changes: changes, cardioMinutes: Int(cardio.rounded()), runMinutes: nextRun)
    }

    static func barbellOrDumbbell(_ rec: inout LiftRecord, item: SessionItem, eq: Equipment, used: Double,
                                  reading: SetReading, catalog: Catalog, effort: EffortRules.Step = .normal) -> String? {
        let inc = eq == .bb ? (catalog.exercise(item.exerciseID ?? "")?.inc ?? 5) : 5
        if reading.hitAll {
            rec.fails = 0
            rec.holds = 0
            if eq == .db && used >= Suggestions.dumbbellMax {
                rec.workingWeight = Suggestions.dumbbellMax
                return maxDumbbellNote
            }
            switch effort {
            case .hold:
                rec.workingWeight = used
                return EffortRules.holdNote
            case .double:
                rec.workingWeight = Suggestions.clamp(used + inc * 2, equipment: eq)
                return EffortRules.doubleNote
            case .normal, .bump:
                rec.workingWeight = Suggestions.clamp(used + inc, equipment: eq)
                return nil
            }
        }
        if reading.miss {
            if rec.fails >= 1 {
                rec.fails = 0
                rec.workingWeight = Suggestions.clamp(used * 0.9, equipment: eq)
                return droppedTenNote
            }
            rec.fails += 1
            rec.workingWeight = used
            return nil
        }
        // In range, not the top.
        rec.fails = 0
        if effort == .bump {
            rec.holds = 0
            rec.workingWeight = Suggestions.clamp(used + inc, equipment: eq)
            return EffortRules.bumpNote
        }
        if item.kind == .main {
            rec.holds += 1
            if rec.holds >= 3 {
                rec.holds = 0
                rec.workingWeight = Suggestions.clamp(used * 0.95, equipment: eq)
                return stuckNote
            }
        }
        rec.workingWeight = used
        return nil
    }

    static func kettlebell(_ rec: inout LiftRecord, id: String, used: Double, reading: SetReading) -> String? {
        let bell = Suggestions.snapBell(used)
        if reading.hitAll {
            rec.fails = 0
            if bell >= 50 {
                rec.workingWeight = 50
                return ownFiftyNote
            }
            rec.workingWeight = bell == 20 ? 35 : 50
            return nil
        }
        if reading.miss {
            if rec.fails >= 1 && bell > Suggestions.defaultBell(id) {
                rec.fails = 0
                rec.workingWeight = bell == 50 ? 35 : 20
                return nil
            }
            rec.fails += 1
            rec.workingWeight = bell
            return nil
        }
        rec.fails = 0
        rec.workingWeight = bell
        return chaseRepsNote
    }

    static let trxHarderNote = "Harder: walk your feet closer to the anchor, or slow the lowering to 3 seconds."

    static func harderNote(_ unit: ExerciseUnit) -> String {
        switch unit {
        case .sec: return "Harder: add 10 to 15 seconds."
        case .yd: return "Harder: go a little farther or faster."
        default: return "Harder: slow the lowering to 3 seconds or add reps."
        }
    }
}
