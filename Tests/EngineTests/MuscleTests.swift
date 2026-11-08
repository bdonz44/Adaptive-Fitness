import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct MuscleTests {
    @Test func everyExerciseHitsSomething() {
        for e in Catalog.bundled.mainLifts + Catalog.bundled.accessories {
            #expect(!MuscleMap.work(e).isEmpty, "\(e.id)")
        }
    }

    @Test func setsAddUpWithHelpersAtHalf() {
        let s = MuscleMap.sets([("bench", 4), ("curl", 3), ("bbrow", 4)])
        #expect(s[.chest] == 4 && s[.triceps] == 2 && s[.shoulders] == 2)
        #expect(s[.biceps] == 5 && s[.back] == 4)
        #expect(MuscleMap.short(s).first == .quads)
    }

    @Test func readsSavedIdsOrTheRebuiltSession() {
        let session = SessionBuilder.build(slot: .D, context: SessionContext(week: 1))
        var withID = LoggedItem(sets: sets(185, [5, 5, 5]))
        withID.exerciseID = "incline"
        let entries: [String: LoggedItem] = [
            "main": LoggedItem(sets: sets(185, [5, 5, 5, 5])),     // old log: no id, rebuilt
            "p0c0": withID,                                         // saved id wins
            "x-curl": LoggedItem(sets: sets(25, [12, 12])),         // extras carry their id in the key
            "p1c0": LoggedItem(skipped: "Pain"),
        ]
        let done = MuscleMap.done(entries: entries, session: session).sorted { $0.exerciseID < $1.exerciseID }
        #expect(done.map(\.exerciseID) == ["bench", "curl", "incline"])
        #expect(done.map(\.sets) == [4, 2, 3])
    }
}
