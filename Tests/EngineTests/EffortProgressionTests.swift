import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct EffortProgressionTests {
    let on = AdaptiveSettings(effortProgression: true)

    @Test func topOfRangeWithThreeLeftDoublesTheJump() {
        let bench = finish(foundationMain("bench"), sets(185, [5, 5, 5, 5]), rir: 3, adaptive: on)
        #expect(bench.lifts["bench"]?.workingWeight == 195)
        #expect(bench.lifts["bench"]?.note == EffortRules.doubleNote)
        let curl = finish(liftItem("curl"), sets(25, [12, 12, 12]), rir: 3, adaptive: on)
        #expect(curl.lifts["curl"]?.workingWeight == 35)
    }

    @Test func topOfRangeSolidIsTheNormalJump() {
        let r = finish(foundationMain("bench"), sets(185, [5, 5, 5, 5]), rir: 2, adaptive: on)
        #expect(r.lifts["bench"]?.workingWeight == 190)
        #expect(r.lifts["bench"]?.note == nil)
    }

    @Test func topOfRangeGrinderHoldsTheWeight() {
        let r = finish(foundationMain("bench"), sets(185, [5, 5, 5, 5]),
                       record: LiftRecord(exerciseID: "bench", workingWeight: 185, fails: 1), rir: 0, adaptive: on)
        #expect(r.lifts["bench"]?.workingWeight == 185)
        #expect(r.lifts["bench"]?.fails == 0)
        #expect(r.lifts["bench"]?.note == EffortRules.holdNote)
    }

    @Test func inRangeWithThreeLeftStillGoesUp() {
        let r = finish(liftItem("bbrow", kind: .main, sets: 3, low: 8, high: 10), sets(100, [9, 9, 9]),
                       record: LiftRecord(exerciseID: "bbrow", workingWeight: 100, holds: 2), rir: 3, adaptive: on)
        #expect(r.lifts["bbrow"]?.workingWeight == 105)
        #expect(r.lifts["bbrow"]?.holds == 0)
    }

    @Test func missesKeepTheExistingRules() {
        let r = finish(foundationMain("bench"), sets(185, [5, 4, 3, 3]),
                       record: LiftRecord(exerciseID: "bench", workingWeight: 185, fails: 1), rir: 3, adaptive: on)
        #expect(r.lifts["bench"]?.workingWeight == 165)
    }

    @Test func settingOffOrNoEffortKeepsTheWebAppRules() {
        #expect(finish(foundationMain("bench"), sets(185, [5, 5, 5, 5]), rir: 3).lifts["bench"]?.workingWeight == 190)
        #expect(finish(foundationMain("bench"), sets(185, [5, 5, 5, 5]), adaptive: on).lifts["bench"]?.workingWeight == 190)
    }

    @Test func effortIsSavedInHistory() {
        let r = finish(foundationMain("bench"), sets(185, [5, 5, 5, 5]), rir: 2, adaptive: on)
        #expect(r.lifts["bench"]?.history.last?.rir == 2)
    }

    @Test func repsLeftCountTowardTheEstimatedMax() throws {
        let rec = LiftRecord(exerciseID: "bench",
                             history: [HistoryEntry(date: t0, weight: 200, reps: 5, targetHi: 5, rir: 3)])
        let plain = try #require(Suggestions.best1RM(rec))
        let withEffort = try #require(Suggestions.best1RM(rec, countEffort: true))
        #expect(plain == Suggestions.e1RM(weight: 200, reps: 5))
        #expect(withEffort == Suggestions.e1RM(weight: 200, reps: 8))
    }
}
