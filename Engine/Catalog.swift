import Foundation

public enum Equipment: String, Codable, Sendable {
    /// bb = barbell, db = dumbbell, kb = kettlebell, bw = bodyweight
    case bb, db, kb, bw
}

public enum ExerciseUnit: String, Codable, Sendable {
    case reps, sec, yd, min, rounds
}

public struct Exercise: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// "main" for the main barbell lifts, otherwise the accessory category
    /// (hinge, quad, core, delt, chest, bicep, tricep, row, full).
    public let category: String
    public let eq: Equipment
    /// Barbell increment in lb. Dumbbells always move 5 lb.
    public let inc: Double?
    public let unit: ExerciseUnit
    /// Done each side.
    public let side: Bool
    public let cue: String
}

public struct EngineWorkout: Codable, Hashable, Sendable {
    public let name: String
    /// Rounds by phase: Foundation, Build, Define.
    public let rounds: [Int]
    public let minPerRound: Double
    /// Round timer: seconds of work and rest per round (interval workouts only).
    public let work: Int?
    public let rest: Int?
    public let description: String
}

public struct Finisher: Codable, Hashable, Sendable {
    public let slot: String
    public let name: String
    public let rounds: Int
    /// `.min` when the rounds are minutes (EMOM), otherwise `.rounds`.
    public let unit: ExerciseUnit
    public let minPerRound: Double?
    public let startWeight: Double?
    /// Round timer: seconds of work and rest per round (interval finishers only).
    public let work: Int?
    public let rest: Int?
    public let description: String
}

/// The bundled exercise data. New moves go in the JSON files, not code.
public struct Catalog: Sendable {
    public let mainLifts: [Exercise]
    /// Order within a category matters: rotation walks the list.
    public let accessories: [Exercise]
    public let engineWorkouts: [EngineWorkout]
    public let finishers: [Finisher]
    private let byID: [String: Exercise]

    public init(mainLifts: [Exercise], accessories: [Exercise], engineWorkouts: [EngineWorkout], finishers: [Finisher]) {
        self.mainLifts = mainLifts
        self.accessories = accessories
        self.engineWorkouts = engineWorkouts
        self.finishers = finishers
        var map: [String: Exercise] = [:]
        for e in mainLifts + accessories { map[e.id] = e }
        self.byID = map
    }

    public func exercise(_ id: String) -> Exercise? { byID[id] }

    public func accessories(in category: String) -> [Exercise] {
        accessories.filter { $0.category == category }
    }

    public func finishers(for slot: Slot) -> [Finisher] {
        finishers.filter { $0.slot == slot.rawValue }
    }

    public func isMainLift(_ id: String) -> Bool {
        mainLifts.contains { $0.id == id }
    }

    private struct ExerciseFile: Codable {
        let main: [Exercise]
        let accessories: [Exercise]
    }

    public static func load(bundle: Bundle) throws -> Catalog {
        func data(_ name: String) throws -> Data {
            guard let url = bundle.url(forResource: name, withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(name).json"])
            }
            return try Data(contentsOf: url)
        }
        let decoder = JSONDecoder()
        let ex = try decoder.decode(ExerciseFile.self, from: data("exercises"))
        let engine = try decoder.decode([EngineWorkout].self, from: data("engine"))
        let fin = try decoder.decode([Finisher].self, from: data("finishers"))
        return Catalog(mainLifts: ex.main, accessories: ex.accessories, engineWorkouts: engine, finishers: fin)
    }

    /// The data shipped in this package.
    public static let bundled: Catalog = {
        do { return try Catalog.load(bundle: .module) } catch { fatalError("Bundled exercise data is missing or invalid: \(error)") }
    }()
}

enum Fmt {
    /// 135 -> "135", 2.5 -> "2.5"
    static func lb(_ w: Double) -> String {
        if w == w.rounded() { return String(Int(w)) }
        return String(format: "%.1f", w)
    }
}
