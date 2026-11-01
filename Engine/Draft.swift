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
    }

    public func context(runMinutes: Int) -> SessionContext {
        SessionContext(week: week, readiness: readiness, swaps: swaps,
                       condSwap: condSwap, finSwap: finSwap, runMinutes: runMinutes)
    }

    /// A draft from an earlier week is discarded.
    public func isCurrent(for state: ProgramState) -> Bool { week == state.week }

    public var hasWork: Bool { entries.values.contains { $0.hasCompletedWork } }

    /// Changing readiness clears any items with no completed sets so weights recalculate.
    public mutating func setReadiness(_ newValue: Readiness) {
        guard newValue != readiness else { return }
        readiness = newValue
        entries = entries.filter { $0.value.hasCompletedWork }
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
    public var hasCompletedWork: Bool { ticked || rounds != nil || sets.contains { $0.isDone } }

    public mutating func ensureSets(_ count: Int) {
        while sets.count < count { sets.append(LoggedSet()) }
    }
}
