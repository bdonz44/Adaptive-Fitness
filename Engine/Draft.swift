import Foundation

/// The in-progress session: saved on every change, survives app restarts,
/// discarded when the week changes or a different slot is picked.
public struct SessionDraft: Codable, Equatable, Sendable {
    public var slot: Slot
    public var week: Int
    public var readiness: Readiness
    public var swaps: [String: String]
    public var condSwap: Int?
    public var finSwap: Int?
    /// Logged work by `SessionItem.key`.
    public var entries: [String: LoggedItem]
    /// Ticked warm-up steps (by index).
    public var warmTicks: [Int]
    /// Minutes available today (v2, time-boxed sessions).
    public var timeBudget: Int?
    /// When the first set or warm-up step was ticked (start of the Health workout).
    public var startedAt: Date?
    /// Warm-up weights changed by hand, by step index ("0", "1"...).
    public var warmWeights: [String: Double]?
    /// Exercises added by hand for today ("Add exercise"), in order.
    public var extras: [String]?
    /// The item logged most recently (Now and Focus carry on from it).
    public var lastDone: String?
    /// The program and days-a-week this draft was built for (nil: Hybrid 12, 5 days).
    public var program: ProgramID?
    public var days: Int?

    /// A new draft for the running program.
    public init(slot: Slot, state: ProgramState, readiness: Readiness = .normal) {
        self.init(slot: slot, week: state.week, readiness: readiness)
        if state.program != .hybrid12 || state.days != state.program.defaultDays {
            program = state.program
            days = state.days
        }
    }

    public init(slot: Slot, week: Int, readiness: Readiness = .normal) {
        self.slot = slot
        self.week = week
        self.readiness = readiness
        self.swaps = [:]
        self.condSwap = nil
        self.finSwap = nil
        self.entries = [:]
        self.warmTicks = []
        self.timeBudget = nil
        self.startedAt = nil
    }

    /// Records the start time the first time any work or warm-up step is logged.
    public mutating func noteStart(at date: Date) {
        if startedAt == nil, hasWork || !warmTicks.isEmpty { startedAt = date }
    }

    /// Session inputs for the running program.
    public func context(for state: ProgramState) -> SessionContext {
        var c = context(runMinutes: state.runMinutes)
        c.program = state.program
        c.days = state.days
        c.startWeek = state.startWeek
        return c
    }

    public func context(runMinutes: Int) -> SessionContext {
        SessionContext(week: week, readiness: readiness, swaps: swaps,
                       condSwap: condSwap, finSwap: finSwap, runMinutes: runMinutes, extras: extras ?? [])
    }

    /// A draft from an earlier week is discarded.
    public func isCurrent(for state: ProgramState) -> Bool {
        week == state.week && (program ?? .hybrid12) == state.program
            && (days ?? ProgramID.hybrid12.defaultDays) == state.days
    }

    public var hasWork: Bool { entries.values.contains { $0.hasCompletedWork } }

    /// Changing readiness clears any items with no completed sets so weights recalculate.
    public mutating func setReadiness(_ newValue: Readiness) {
        guard newValue != readiness else { return }
        readiness = newValue
        entries = entries.filter { $0.value.hasCompletedWork }
    }

    /// Adds an exercise to the end of today's session (once).
    public mutating func addExtra(_ exerciseID: String) {
        var list = extras ?? []
        guard !list.contains(exerciseID) else { return }
        list.append(exerciseID)
        extras = list
    }

    /// Takes an added exercise back out, with anything logged for it.
    public mutating func removeExtra(_ exerciseID: String) {
        extras?.removeAll { $0 == exerciseID }
        if extras?.isEmpty == true { extras = nil }
        entries[SessionItem.extraKey(exerciseID)] = nil
    }

    /// Accessory: next exercise in the same category not already in the session.
    /// Engine and finisher: next index. Clears what was logged for that item.
    @discardableResult
    public mutating func swap(_ key: String, in session: Session, catalog: Catalog = .bundled) -> Bool {
        guard let item = session.item(key) else { return false }
        let w = ProgramWeek(week)
        switch item.kind {
        case .accessory:
            guard let next = SessionBuilder.swapOption(for: key, in: session, catalog: catalog) else { return false }
            swaps[key] = next
        case .engine:
            condSwap = (condSwap ?? (w.wk - 1 + w.cycle - 1)) + 1
        case .finisher:
            finSwap = (finSwap ?? (w.wk - 1)) + 1
        default:
            return false
        }
        entries[key] = nil
        return true
    }

    /// Sets one set's weight. The kettlebell button also applies it to later unfinished sets.
    public mutating func setWeight(_ weight: Double?, key: String, set index: Int, setCount: Int,
                                   applyToLaterUnfinished: Bool = false) {
        var e = entries[key] ?? LoggedItem()
        e.ensureSets(max(index + 1, setCount))
        e.sets[index].weight = weight
        if applyToLaterUnfinished {
            for i in (index + 1)..<e.sets.count where !e.sets[i].isDone {
                e.sets[i].weight = weight
            }
        }
        entries[key] = e
    }

    /// After a set is done, later sets of the same item that are still blank and
    /// not done take its weight and reps, so the next set is ready to tick.
    public mutating func carryForward(key: String, from index: Int, setCount: Int) {
        guard var e = entries[key], index < e.sets.count else { return }
        e.ensureSets(setCount)
        let done = e.sets[index]
        guard done.isDone else { return }
        for i in (index + 1)..<max(e.sets.count, index + 1) where !e.sets[i].isDone {
            if e.sets[i].weight == nil { e.sets[i].weight = done.weight }
            // A suggestion only: filling `reps` would count the set as done.
            if let r = done.reps { e.sets[i].plannedReps = r }
        }
        entries[key] = e
    }

    /// Drafts saved before `plannedReps` existed had carried reps written as real reps, which made
    /// untouched sets count as done. Unticked sets after the last ticked set that repeat its reps
    /// go back to being suggestions.
    public mutating func repairCarriedReps() {
        for (key, var e) in entries {
            guard let last = e.sets.lastIndex(where: \.ticked), let r = e.sets[last].reps else { continue }
            var changed = false
            for i in (last + 1)..<e.sets.count where !e.sets[i].ticked && e.sets[i].reps == r {
                e.sets[i].reps = nil
                e.sets[i].plannedReps = r
                changed = true
            }
            if changed { entries[key] = e }
        }
    }

    /// Takes the last not-done set off today's list (keeps at least one).
    public mutating func removeSet(key: String, planned: Int) {
        var e = entries[key] ?? LoggedItem()
        let active = e.activeSets(planned: planned)
        guard active > 1 else { return }
        e.ensureSets(active)
        // The last set that isn't done (usually the last one); done sets are never removed.
        guard let open = (0..<active).last(where: { !e.sets[$0].isDone }) else { return }
        e.sets.remove(at: open)
        e.ensureSets(active)
        e.removedSets = (e.removedSets ?? 0) + 1
        entries[key] = e
    }

    /// Puts removed sets back.
    public mutating func restoreSets(key: String) {
        entries[key]?.removedSets = nil
    }

    /// Skips the whole exercise today (clears anything logged) or, with nil, brings it back.
    public mutating func skip(key: String, reason: String?) {
        if let reason {
            entries[key] = LoggedItem(skipped: reason)
        } else {
            entries[key]?.skipped = nil
        }
    }

    /// Ticks every active set; blank weights take `weight`, blank reps stay blank (count as the top of the range).
    public mutating func markAllDone(key: String, planned: Int, weight: Double?) {
        var e = entries[key] ?? LoggedItem()
        let active = e.activeSets(planned: planned)
        e.ensureSets(active)
        for i in 0..<active where !e.sets[i].isDone {
            e.sets[i].ticked = true
            if e.sets[i].weight == nil { e.sets[i].weight = weight }
        }
        entries[key] = e
    }

    /// Changes one warm-up step's weight; nil goes back to the calculated weight.
    public mutating func setWarmWeight(_ weight: Double?, step index: Int) {
        var w = warmWeights ?? [:]
        w["\(index)"] = weight
        warmWeights = w.isEmpty ? nil : w
    }

    public func warmWeight(step index: Int) -> Double? { warmWeights?["\(index)"] }

    public mutating func toggleWarmTick(_ index: Int) {
        if let i = warmTicks.firstIndex(of: index) {
            warmTicks.remove(at: i)
        } else {
            warmTicks.append(index)
        }
    }
}

extension LoggedSet {
    public var isDone: Bool { ticked || reps != nil }
}

extension LoggedItem {
    /// Sets planned for today after removals; 0 when the exercise is skipped.
    public func activeSets(planned: Int) -> Int {
        if skipped != nil { return 0 }
        return max(1, planned - (removedSets ?? 0))
    }

    public var hasCompletedWork: Bool { ticked || rounds != nil || sets.contains { $0.isDone } }

    public mutating func ensureSets(_ count: Int) {
        while sets.count < count { sets.append(LoggedSet()) }
    }
}
