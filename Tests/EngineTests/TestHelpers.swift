import Foundation
@testable import Hybrid12Engine

let day: TimeInterval = 86400
let t0 = Date(timeIntervalSince1970: 1_790_000_000)

/// Ticked sets at one weight.
func sets(_ weight: Double?, _ reps: [Int?]) -> [LoggedSet] {
    reps.map { LoggedSet(weight: weight, reps: $0, ticked: true) }
}

/// A standalone lift item for rule tests.
func liftItem(_ id: String, kind: ItemKind = .accessory, sets: Int = 3, low: Int = 10, high: Int = 12) -> SessionItem {
    let ex = Catalog.bundled.exercise(id)!
    return SessionItem(key: "x", tag: "", kind: kind, exerciseID: id, name: ex.name, equipment: ex.eq,
                       unit: ex.unit, side: ex.side, sets: sets, low: low, high: high, restSeconds: 60,
                       detail: ex.cue)
}

/// Main lift as built for Foundation: 4 x 5.
func foundationMain(_ id: String) -> SessionItem {
    liftItem(id, kind: .main, sets: 4, low: 5, high: 5)
}

func finish(_ item: SessionItem, _ logged: [LoggedSet], record: LiftRecord? = nil,
            week: Int = 1, readiness: Readiness = .normal, rir: Int? = nil) -> ProgressResult {
    let session = Session(slot: .A, title: "Test", week: ProgramWeek(week), readiness: readiness,
                          blocks: [SessionBlock(kind: .getStrong, items: [item])])
    var lifts: [String: LiftRecord] = [:]
    if let record { lifts[record.exerciseID] = record }
    return Progression.progress(session: session, entries: [item.key: LoggedItem(sets: logged, rir: rir)],
                                lifts: lifts, date: t0, runMinutes: Program.defaultRunMinutes)
}

func entry(_ weight: Double, _ reps: Int, targetHi: Int = 5, daysAgo: Double = 7) -> HistoryEntry {
    HistoryEntry(date: t0.addingTimeInterval(-daysAgo * day), weight: weight, reps: reps, targetHi: targetHi)
}
