import Foundation

// MARK: - 1. Interval paces that progress like lifts

/// Treadmill speed and incline for an interval workout, and how they went.
public struct PaceRecord: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public var date: Date
        public var speed: Double?
        public var incline: Double?
        public var rounds: Int
        public var planned: Int
        public var rating: RunRating?
    }

    public var name: String
    /// The pace to use next time.
    public var speed: Double?
    public var incline: Double?
    /// Tough sessions in a row (missed rounds or "too hard").
    public var misses: Int
    public var history: [Entry]

    public init(name: String, speed: Double? = nil, incline: Double? = nil, misses: Int = 0, history: [Entry] = []) {
        self.name = name; self.speed = speed; self.incline = incline; self.misses = misses; self.history = history
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        speed = c.lenient(Double.self, .speed)
        incline = c.lenient(Double.self, .incline)
        misses = c.lenient(Int.self, .misses) ?? 0
        history = c.lenient([Entry].self, .history) ?? []
    }
}

public enum IntervalPace {
    /// Treadmill intervals whose pace is tracked.
    public static let tracked: Set<String> = ["Norwegian 4×4", "30/30 Intervals", "Hill Sprints"]
    /// Stored next to the lifts (no iCloud schema change), under this prefix.
    public static let storePrefix = "pace:"
    public static let speedStep = 0.2
    public static let inclineStep = 1.0
    /// Past this speed, intervals get harder by incline instead.
    public static let maxSpeed = 10.0
    public static let maxIncline = 15.0
    public static let historyLimit = 50

    public static func tracks(_ item: SessionItem) -> Bool { item.isCardio && tracked.contains(item.name) }

    /// "Last time 7.0 mph at 8%. Today 7.2 mph at 8%."
    public static func targetText(_ record: PaceRecord?) -> String? {
        guard let r = record, r.speed != nil || r.incline != nil else { return nil }
        let today = text(speed: r.speed, incline: r.incline)
        guard let last = r.history.last, last.speed != nil || last.incline != nil else { return "Today: \(today)" }
        let before = text(speed: last.speed, incline: last.incline)
        return before == today ? "Same as last time: \(today)" : "Last time \(before). Today \(today)."
    }

    public static func text(speed: Double?, incline: Double?) -> String {
        var parts: [String] = []
        if let s = speed { parts.append(String(format: "%.1f mph", s)) }
        if let i = incline { parts.append("\(Fmt.lb(i))% incline") }
        return parts.joined(separator: " at ")
    }

    /// After a session: the pace for next time, and a note for the Finish screen.
    /// All rounds done and not "too hard": up 0.2 mph (0.4 if it felt easy), or incline once speed tops out.
    /// Missed rounds or "too hard": same pace; twice in a row, back 0.2 mph.
    public static func next(after record: PaceRecord?, name: String, speed: Double?, incline: Double?,
                            rounds: Int, planned: Int, rating: RunRating?, date: Date) -> (record: PaceRecord, note: String?) {
        var r = record ?? PaceRecord(name: name)
        guard speed != nil || incline != nil else { return (r, nil) }
        r.history.append(.init(date: date, speed: speed, incline: incline, rounds: rounds, planned: planned, rating: rating))
        if r.history.count > historyLimit { r.history.removeFirst(r.history.count - historyLimit) }
        var nextSpeed = speed
        var nextIncline = incline
        let note: String
        if rounds >= planned && rating != .tooHard {
            r.misses = 0
            let steps = rating == .feltEasy ? 2.0 : 1.0
            if let s = speed, s + speedStep * steps <= maxSpeed + 0.001 {
                nextSpeed = ((s + speedStep * steps) * 10).rounded() / 10
            } else if let i = incline ?? (speed != nil ? 0 : nil) {
                nextIncline = min(maxIncline, i + inclineStep * steps)
            }
            note = "\(name): all \(planned) rounds. Next time \(text(speed: nextSpeed, incline: nextIncline))."
        } else {
            r.misses += 1
            if r.misses >= 2, let s = speed {
                nextSpeed = max(2, ((s - speedStep) * 10).rounded() / 10)
                r.misses = 0
                note = "\(name): two tough ones in a row. Next time \(text(speed: nextSpeed, incline: nextIncline))."
            } else {
                note = "\(name): same pace next time. Own it, then it goes up."
            }
        }
        r.speed = nextSpeed
        r.incline = nextIncline
        return (r, note)
    }
}

// MARK: - 2. Recovery picks the day

public enum DayPicker {
    /// Red recovery on WHOOP.
    public static let redBelow = 34

    /// The next session, unless recovery is red and it's a hard day (intervals or heavy legs):
    /// then the first open easier day goes first. The hard day stays open for later.
    public static func pick(state: ProgramState, logs: [LogStamp], now: Date, recovery: Int?) -> (slot: Slot, note: String?) {
        let base = Program.nextSlot(state: state, logs: logs, now: now)
        guard let r = recovery, r < redBelow, state.lower.contains(base) else { return (base, nil) }
        let open = state.order.filter { !state.isDone($0) && !state.lower.contains($0) }
        guard let easier = open.first else { return (base, nil) }
        return (easier, "Recovery \(r)%: \(state.slotName(easier)) today. \(state.slotName(base)) waits for a better day.")
    }
}

// MARK: - 5. Muscle balancing

public enum MuscleBalance {
    public static let target = 10.0
    public static let maxBoosts = 3

    /// The muscle an exercise works most.
    public static func primary(_ ex: Exercise) -> Muscle? {
        MuscleMap.work(ex).max { $0.value < $1.value }?.key
    }

    /// Adds one set to up to 3 of today's accessories whose main muscle is under 10 hard sets
    /// in the last 7 days (the most behind first). Not on light days. Returns what changed.
    @discardableResult
    public static func boost(_ session: inout Session, weekSets: [Muscle: Double], catalog: Catalog = .bundled) -> [String] {
        guard !session.isLightDay else { return [] }
        var candidates: [(bi: Int, ii: Int, muscle: Muscle, have: Double)] = []
        for bi in session.blocks.indices {
            for ii in session.blocks[bi].items.indices {
                let item = session.blocks[bi].items[ii]
                guard item.kind == .accessory, item.isLift, let id = item.exerciseID, let ex = catalog.exercise(id),
                      let m = primary(ex) else { continue }
                let have = weekSets[m] ?? 0
                if have < target { candidates.append((bi, ii, m, have)) }
            }
        }
        var used = Set<Muscle>()
        var notes: [String] = []
        for c in candidates.sorted(by: { $0.have < $1.have }) where !used.contains(c.muscle) && notes.count < maxBoosts {
            used.insert(c.muscle)
            session.blocks[c.bi].items[c.ii].sets += 1
            let name = session.blocks[c.bi].items[c.ii].name
            notes.append("+1 set of \(name): \(c.muscle.rawValue) at \(Int(c.have.rounded())) sets this week")
        }
        return notes
    }
}

// MARK: - 8. Heart-rate-driven intervals

public enum HeartIntervals {
    public enum Call: Equatable, Sendable { case none, endRest, holdRest }

    /// Rests this long or longer follow heart rate (30/30s and EMOMs keep the clock).
    public static let minRest = 60
    /// Recovered: this many % of max below the bottom of the work zone.
    public static let recoveredGap = 15
    public static let maxHold = 60.0

    /// During a rest: end it once heart rate has come down (after at least half the rest),
    /// or hold it at the end (up to 60 sec) while heart rate is still high.
    public static func restCall(bpm: Int?, max: Int, target: ClosedRange<Int>, secondsIntoRest: Double,
                                restLength: Int, heldSoFar: Double) -> Call {
        guard let bpm, max > 0, restLength >= minRest else { return .none }
        let pct = HeartRate.percent(bpm: bpm, max: max)
        let recovered = pct <= target.lowerBound - recoveredGap
        if recovered && secondsIntoRest >= Double(restLength) / 2 { return .endRest }
        if !recovered && Double(restLength) - secondsIntoRest <= 1.5 && heldSoFar < maxHold { return .holdRest }
        return .none
    }

    /// Two work rounds in a row (from round 3 on) that never got within 5% of the zone:
    /// time to call it.
    public static func fading(peaks: [Int], max: Int, target: ClosedRange<Int>) -> Bool {
        guard peaks.count >= 3, max > 0 else { return false }
        return peaks.suffix(2).allSatisfy { HeartRate.percent(bpm: $0, max: max) < target.lowerBound - 5 }
    }
}
