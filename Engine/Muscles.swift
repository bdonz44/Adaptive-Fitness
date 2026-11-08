import Foundation

/// Hard sets per muscle per week. 10-20 is the range research ties to growth (Schoenfeld 2016,
/// Baz-Valle 2022). A set counts 1 for the main muscle and 0.5 for helpers.
public enum Muscle: String, CaseIterable, Codable, Sendable {
    case chest, shoulders, back, biceps, triceps, quads, hamstrings, glutes, core

    public var name: String { rawValue.capitalized }
}

public enum MuscleMap {
    public static let low = 10.0
    public static let high = 20.0

    typealias Work = [Muscle: Double]

    /// By exercise where it differs from its category.
    static let byExercise: [String: Work] = [
        "squat": [.quads: 1, .glutes: 0.5, .core: 0.5], "fsquat": [.quads: 1, .glutes: 0.5, .core: 0.5],
        "bench": [.chest: 1, .triceps: 0.5, .shoulders: 0.5], "incline": [.chest: 1, .shoulders: 0.5, .triceps: 0.5],
        "floorpress": [.chest: 1, .triceps: 0.5], "ohp": [.shoulders: 1, .triceps: 0.5],
        "pushpress": [.shoulders: 1, .triceps: 0.5, .quads: 0.5], "deadlift": [.hamstrings: 1, .glutes: 1, .back: 0.5],
        "rdl": [.hamstrings: 1, .glutes: 0.5], "slrdl": [.hamstrings: 1, .glutes: 0.5], "hipthrust": [.glutes: 1, .hamstrings: 0.5],
        "kbswingh": [.glutes: 1, .hamstrings: 0.5], "kbswing": [.glutes: 1, .hamstrings: 0.5], "goodmorning": [.hamstrings: 1, .glutes: 0.5],
        "thruster": [.quads: 1, .shoulders: 1], "kbcp": [.shoulders: 1, .glutes: 0.5], "squatpress": [.quads: 1, .shoulders: 1],
        "burpee": [.chest: 0.5, .quads: 0.5], "pushup": [.chest: 1, .triceps: 0.5], "deficitpu": [.chest: 1, .triceps: 0.5],
        "cgpushup": [.triceps: 1, .chest: 0.5], "renegade": [.back: 1, .core: 0.5],
        "trxrow": [.back: 1, .biceps: 0.5], "trxsarow": [.back: 1, .biceps: 0.5], "trxhighrow": [.back: 1, .shoulders: 0.5],
        "trxpowerpull": [.back: 1, .core: 0.5], "trxfacepull": [.shoulders: 1, .back: 0.5], "trxyfly": [.shoulders: 1, .back: 0.5],
        "trxtfly": [.shoulders: 1, .back: 0.5], "trxpress": [.chest: 1, .triceps: 0.5], "trxpushup": [.chest: 1, .core: 0.5],
        "trxchestfly": [.chest: 1], "trxatomic": [.chest: 1, .core: 1], "trxcurl": [.biceps: 1], "trxtricep": [.triceps: 1],
        "trxsquat": [.quads: 1, .glutes: 0.5], "trxpistol": [.quads: 1, .glutes: 0.5], "trxlunge": [.quads: 1, .glutes: 0.5],
        "trxsprinter": [.quads: 1, .glutes: 0.5], "trxsquatrow": [.quads: 0.5, .back: 1], "trxhamcurl": [.hamstrings: 1],
        "trxhippress": [.glutes: 1, .hamstrings: 0.5],
        "powerclean": [.glutes: 1, .hamstrings: 0.5, .back: 0.5], "hangclean": [.glutes: 1, .hamstrings: 0.5, .back: 0.5],
        "powersnatch": [.glutes: 1, .shoulders: 0.5, .back: 0.5], "hangsnatch": [.glutes: 1, .shoulders: 0.5, .back: 0.5],
        "dbhangclean": [.glutes: 1, .back: 0.5], "dbsnatch": [.glutes: 1, .shoulders: 0.5], "kbclean": [.glutes: 1, .back: 0.5],
        "kbsnatch": [.glutes: 1, .shoulders: 0.5], "getup": [.core: 1, .shoulders: 0.5], "kbwindmill": [.core: 1, .shoulders: 0.5],
        "pullup": [.back: 1, .biceps: 0.5], "chinup": [.back: 1, .biceps: 1], "suitcase": [.core: 1],
    ]

    static let byCategory: [String: Work] = [
        "chest": [.chest: 1, .triceps: 0.5], "delt": [.shoulders: 1], "bicep": [.biceps: 1], "tricep": [.triceps: 1],
        "row": [.back: 1, .biceps: 0.5], "quad": [.quads: 1, .glutes: 0.5], "hinge": [.hamstrings: 1, .glutes: 0.5],
        "core": [.core: 1], "abs": [.core: 1], "full": [.quads: 0.5, .shoulders: 0.5], "trx": [.core: 1],
        "power": [.glutes: 1], "pull": [.back: 1, .biceps: 0.5],
    ]

    public static func work(_ ex: Exercise) -> [Muscle: Double] {
        byExercise[ex.id] ?? byCategory[ex.category] ?? [:]
    }

    /// Hard sets per muscle from (exercise id, finished sets) pairs.
    public static func sets(_ done: [(exerciseID: String, sets: Int)], catalog: Catalog = .bundled) -> [Muscle: Double] {
        var out: [Muscle: Double] = [:]
        for d in done where d.sets > 0 {
            guard let ex = catalog.exercise(d.exerciseID) else { continue }
            for (m, f) in work(ex) { out[m, default: 0] += f * Double(d.sets) }
        }
        return out
    }

    /// Muscles under 10 sets, lowest first.
    public static func short(_ sets: [Muscle: Double]) -> [Muscle] {
        Muscle.allCases.filter { (sets[$0] ?? 0) < low }.sorted { (sets[$0] ?? 0) < (sets[$1] ?? 0) }
    }

    /// Finished sets per exercise in a logged session. Uses the saved exercise ids, and for
    /// sessions saved before those existed, the rebuilt session (and "x-<id>" extras).
    public static func done(entries: [String: LoggedItem], session: Session?) -> [(exerciseID: String, sets: Int)] {
        entries.compactMap { key, e in
            let id = e.exerciseID ?? session?.item(key)?.exerciseID
                ?? (key.hasPrefix(SessionItem.extraPrefix) ? String(key.dropFirst(SessionItem.extraPrefix.count)) : nil)
            guard let id, e.skipped == nil else { return nil }
            let n = e.sets.filter(\.isDone).count
            return n > 0 ? (id, n) : nil
        }
    }
}
