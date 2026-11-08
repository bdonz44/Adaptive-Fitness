import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct PlateauBreakerTests {
    let on = AdaptiveSettings(plateauBreaker: true)

    @Test func thirdStuckSessionStartsTheBreakerInsteadOfDropping() throws {
        let item = liftItem("bench", kind: .main, sets: 4, low: 6, high: 8)
        let r = finish(item, sets(185, [7, 7, 7, 7]),
                       record: LiftRecord(exerciseID: "bench", workingWeight: 185, holds: 2), adaptive: on)
        let rec = try #require(r.lifts["bench"])
        #expect(rec.breaker == 3 && rec.workingWeight == 185 && rec.holds == 0)
        #expect(rec.note == PlateauBreaker.startNote)
        // Without the switch: the old 5% reset.
        let off = finish(item, sets(185, [7, 7, 7, 7]), record: LiftRecord(exerciseID: "bench", workingWeight: 185, holds: 2))
        #expect(off.lifts["bench"]?.workingWeight == 175 && off.lifts["bench"]?.breaker == nil)
    }

    @Test func sessionsBuildAsHeavyTriplesWhileItRuns() throws {
        var ctx = SessionContext(week: 2)
        ctx.breakers = ["bench": 3]
        let main = try #require(SessionBuilder.build(slot: .D, context: ctx).item("main"))
        #expect(main.exerciseID == "bench" && main.sets == 5 && main.low == 3 && main.high == 3 && main.restSeconds >= 180)
        #expect(main.detail.hasPrefix("Plateau breaker, 1 of 3"))
        var deload = SessionContext(week: 4)
        deload.breakers = ["bench": 3]
        #expect(SessionBuilder.build(slot: .D, context: deload).item("main")?.high == 5)
    }

    @Test func countsDownAndEnds() throws {
        let triples = liftItem("bench", kind: .main, sets: 5, low: 3, high: 3)
        var rec = LiftRecord(exerciseID: "bench", workingWeight: 200, breaker: 3)
        for left in [2, 1] {
            rec = try #require(finish(triples, sets(rec.workingWeight, [3, 3, 3, 3, 3]), record: rec, adaptive: on).lifts["bench"])
            #expect(rec.breaker == left)
        }
        rec = try #require(finish(triples, sets(rec.workingWeight, [3, 3, 3, 3, 3]), record: rec, adaptive: on).lifts["bench"])
        #expect(rec.breaker == nil && rec.note == PlateauBreaker.endNote)
        #expect(rec.workingWeight == 215)   // three good sessions of triples moved it up
    }

    @Test func heavyTriplesAreSuggestedOffTheEstimatedMax() throws {
        let rec = LiftRecord(exerciseID: "bench", workingWeight: 185, history: [HistoryEntry(date: t0, weight: 185, reps: 7, targetHi: 8)])
        let triples = liftItem("bench", kind: .main, sets: 5, low: 3, high: 3)
        let w = try #require(Suggestions.suggest(item: triples, lifts: ["bench": rec], lightenToday: false).weight)
        #expect(w > 185)
    }
}
