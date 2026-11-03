import Foundation

/// Internal slot letters never change; display order is `Program.order`.
public enum Slot: String, Codable, CaseIterable, Sendable {
    case A, B, C, D, E, R
}

public enum Phase: Int, Codable, CaseIterable, Sendable {
    case foundation = 0, build = 1, define = 2

    public var name: String {
        switch self {
        case .foundation: return "Foundation"
        case .build: return "Build"
        case .define: return "Define"
        }
    }
}

public enum Readiness: String, Codable, CaseIterable, Sendable {
    case great, normal, beat
}

/// Everything derived from the stored absolute week number (starts at 1, never resets).
public struct ProgramWeek: Equatable, Sendable {
    public let week: Int

    public init(_ week: Int) { self.week = max(1, week) }

    /// Week within the 12-week cycle.
    public var wk: Int { ((week - 1) % 12) + 1 }
    public var cycle: Int { (week - 1) / 12 + 1 }
    public var phase: Phase { wk <= 4 ? .foundation : (wk <= 8 ? .build : .define) }
    /// Weeks 4 and 8 are back-off weeks.
    public var isDeload: Bool { wk == 4 || wk == 8 }
}

/// Fixed set and rep schemes per phase. Rest is in seconds.
public struct PhaseScheme: Equatable, Sendable {
    public let mainSets: Int
    public let mainLow: Int
    public let mainHigh: Int
    public let mainRest: Int
    public let accSets: Int
    public let accLow: Int
    public let accHigh: Int
    public let accRest: Int
    public let holdLow: Int
    public let holdHigh: Int
    public let pairs: Int

    public static func of(_ phase: Phase) -> PhaseScheme {
        switch phase {
        case .foundation:
            return PhaseScheme(mainSets: 4, mainLow: 5, mainHigh: 5, mainRest: 150,
                               accSets: 3, accLow: 10, accHigh: 12, accRest: 75,
                               holdLow: 30, holdHigh: 45, pairs: 2)
        case .build:
            return PhaseScheme(mainSets: 4, mainLow: 6, mainHigh: 8, mainRest: 120,
                               accSets: 4, accLow: 10, accHigh: 15, accRest: 60,
                               holdLow: 40, holdHigh: 60, pairs: 3)
        case .define:
            return PhaseScheme(mainSets: 3, mainLow: 6, mainHigh: 6, mainRest: 90,
                               accSets: 3, accLow: 12, accHigh: 15, accRest: 45,
                               holdLow: 45, holdHigh: 60, pairs: 2)
        }
    }
}

public struct SlotPlan: Sendable {
    public let slot: Slot
    /// Day number in the week (nil for the optional run).
    public let day: Int?
    public let name: String
    /// Main lift id by phase (Foundation, Build, Define); nil when the slot has none.
    public let mainLifts: [String]?
    /// Superset pairs as accessory categories, in order.
    public let pairs: [[String]]

    public func mainLift(for phase: Phase) -> String? {
        mainLifts?[phase.rawValue]
    }
}

public enum Program {
    /// Display order of the five required sessions.
    public static let order: [Slot] = [.B, .C, .A, .D, .E]
    /// Leg-heavy slots.
    public static let lower: [Slot] = [.A, .E]
    public static let required: Set<Slot> = [.A, .B, .C, .D, .E]
    public static let defaultRunMinutes = 25
    public static let cardioGoalMinutes = 120
    public static let carryYards = 40
    public static let runDescription = "Conversational pace on trails or treadmill. Slow down or walk if you cannot talk in full sentences."

    public static let plans: [Slot: SlotPlan] = [
        .B: SlotPlan(slot: .B, day: 1, name: "Upper Physique",
                     mainLifts: ["ohp", "incline", "pushpress"],
                     pairs: [["delt", "bicep"], ["chest", "tricep"], ["delt", "tricep"]]),
        .C: SlotPlan(slot: .C, day: 2, name: "Conditioning",
                     mainLifts: nil,
                     pairs: [["core", "core"]]),
        .A: SlotPlan(slot: .A, day: 3, name: "Heavy Lower",
                     mainLifts: ["squat", "squat", "squat"],
                     pairs: [["hinge", "core"], ["quad", "core"], ["quad", "hinge"]]),
        .D: SlotPlan(slot: .D, day: 4, name: "Heavy Upper",
                     mainLifts: ["bench", "bench", "floorpress"],
                     pairs: [["row", "bicep"], ["row", "tricep"], ["delt", "chest"]]),
        .E: SlotPlan(slot: .E, day: 5, name: "Full-Body Lean-Out",
                     mainLifts: ["deadlift", "deadlift", "deadlift"],
                     pairs: [["full", "row"], ["quad", "core"], ["full", "chest"]]),
        .R: SlotPlan(slot: .R, day: nil, name: "Easy Run (optional)",
                     mainLifts: nil,
                     pairs: []),
    ]

    public static func plan(_ slot: Slot) -> SlotPlan { plans[slot]! }
}

// MARK: - Program state, week advance, plan controls

public struct ProgramState: Codable, Equatable, Sendable {
    public var week: Int
    public var doneSlots: [String]
    public var startDate: Date?
    public var runMinutes: Int

    public init(week: Int = 1, doneSlots: [String] = [], startDate: Date? = nil, runMinutes: Int = Program.defaultRunMinutes) {
        self.week = week
        self.doneSlots = doneSlots
        self.startDate = startDate
        self.runMinutes = runMinutes
    }

    public func isDone(_ slot: Slot) -> Bool { doneSlots.contains(slot.rawValue) }
    public var doneCount: Int { Program.order.filter { isDone($0) }.count }
    /// Four (or, after a repair, five) done shows a "Start next week" link.
    public var canStartNextWeek: Bool { doneCount >= 4 }
}

public struct WeekAdvance: Equatable, Sendable {
    public var state: ProgramState
    /// Set when this finished a week.
    public var finishedWeek: Int?
    public var message: String?
}

public struct LogStamp: Equatable, Sendable {
    public var slot: Slot
    public var date: Date
    public init(slot: Slot, date: Date) { self.slot = slot; self.date = date }
}

extension Program {
    /// Marks a slot done after a log (or a Skip). The run never counts.
    /// When A through E are all done the week advances and `done` clears.
    public static func markDone(_ slot: Slot, state: ProgramState) -> WeekAdvance {
        var s = state
        guard slot != .R else { return WeekAdvance(state: s, finishedWeek: nil, message: nil) }
        if !s.doneSlots.contains(slot.rawValue) { s.doneSlots.append(slot.rawValue) }
        guard required.allSatisfy({ s.isDone($0) }) else {
            return WeekAdvance(state: s, finishedWeek: nil, message: nil)
        }
        return advance(s)
    }

    /// Every slot with a session logged in the current week counts as done (repairs
    /// a done list that lost entries, for example to an iCloud duplicate). Never
    /// advances the week; the easy run is ignored.
    public static func addingLogged(_ slots: [Slot], state: ProgramState) -> ProgramState {
        var s = state
        for slot in order where slots.contains(slot) && !s.doneSlots.contains(slot.rawValue) {
            s.doneSlots.append(slot.rawValue)
        }
        return s
    }

    public enum SlotStatus: Equatable, Sendable {
        /// Finished with a log this week.
        case logged(Date)
        /// Counted as done with no log (skipped, imported or marked by hand).
        case markedDone
        case toDo
    }

    /// Each session of the week and why it counts (or not). `logged` = newest log date per slot this week.
    public static func weekStatus(state: ProgramState, logged: [Slot: Date]) -> [(slot: Slot, status: SlotStatus)] {
        order.map { slot in
            guard state.isDone(slot) else { return (slot, .toDo) }
            if let d = logged[slot] { return (slot, .logged(d)) }
            return (slot, .markedDone)
        }
    }

    /// Marks or unmarks one session by hand. Never advances the week.
    public static func setDone(_ slot: Slot, _ done: Bool, state: ProgramState) -> ProgramState {
        guard slot != .R else { return state }
        var s = state
        if done {
            if !s.doneSlots.contains(slot.rawValue) { s.doneSlots.append(slot.rawValue) }
        } else {
            s.doneSlots.removeAll { $0 == slot.rawValue }
        }
        return s
    }

    /// The "Start next week" link (shown when four are done).
    public static func startNextWeek(_ state: ProgramState) -> WeekAdvance {
        advance(state)
    }

    private static func advance(_ state: ProgramState) -> WeekAdvance {
        var s = state
        let finished = s.week
        s.week += 1
        s.doneSlots = []
        var message = "Week \(finished) done."
        if ProgramWeek(s.week).isDeload { message += " Next week is a back-off week." }
        return WeekAdvance(state: s, finishedWeek: finished, message: message)
    }

    /// Jump to week 1-12 within the current cycle. Clears done (the caller also clears the draft).
    public static func jump(toWeekInCycle n: Int, state: ProgramState) -> ProgramState {
        var s = state
        let target = min(12, max(1, n))
        s.week = (ProgramWeek(state.week).cycle - 1) * 12 + target
        s.doneSlots = []
        return s
    }

    /// Next session = first open slot in order. If A or E was logged in the
    /// last 48 hours, skip to the first open slot that is not A or E.
    /// All five done: the optional run.
    public static func nextSlot(state: ProgramState, logs: [LogStamp], now: Date) -> Slot {
        let open = order.filter { !state.isDone($0) }
        guard let first = open.first else { return .R }
        let recentLower = logs.contains { log in
            lower.contains(log.slot) && log.date <= now && now.timeIntervalSince(log.date) < 48 * 3600
        }
        if recentLower, let upper = open.first(where: { !lower.contains($0) }) {
            return upper
        }
        return first
    }
}
