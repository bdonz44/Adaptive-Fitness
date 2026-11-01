import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct SuggestionsTests {
    func suggest(_ item: SessionItem, _ lifts: [String: LiftRecord], light: Bool = false) -> Suggestion {
        Suggestions.suggest(item: item, lifts: lifts, lightenToday: light)
    }

    // MARK: Math

    @Test func epleyCapsRepsAt12() {
        #expect(abs(Suggestions.e1RM(weight: 100, reps: 5) - 116.6667) < 0.001)
        #expect(Suggestions.e1RM(weight: 100, reps: 20) == Suggestions.e1RM(weight: 100, reps: 12))
    }

    @Test func best1RMUsesLastThreeEntriesWithWeightAndReps() throws {
        let rec = LiftRecord(exerciseID: "bench", history: [
            entry(250, 5), entry(150, 5), entry(150, 5),
            HistoryEntry(date: t0, weight: nil, reps: 5, targetHi: 5),
            entry(150, 5),
        ])
        let best = try #require(Suggestions.best1RM(rec))
        #expect(abs(best - 175) < 0.001)
        #expect(Suggestions.best1RM(LiftRecord(exerciseID: "bench")) == nil)
        #expect(Suggestions.best1RM(nil) == nil)
    }

    @Test func weightForRepTargetLeavesTwoInReserve() {
        // 215.83 / (1 + 7/30) = 175
        let e = Suggestions.e1RM(weight: 185, reps: 5)
        #expect(abs(Suggestions.weight(forReps: 5, e1RM: e) - 175) < 0.001)
    }

    @Test func clampToRealEquipment() {
        #expect(Suggestions.clamp(137, equipment: .bb) == 135)
        #expect(Suggestions.clamp(30, equipment: .bb) == 45)
        #expect(Suggestions.clamp(3, equipment: .db) == 5)
        #expect(Suggestions.clamp(50, equipment: .db) == 35)
        #expect(Suggestions.clamp(43, equipment: .kb) == 50)
        #expect(Suggestions.clamp(42, equipment: .kb) == 35)
        #expect(Suggestions.clamp(28, equipment: .kb) == 35)
        #expect(Suggestions.clamp(27, equipment: .kb) == 20)
    }

    // MARK: Suggestion order

    @Test func rule1StoredWeightWithMatchingTarget() {
        let main = foundationMain("bench")
        let bump = suggest(main, ["bench": LiftRecord(exerciseID: "bench", workingWeight: 190, history: [entry(185, 5)])])
        #expect(bump.weight == 190)
        #expect(bump.reason == "Last time 185 × 5. You earned the bump.")

        let reset = suggest(main, ["bench": LiftRecord(exerciseID: "bench", workingWeight: 165, history: [entry(185, 4)])])
        #expect(reset.weight == 165)
        #expect(reset.reason == "Last time 185 × 4. Reset lower to build back.")

        let same = suggest(main, ["bench": LiftRecord(exerciseID: "bench", workingWeight: 185, history: [entry(185, 5)])])
        #expect(same.weight == 185)
        #expect(same.reason == "Last time 185 × 5. Same weight, beat your reps.")
    }

    @Test func rule2BestOneRepMaxWhenTargetChanged() {
        // Last entry was for a top of 8; today's top is 5.
        let lifts = ["bench": LiftRecord(exerciseID: "bench", workingWeight: 190, history: [entry(185, 5, targetHi: 8)])]
        let s = suggest(foundationMain("bench"), lifts)
        #expect(s.weight == 175)
        #expect(s.reason.hasPrefix("From your recent best"))
    }

    @Test func rule3RelatedLift() {
        // Bench e1RM 215.83 x 0.82 = 176.98; for 8 reps: / (1 + 10/30) = 132.7 -> 135
        let incline = liftItem("incline", kind: .main, sets: 4, low: 6, high: 8)
        let s = suggest(incline, ["bench": LiftRecord(exerciseID: "bench", workingWeight: 185, history: [entry(185, 5)])])
        #expect(s.weight == 135)
        #expect(s.reason == "Estimated from your Bench Press.")
    }

    @Test func rule4StoredWeightOnly() {
        let s = suggest(foundationMain("bench"), ["bench": LiftRecord(exerciseID: "bench", workingWeight: 135)])
        #expect(s.weight == 135)
        #expect(s.reason == "Last used 135 lb.")
    }

    @Test func rule5Nothing() {
        let s = suggest(foundationMain("bench"), [:])
        #expect(s.weight == nil)
        #expect(s.reason == "Pick a weight you could lift for 2 more reps than the target.")
    }

    @Test func dumbbellsClampTo35() {
        let s = suggest(liftItem("curl"), ["curl": LiftRecord(exerciseID: "curl", workingWeight: 40)])
        #expect(s.weight == 35)
    }

    @Test func lightenedOnDeloadAndBeatUp() {
        let lifts = ["bench": LiftRecord(exerciseID: "bench", workingWeight: 200, history: [entry(200, 5)])]
        let s = suggest(foundationMain("bench"), lifts, light: true)
        #expect(s.weight == 180)
        #expect(s.reason == "Last time 200 × 5. Same weight, beat your reps. Lightened 10% for today.")
        // Session flag drives it.
        #expect(SessionBuilder.build(slot: .D, context: SessionContext(week: 4)).isLightDay)
        #expect(!SessionBuilder.build(slot: .D, context: SessionContext(week: 3)).isLightDay)
    }

    // MARK: Kettlebells and bodyweight

    @Test func kettlebellDefaults() {
        #expect(suggest(liftItem("gobletsq"), [:]).weight == 50)
        #expect(suggest(liftItem("kbswingh"), [:]).weight == 50)
        #expect(suggest(liftItem("suitcase"), [:]).weight == 50)
        #expect(suggest(liftItem("gorilla"), [:]).weight == 50)
        #expect(suggest(liftItem("kbswing"), [:]).weight == 50)
        #expect(suggest(liftItem("kbbottoms"), [:]).weight == 20)
        #expect(suggest(liftItem("slrdl"), [:]).weight == 35)
    }

    @Test func kettlebellWithStoredBell() {
        let s35 = suggest(liftItem("slrdl"), ["slrdl": LiftRecord(exerciseID: "slrdl", workingWeight: 35)])
        #expect(s35.weight == 35)
        #expect(s35.reason == "Your 35 lb. Hit every rep and it moves you to the next bell.")
        let s50 = suggest(liftItem("slrdl"), ["slrdl": LiftRecord(exerciseID: "slrdl", workingWeight: 50)])
        #expect(s50.weight == 50)
        #expect(s50.reason == "Once you own every rep here, add reps.")
        // 50 x 0.9 = 45 snaps back to 50.
        #expect(suggest(liftItem("slrdl"), ["slrdl": LiftRecord(exerciseID: "slrdl", workingWeight: 50)], light: true).weight == 50)
    }

    @Test func bellButtonCycles() {
        #expect(Suggestions.nextBellInCycle(20) == 35)
        #expect(Suggestions.nextBellInCycle(35) == 50)
        #expect(Suggestions.nextBellInCycle(50) == 20)
    }

    @Test func bodyweightHasNoWeight() {
        let s = suggest(liftItem("pushup"), ["pushup": LiftRecord(exerciseID: "pushup", note: "Harder: slow the lowering to 3 seconds or add reps.")])
        #expect(s.weight == nil)
        #expect(s.reason == "Harder: slow the lowering to 3 seconds or add reps.")
    }
}
