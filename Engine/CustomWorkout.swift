import Foundation

/// A workout you build yourself: exercises with sets, reps and rest. Done on any day as an
/// extra session (it never counts as one of the program's sessions or moves the week).
public struct CustomWorkout: Codable, Equatable, Identifiable, Sendable {
    public struct Item: Codable, Equatable, Sendable {
        public var exerciseID: String
        public var sets: Int
        public var low: Int
        public var high: Int
        public var rest: Int
        public init(exerciseID: String, sets: Int, low: Int, high: Int, rest: Int) {
            self.exerciseID = exerciseID; self.sets = sets; self.low = low; self.high = high; self.rest = rest
        }
    }

    public var id: String
    public var name: String
    public var items: [Item]

    public init(id: String = UUID().uuidString, name: String, items: [Item]) {
        self.id = id; self.name = name; self.items = items
    }

    /// Starting sets, reps and rest for an exercise added to a workout.
    public static func defaults(for ex: Exercise) -> Item {
        switch (ex.unit, ex.category) {
        case (.sec, _): return Item(exerciseID: ex.id, sets: 3, low: 30, high: 45, rest: 45)
        case (.yd, _): return Item(exerciseID: ex.id, sets: 3, low: Program.carryYards, high: Program.carryYards, rest: 60)
        case (_, "main"): return Item(exerciseID: ex.id, sets: 4, low: 5, high: 5, rest: 150)
        case (_, "power"), (_, "olyvar"): return Item(exerciseID: ex.id, sets: 5, low: 3, high: 3, rest: 120)
        default: return Item(exerciseID: ex.id, sets: 3, low: 8, high: 12, rest: 60)
        }
    }

    /// Rep choices offered for each unit.
    public static func repChoices(_ unit: ExerciseUnit) -> [(low: Int, high: Int)] {
        switch unit {
        case .sec: return [(20, 30), (30, 45), (45, 60), (60, 90)]
        case .yd: return [(Program.carryYards, Program.carryYards)]
        default: return [(1, 2), (3, 3), (3, 5), (5, 5), (6, 8), (8, 10), (8, 12), (10, 15), (15, 20)]
        }
    }

    public static let restChoices = [30, 45, 60, 90, 120, 150, 180, 240]
}

extension SessionBuilder {
    /// Today's session from a workout you built. The first main barbell lift gets the warm-up.
    public static func buildCustom(_ w: CustomWorkout, week: ProgramWeek, readiness: Readiness,
                                   catalog: Catalog = .bundled) -> Session {
        var items: [SessionItem] = []
        var hasMain = false
        for (i, it) in w.items.enumerated() {
            guard let ex = catalog.exercise(it.exerciseID) else { continue }
            let isMain = !hasMain && ex.category == "main" && ex.eq == .bb
            if isMain { hasMain = true }
            let sets = max(1, it.sets - (readiness == .beat ? 1 : 0))
            items.append(SessionItem(key: isMain ? "main" : "c\(i)", tag: "\(i + 1)", kind: isMain ? .main : .accessory,
                                     exerciseID: ex.id, name: ex.name, equipment: ex.eq, unit: ex.unit, side: ex.side,
                                     sets: sets, low: min(it.low, it.high), high: max(it.low, it.high),
                                     restSeconds: max(0, it.rest), detail: ex.cue))
        }
        let blocks = items.isEmpty ? [] : [SessionBlock(kind: .getStrong, items: items)]
        return Session(slot: .R, title: w.name.isEmpty ? "Your workout" : w.name, week: week, readiness: readiness, blocks: blocks)
    }
}
