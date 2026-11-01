import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct WarmUpTests {
    @Test func percentagesBeforeAWeightIsTyped() {
        let steps = WarmUp.ramp(lift: "bench", workWeight: nil)
        #expect(steps.map(\.label) == ["Empty bar × 10", "40% × 5", "60% × 3", "80% × 2"])
        #expect(steps.allSatisfy { $0.weight == nil })
        #expect(WarmUp.ramp(lift: "deadlift", workWeight: nil).map(\.label) == ["40% × 5", "60% × 3", "80% × 2"])
    }

    @Test func benchRamp() {
        let steps = WarmUp.ramp(lift: "bench", workWeight: 135)
        #expect(steps.map(\.weight) == [45, 55, 80, 110])
        #expect(steps.map(\.reps) == [10, 5, 3, 2])
        #expect(steps.first?.plates == "empty bar")
        #expect(steps.last?.plates == "32.5 per side")
    }

    @Test func heavyLiftsAddANinetyPercentSingle() {
        let steps = WarmUp.ramp(lift: "squat", workWeight: 225)
        #expect(steps.map(\.weight) == [45, 90, 135, 180, 205])
        #expect(steps.last?.reps == 1)
    }

    @Test func deadliftStartsAt95AndDropsDuplicates() {
        #expect(WarmUp.ramp(lift: "deadlift", workWeight: 135).map(\.weight) == [95, 110])
        #expect(WarmUp.ramp(lift: "deadlift", workWeight: 315).map(\.weight) == [125, 190, 250, 285])
    }

    @Test func stepsAtOrAboveWorkWeightAreDropped() {
        #expect(WarmUp.ramp(lift: "bench", workWeight: 50).map(\.weight) == [45])
        #expect(WarmUp.ramp(lift: "bench", workWeight: 45).isEmpty)
    }

    @Test func plates() {
        #expect(WarmUp.plates(45) == "empty bar")
        #expect(WarmUp.plates(135) == "45 per side")
        #expect(WarmUp.plates(100) == "27.5 per side")
    }
}

@Suite struct CoachTests {
    func weigh(_ pounds: Double, daysAgo: Double) -> WeighIn {
        WeighIn(date: t0.addingTimeInterval(-daysAgo * day), pounds: pounds)
    }

    @Test func needsTwoWeighIns() {
        #expect(Coach.weightTrend(weighIns: [weigh(200, daysAgo: 1)], now: t0)
                == "Log your weight once or twice a week and this checks whether the fat loss is on pace.")
    }

    @Test func needsTenDays() {
        #expect(Coach.weightTrend(weighIns: [weigh(200, daysAgo: 7), weigh(199, daysAgo: 0)], now: t0)
                == "Keep weighing in. The trend check needs about 10 days.")
    }

    @Test func flat() {
        #expect(Coach.weightTrend(weighIns: [weigh(200, daysAgo: 20), weigh(199.9, daysAgo: 0)], now: t0)
                == "Keep the lifting as is. Trim about 300 calories a day or add one more easy run.")
    }

    @Test func tooFast() {
        // 4 lb in 14 days = 2 lb/week, more than 1% of 196.
        #expect(Coach.weightTrend(weighIns: [weigh(200, daysAgo: 14), weigh(196, daysAgo: 0)], now: t0)
                == "Eat a little more and keep protein high (about 1 g per pound of goal weight).")
    }

    @Test func onPace() {
        #expect(Coach.weightTrend(weighIns: [weigh(200, daysAgo: 14), weigh(198, daysAgo: 0)], now: t0)
                == "Losing about 1.0 lb a week. Stay the course.")
    }

    @Test func ignoresWeighInsOlderThan28Days() {
        let w = [weigh(210, daysAgo: 40), weigh(200, daysAgo: 14), weigh(198, daysAgo: 0)]
        #expect(Coach.weightTrend(weighIns: w, now: t0) == "Losing about 1.0 lb a week. Stay the course.")
    }

    @Test func cardio() {
        #expect(Coach.cardioNote(cardioByWeek: [2: 60], week: 3, goal: 120)?.text
                == "Cardio was 60 of 120 min last week. Add an easy run on a non-leg day.")
        #expect(Coach.cardioNote(cardioByWeek: [2: 90], week: 3, goal: 120)?.text
                == "90 min of cardio last week. Good work, keep it going.")
        #expect(Coach.cardioNote(cardioByWeek: [:], week: 1, goal: 120) == nil)
    }

    @Test func strength() {
        let lifts = [
            "squat": LiftRecord(exerciseID: "squat", workingWeight: 235, firstWeight: 225),
            "bench": LiftRecord(exerciseID: "bench", workingWeight: 185, fails: 1, firstWeight: 185),
            "curl": LiftRecord(exerciseID: "curl", workingWeight: 30, firstWeight: 20),
        ]
        #expect(Coach.strengthNote(lifts: lifts, catalog: .bundled)?.text
                == "1 of 2 main lifts are heavier than where you started. One to watch: Bench Press.")
        #expect(Coach.strengthNote(lifts: [:], catalog: .bundled) == nil)
    }

    @Test func coachCheckGivesOneToThreeNotes() {
        let notes = Coach.coachNotes(
            weighIns: [weigh(200, daysAgo: 14), weigh(198, daysAgo: 0)],
            cardioByWeek: [1: 130], week: 2,
            lifts: ["squat": LiftRecord(exerciseID: "squat", workingWeight: 235, firstWeight: 225)],
            now: t0)
        #expect(notes.map(\.kind) == [.weight, .cardio, .strength])
        #expect(Coach.coachNotes(weighIns: [], cardioByWeek: [:], week: 1, lifts: [:], now: t0).count == 1)
    }
}
