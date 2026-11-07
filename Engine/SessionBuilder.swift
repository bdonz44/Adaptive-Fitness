import Foundation

public enum ItemKind: String, Codable, Sendable {
    case main, accessory, engine, finisher, run
}

public enum BlockKind: String, Codable, Sendable {
    case getStrong, engine, box, run, buildTheLook, extras, burnIt

    public var title: String {
        switch self {
        case .getStrong: return "Get strong"
        case .engine: return "Engine"
        case .box: return "Box"
        case .run: return "Run"
        case .buildTheLook: return "Build the look"
        case .extras: return "Extras"
        case .burnIt: return "Burn it"
        }
    }
}

public struct SessionItem: Equatable, Sendable {
    /// Stable key within the session: "main", "p0c1" (pair 0, position 1), "engine", "finisher", "run".
    public var key: String
    /// Display tag: "A" for the main lift, "B1", "B2", "C1"... for superset pairs; empty otherwise.
    public var tag: String
    public var kind: ItemKind
    public var exerciseID: String?
    public var name: String
    public var equipment: Equipment?
    public var unit: ExerciseUnit
    public var side: Bool = false
    public var sets: Int
    /// Rep range (or seconds / yards for holds and carries).
    public var low: Int
    public var high: Int
    public var restSeconds: Int
    /// Planned rounds for engine, finisher and run items (run: minutes).
    public var rounds: Int? = nil
    public var minutesPerRound: Double? = nil
    /// Cue for exercises, description for engine workouts, finishers and runs.
    public var detail: String
    public var pair: Int? = nil
    public var position: Int? = nil
    public var startWeight: Double? = nil
    /// Round timer defaults (seconds), from the workout data.
    public var intervalWork: Int? = nil
    public var intervalRest: Int? = nil
    /// False for program conditioning blocks that have no alternatives.
    public var canSwap: Bool = true

    public var isLift: Bool { kind == .main || kind == .accessory }
    /// Added by hand for today ("Add exercise"), keyed "x-<exercise id>".
    public var isExtra: Bool { key.hasPrefix(SessionItem.extraPrefix) }
    public static let extraPrefix = "x-"
    public static func extraKey(_ exerciseID: String) -> String { extraPrefix + exerciseID }
    public var isCardio: Bool { kind == .engine || kind == .finisher || kind == .run }
    /// First item of a superset pair: its tick starts a 20 sec transition, not the rest.
    public var startsPair: Bool { position == 0 }
}

public struct SessionBlock: Equatable, Sendable {
    public var kind: BlockKind
    public var items: [SessionItem]
    public var title: String { kind.title }
}

public struct Session: Equatable, Sendable {
    public var slot: Slot
    public var title: String
    public var week: ProgramWeek
    public var readiness: Readiness
    public var blocks: [SessionBlock]
    /// Time today (adaptive 2): the minutes it was trimmed to, and what was cut.
    public var budget: Int? = nil
    public var trims: [String] = []

    public var items: [SessionItem] { blocks.flatMap(\.items) }
    public func item(_ key: String) -> SessionItem? { items.first { $0.key == key } }
    /// Deload weeks and Beat-up days: lighter weights, no progression.
    public var isLightDay: Bool { week.isDeload || readiness == .beat }
}

/// Inputs from the session draft.
public struct SessionContext: Equatable, Sendable {
    public var week: Int
    public var readiness: Readiness
    /// User swaps by item key ("p0c1" -> exercise id).
    public var swaps: [String: String]
    public var condSwap: Int?
    public var finSwap: Int?
    public var runMinutes: Int
    /// Exercises added by hand for today, in order.
    public var extras: [String]
    /// The program, days a week, and the absolute week it started on (week 1 of the program).
    public var program: ProgramID
    public var days: Int
    public var startWeek: Int

    public init(week: Int, readiness: Readiness = .normal, swaps: [String: String] = [:],
                condSwap: Int? = nil, finSwap: Int? = nil, runMinutes: Int = Program.defaultRunMinutes,
                extras: [String] = [], program: ProgramID = .hybrid12, days: Int? = nil, startWeek: Int = 1) {
        self.extras = extras
        self.program = program
        self.days = days ?? program.defaultDays
        self.startWeek = startWeek
        self.week = week
        self.readiness = readiness
        self.swaps = swaps
        self.condSwap = condSwap
        self.finSwap = finSwap
        self.runMinutes = runMinutes
    }
}

public enum SessionBuilder {
    private static let letters = Array("ABCDEFGH")

    public static func seed(slot: Slot, week: ProgramWeek) -> Int {
        let index = Array("ABCDER").firstIndex(of: Character(slot.rawValue)) ?? 0
        return (week.wk - 1) + (week.cycle - 1) * 5 + index * 2
    }

    /// Walks the category list starting at n % count and returns the first exercise not already used.
    public static func pick(_ list: [Exercise], n: Int, used: Set<String>) -> Exercise? {
        guard !list.isEmpty else { return nil }
        let start = positiveMod(n, list.count)
        for i in 0..<list.count {
            let e = list[(start + i) % list.count]
            if !used.contains(e.id) { return e }
        }
        return list[start]
    }

    public static func mainSets(liftID: String, week: ProgramWeek, readiness: Readiness) -> Int {
        var sets = PhaseScheme.of(week.phase).mainSets
        if liftID == "deadlift" { sets -= 1 }
        if readiness == .great { sets += 1 }
        if readiness == .beat || week.isDeload { sets -= 1 }
        return max(1, sets)
    }

    public static func build(slot: Slot, context: SessionContext, catalog: Catalog = .bundled) -> Session {
        let week = ProgramWeek(context.week - context.startWeek + 1)
        var session = context.program == .hybrid12
            ? buildHybrid(slot: slot, context: context, week: week, catalog: catalog)
            : ProgramLibrary.build(slot: slot, context: context, week: week, catalog: catalog)
        if let extras = extrasBlock(context: context, week: week, catalog: catalog) {
            let at = session.blocks.firstIndex { $0.kind == .burnIt } ?? session.blocks.count
            session.blocks.insert(extras, at: at)
        }
        return session
    }

    static func buildHybrid(slot: Slot, context: SessionContext, week: ProgramWeek, catalog: Catalog) -> Session {
        let scheme = PhaseScheme.of(week.phase)
        let plan = Program.plan(slot)
        let beat = context.readiness == .beat
        var blocks: [SessionBlock] = []
        var used = Set<String>()
        var hasMain = false

        // 1. Get strong
        if let liftID = plan.mainLift(for: week.phase), let lift = catalog.exercise(liftID) {
            hasMain = true
            used.insert(lift.id)
            let item = SessionItem(
                key: "main", tag: "A", kind: .main, exerciseID: lift.id, name: lift.name,
                equipment: lift.eq, unit: lift.unit, side: lift.side,
                sets: mainSets(liftID: lift.id, week: week, readiness: context.readiness),
                low: scheme.mainLow, high: scheme.mainHigh, restSeconds: scheme.mainRest,
                detail: lift.cue)
            blocks.append(SessionBlock(kind: .getStrong, items: [item]))
        }

        // 2. Engine (Conditioning only)
        if slot == .C, !catalog.engineWorkouts.isEmpty {
            let index = positiveMod(context.condSwap ?? (week.wk - 1 + week.cycle - 1), catalog.engineWorkouts.count)
            let w = catalog.engineWorkouts[index]
            var rounds = w.rounds[week.phase.rawValue]
            if beat { rounds = halfUp(rounds) }
            let item = SessionItem(
                key: "engine", tag: "", kind: .engine, exerciseID: nil, name: w.name,
                equipment: nil, unit: .rounds, sets: 1, low: rounds, high: rounds, restSeconds: 0,
                rounds: rounds, minutesPerRound: w.minPerRound, detail: w.description,
                intervalWork: w.work, intervalRest: w.rest)
            blocks.append(SessionBlock(kind: .engine, items: [item]))
        }

        // 3. Run (optional run only)
        if slot == .R {
            let minutes = beat ? max(15, context.runMinutes - 10) : context.runMinutes
            let item = SessionItem(
                key: "run", tag: "", kind: .run, exerciseID: nil, name: "Easy Run",
                equipment: nil, unit: .min, sets: 1, low: minutes, high: minutes, restSeconds: 0,
                rounds: minutes, minutesPerRound: 1, detail: Program.runDescription)
            blocks.append(SessionBlock(kind: .run, items: [item]))
        }

        // 4. Build the look (skipped on Beat-up days)
        if !beat && !plan.pairs.isEmpty {
            let pairCount = min(slot == .C ? 1 : scheme.pairs, plan.pairs.count)
            let rotation = seed(slot: slot, week: week)
            let letterBase = hasMain ? 1 : 0
            let sets = max(1, scheme.accSets - (week.isDeload ? 1 : 0))
            var items: [SessionItem] = []
            for pi in 0..<pairCount {
                for ci in 0..<2 {
                    let category = plan.pairs[pi][ci]
                    let key = "p\(pi)c\(ci)"
                    let exercise: Exercise?
                    if let swapID = context.swaps[key], let swapped = catalog.exercise(swapID) {
                        exercise = swapped
                    } else {
                        exercise = pick(catalog.accessories(in: category), n: rotation + pi + ci * 3, used: used)
                    }
                    guard let ex = exercise else { continue }
                    used.insert(ex.id)
                    let range: (low: Int, high: Int)
                    switch ex.unit {
                    case .sec: range = (scheme.holdLow, scheme.holdHigh)
                    case .yd: range = (Program.carryYards, Program.carryYards)
                    default: range = (scheme.accLow, scheme.accHigh)
                    }
                    items.append(SessionItem(
                        key: key, tag: "\(letters[letterBase + pi])\(ci + 1)", kind: .accessory,
                        exerciseID: ex.id, name: ex.name, equipment: ex.eq, unit: ex.unit, side: ex.side,
                        sets: sets, low: range.low, high: range.high, restSeconds: scheme.accRest,
                        detail: ex.cue, pair: pi, position: ci))
                }
            }
            if !items.isEmpty { blocks.append(SessionBlock(kind: .buildTheLook, items: items)) }
        }


        // 5. Burn it (A, B, D, E)
        if [Slot.A, .B, .D, .E].contains(slot) {
            let list = catalog.finishers(for: slot)
            if !list.isEmpty {
                let f = list[positiveMod(context.finSwap ?? (week.wk - 1), list.count)]
                var rounds = f.rounds
                if week.phase == .define { rounds = (rounds * 13 + 9) / 10 } // x 1.3, rounded up
                if beat { rounds = halfUp(rounds) }
                let item = SessionItem(
                    key: "finisher", tag: "", kind: .finisher, exerciseID: nil, name: f.name,
                    equipment: f.startWeight != nil ? .db : nil, unit: f.unit, sets: 1,
                    low: rounds, high: rounds, restSeconds: 0,
                    rounds: rounds, minutesPerRound: f.minPerRound ?? 2, detail: f.description,
                    startWeight: f.startWeight, intervalWork: f.work, intervalRest: f.rest)
                blocks.append(SessionBlock(kind: .burnIt, items: [item]))
            }
        }

        return Session(slot: slot, title: plan.name, week: week, readiness: context.readiness, blocks: blocks)
    }

    /// Exercises added by hand: accessory sets, reps and rest for the phase (cleans and snatches: 3-5 reps).
    static func extrasBlock(context: SessionContext, week: ProgramWeek, catalog: Catalog) -> SessionBlock? {
        let scheme = PhaseScheme.of(week.phase)
        let extraItems: [SessionItem] = context.extras.compactMap { id in
            guard let ex = catalog.exercise(id) else { return nil }
            let range: (low: Int, high: Int)
            let power = ex.category == Catalog.powerCategory
            switch ex.unit {
            case .sec: range = (scheme.holdLow, scheme.holdHigh)
            case .yd: range = (Program.carryYards, Program.carryYards)
            default: range = power ? Program.powerReps : (scheme.accLow, scheme.accHigh)
            }
            return SessionItem(
                key: SessionItem.extraKey(ex.id), tag: "+", kind: .accessory,
                exerciseID: ex.id, name: ex.name, equipment: ex.eq, unit: ex.unit, side: ex.side,
                sets: max(1, scheme.accSets - (week.isDeload ? 1 : 0)), low: range.low, high: range.high,
                restSeconds: power ? Program.powerRest : scheme.accRest, detail: ex.cue)
        }
        return extraItems.isEmpty ? nil : SessionBlock(kind: .extras, items: extraItems)
    }

    /// Swap: the next exercise in the same category not already in the session.
    public static func swapOption(for key: String, in session: Session, catalog: Catalog = .bundled) -> String? {
        guard let item = session.item(key), item.kind == .accessory, !item.isExtra,
              let id = item.exerciseID, let ex = catalog.exercise(id) else { return nil }
        let list = catalog.accessories(in: ex.category)
        guard let index = list.firstIndex(where: { $0.id == id }) else { return nil }
        let inSession = Set(session.items.compactMap(\.exerciseID))
        for step in 1..<max(1, list.count) {
            let candidate = list[(index + step) % list.count]
            if !inSession.contains(candidate.id) { return candidate.id }
        }
        return nil
    }
}

func positiveMod(_ n: Int, _ m: Int) -> Int {
    guard m > 0 else { return 0 }
    return ((n % m) + m) % m
}

/// Half, rounded up.
func halfUp(_ n: Int) -> Int { (n + 1) / 2 }
