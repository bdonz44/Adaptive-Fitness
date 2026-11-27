import Foundation
import Testing
@testable import Hybrid12Engine

/// The Nov 27 adaptive features: interval paces, recovery picks the day, self-adjusting
/// calories, VO2 max and heart-rate recovery, muscle balancing, goals and next block,
/// heart-rate intervals, coach memory.
@Suite struct AdaptivePlusTests {
    // MARK: 1. Interval paces

    @Test func allRoundsDoneMovesThePaceUp() {
        let (r, note) = IntervalPace.next(after: nil, name: "Norwegian 4×4", speed: 7.0, incline: 8,
                                          rounds: 4, planned: 4, rating: .solid, date: t0)
        #expect(r.speed == 7.2 && r.incline == 8)
        #expect(note?.contains("7.2 mph") == true)
        let easy = IntervalPace.next(after: nil, name: "Norwegian 4×4", speed: 7.0, incline: 8,
                                     rounds: 4, planned: 4, rating: .feltEasy, date: t0).record
        #expect(easy.speed == 7.4)
    }

    @Test func missesHoldThenBackOff() {
        let first = IntervalPace.next(after: nil, name: "Norwegian 4×4", speed: 7.4, incline: 8,
                                      rounds: 3, planned: 4, rating: nil, date: t0).record
        #expect(first.speed == 7.4 && first.misses == 1)
        let second = IntervalPace.next(after: first, name: "Norwegian 4×4", speed: 7.4, incline: 8,
                                       rounds: 4, planned: 4, rating: .tooHard, date: t0 + day).record
        #expect(second.speed == 7.2 && second.misses == 0)
        #expect(second.history.count == 2)
    }

    @Test func topSpeedMovesToIncline() {
        let r = IntervalPace.next(after: nil, name: "Hill Sprints", speed: 10.0, incline: 8,
                                  rounds: 8, planned: 8, rating: .solid, date: t0).record
        #expect(r.speed == 10.0 && r.incline == 9)
    }

    @Test func nothingTypedChangesNothing() {
        let (r, note) = IntervalPace.next(after: nil, name: "Norwegian 4×4", speed: nil, incline: nil,
                                          rounds: 4, planned: 4, rating: nil, date: t0)
        #expect(r.history.isEmpty && note == nil)
    }

    @Test func paceTargetText() {
        var r = IntervalPace.next(after: nil, name: "Norwegian 4×4", speed: 7.0, incline: 8,
                                  rounds: 4, planned: 4, rating: .solid, date: t0).record
        #expect(IntervalPace.targetText(r) == "Last time 7.0 mph at 8% incline. Today 7.2 mph at 8% incline.")
        r.history = []
        #expect(IntervalPace.targetText(r) == "Today: 7.2 mph at 8% incline")
        #expect(IntervalPace.targetText(nil) == nil)
    }

    @Test func pacedItemsAreTheTreadmillIntervals() {
        let s = ProgramState(program: .vo2Max, days: 4)
        let a = SessionBuilder.build(slot: .A, context: SessionDraft(slot: .A, state: s).context(for: s))
        #expect(a.items.contains { IntervalPace.tracks($0) })
        let b = SessionBuilder.build(slot: .B, context: SessionDraft(slot: .B, state: s).context(for: s))
        #expect(!b.items.contains { IntervalPace.tracks($0) })   // Zone 2 isn't paced
    }

    // MARK: 2. Recovery picks the day

    @Test func redRecoveryPutsAnEasierDayFirst() {
        let s = ProgramState(program: .vo2Max, days: 4)   // A is the 4×4 (hard)
        let red = DayPicker.pick(state: s, logs: [], now: t0, recovery: 22)
        #expect(red.slot == .B)
        #expect(red.note?.contains("22%") == true)
        let green = DayPicker.pick(state: s, logs: [], now: t0, recovery: 70)
        #expect(green.slot == .A && green.note == nil)
        #expect(DayPicker.pick(state: s, logs: [], now: t0, recovery: nil).slot == .A)
    }

    @Test func redRecoveryWithOnlyHardDaysLeftKeepsThePlan() {
        var s = ProgramState(program: .vo2Max, days: 4)
        s.doneSlots = ["B", "D"]
        #expect(DayPicker.pick(state: s, logs: [], now: t0, recovery: 10).slot == .A)
    }

    // MARK: 3. Self-adjusting calories

    func diet(days: Int, eat: Int, lbPerWeek: Double, start: Double = 220) -> ([WeighIn], [FoodEntry]) {
        let now = t0 + Double(days) * day
        let weigh = stride(from: 0, through: days, by: 2).map { d in
            WeighIn(date: t0 + Double(d) * day, pounds: start + lbPerWeek * Double(d) / 7)
        }
        let food = (0..<days).map { FoodEntry(date: t0 + Double($0) * day + 3600 * 12, protein: 180, calories: eat) }
        _ = now
        return (weigh, food)
    }

    @Test func maintenanceComesFromIntakeAndTrend() throws {
        // Eating 2,400 and losing 1 lb a week = 500 a day under maintenance -> about 2,900.
        let (w, f) = diet(days: 28, eat: 2400, lbPerWeek: -1)
        let m = try #require(Nutrition.maintenance(weighIns: w, food: f, now: t0 + 28 * day))
        #expect(abs(m.calories - 2900) <= 30)
        let a = Nutrition.advice(weighIns: w, settings: .init(goalWeight: 190), now: t0 + 28 * day, food: f)
        #expect(a.maintenance == m.calories)
        // 0.75% of ~216 lb = 1.6 lb a week = 810 a day, capped at 750; floor 10 per lb = 2,200.
        #expect(a.calorieTarget == 2200)
        #expect(a.detail.contains("1.4 lb a week"))
        #expect(a.headline.hasPrefix("Eat "))
    }

    @Test func notEnoughFoodLoggedFallsBackToTheTrendRule() {
        let (w, f) = diet(days: 28, eat: 2400, lbPerWeek: 0)
        let few = Array(f.prefix(5))
        #expect(Nutrition.maintenance(weighIns: w, food: few, now: t0 + 28 * day) == nil)
        let a = Nutrition.advice(weighIns: w, settings: .init(goalWeight: 190), now: t0 + 28 * day, food: few)
        #expect(a.maintenance == nil && a.call == .cut)
    }

    @Test func calorieTargetNeverDropsBelowTheFloor() {
        #expect(Nutrition.calorieTarget(maintenance: 1700, bodyweight: 200, losing: true) == 2000)
        #expect(Nutrition.calorieTarget(maintenance: 3000, bodyweight: 200, losing: true) == 2250)
        #expect(Nutrition.calorieTarget(maintenance: 2830, bodyweight: 200, losing: false) == 2850)
    }

    // MARK: 4 and 9. VO2 max and heart-rate recovery

    @Test func cooperTest() {
        #expect(Fitness.cooper(miles: 1.5) == 42.7)
        #expect(Fitness.cooper(miles: 0.2) == nil)
        #expect(Fitness.cooper(miles: .nan) == nil)
    }

    @Test func heartRateRecoveryAveragesTheDropAfterEachRound() {
        let end1 = t0 + 300, end2 = t0 + 720
        var samples: [HeartRate.Sample] = []
        for (end, peak, after) in [(end1, 165, 140), (end2, 168, 137)] {
            for s in stride(from: -20.0, through: 0, by: 1) { samples.append(.init(date: end + s, bpm: peak - Int(-s) / 5)) }
            samples.append(.init(date: end + 59, bpm: after))
        }
        #expect(Fitness.recovery(samples, workEnds: [end1, end2]) == 28)   // (25 + 31) / 2
        #expect(Fitness.recovery(samples, workEnds: [t0 + 5000]) == nil)
    }

    @Test func fitnessChange() {
        let pts = [(date: t0, value: 38.0), (date: t0 + 30 * day, value: 40.5)]
        #expect(Fitness.change(pts, days: 90, now: t0 + 31 * day) == 2.5)
        #expect(Fitness.change(pts, days: 10, now: t0 + 31 * day) == nil)
    }

    // MARK: 5. Muscle balancing

    @Test func shortMusclesGetAnExtraSet() throws {
        let s0 = ProgramState(program: .ripped, days: 4)
        var s = SessionBuilder.build(slot: .A, context: SessionDraft(slot: .A, state: s0).context(for: s0))
        let before = s.items
        var week: [Muscle: Double] = [:]
        for m in Muscle.allCases { week[m] = 14 }
        week[.shoulders] = 3
        let notes = MuscleBalance.boost(&s, weekSets: week)
        #expect(notes.count == 1)
        let changed = zip(before, s.items).filter { $0.sets != $1.sets }
        #expect(changed.count == 1)
        let ex = try #require(changed.first?.0.exerciseID.flatMap(Catalog.bundled.exercise))
        #expect(MuscleBalance.primary(ex) == .shoulders)
    }

    @Test func balancingAddsAtMostThreeAndNeverOnLightDays() {
        let s0 = ProgramState(program: .ripped, days: 4)
        var s = SessionBuilder.build(slot: .A, context: SessionDraft(slot: .A, state: s0).context(for: s0))
        #expect(MuscleBalance.boost(&s, weekSets: [:]).count <= 3)
        var light = SessionBuilder.build(slot: .A, context: SessionDraft(slot: .A, state: s0, readiness: .beat).context(for: s0))
        #expect(MuscleBalance.boost(&light, weekSets: [:]).isEmpty)
    }

    // MARK: 6 and 10. Goals and the next block

    @Test func goalPlanChainsTheRightPrograms() {
        let g = Goal(kind: .vo2Max, target: 45, start: t0, deadline: t0 + 30 * 7 * day, startValue: 39)
        let plan = GoalPlanner.plan(g, current: .ripped, weeksLeftInBlock: 0, now: t0)
        #expect(plan.map(\.program) == [.vo2Max, .engineStrength, .vo2Max])
        let midBlock = GoalPlanner.plan(g, current: .vo2Max, weeksLeftInBlock: 6, now: t0)
        #expect(midBlock.first?.program == .vo2Max && midBlock.dropFirst().first?.program == .engineStrength)
    }

    @Test func goalStatusFollowsAStraightLine() throws {
        let g = Goal(kind: .bodyweight, target: 190, start: t0, deadline: t0 + 100 * day, startValue: 220)
        let behind = try #require(GoalPlanner.status(g, current: 214, now: t0 + 50 * day))
        #expect(!behind.onTrack && behind.expected == 205)
        let ahead = try #require(GoalPlanner.status(g, current: 204, now: t0 + 50 * day))
        #expect(ahead.onTrack && !ahead.done)
        #expect(GoalPlanner.status(g, current: 189, now: t0 + 60 * day)?.done == true)
        #expect(GoalPlanner.status(g, current: nil, now: t0) == nil)
    }

    @Test func nextBlockFollowsResults() {
        let ok = GoalPlanner.BlockResults(adherence: 0.9, weightChangePct: -3, strengthChangePct: 4, fitnessChange: 2)
        #expect(GoalPlanner.nextBlock(after: .vo2Max, goal: nil, results: ok).program == .engineStrength)
        let stalledWeight = GoalPlanner.BlockResults(adherence: 0.9, weightChangePct: -0.3)
        #expect(GoalPlanner.nextBlock(after: .hybrid12, goal: nil, results: stalledWeight).program == .ripped)
        #expect(GoalPlanner.nextBlock(after: .hybrid12, goal: nil, results: stalledWeight, aboveGoalWeight: false).program != .ripped)
        let missed = GoalPlanner.BlockResults(adherence: 0.4)
        #expect(GoalPlanner.nextBlock(after: .define45, goal: nil, results: missed).program == .define45)
        let g = Goal(kind: .bodyweight, target: 190, start: t0, deadline: t0 + 200 * day, startValue: 220)
        #expect(GoalPlanner.nextBlock(after: .ripped, goal: g, results: ok).program == .define45)
    }

    // MARK: 8. Heart-rate intervals

    @Test func restEndsOnceRecoveredButNotBeforeHalfway() {
        let t = 85...95
        // 176 max: 70% is 123 bpm.
        #expect(HeartIntervals.restCall(bpm: 118, max: 176, target: t, secondsIntoRest: 100, restLength: 180, heldSoFar: 0) == .endRest)
        #expect(HeartIntervals.restCall(bpm: 118, max: 176, target: t, secondsIntoRest: 60, restLength: 180, heldSoFar: 0) == .none)
        #expect(HeartIntervals.restCall(bpm: 150, max: 176, target: t, secondsIntoRest: 179, restLength: 180, heldSoFar: 0) == .holdRest)
        #expect(HeartIntervals.restCall(bpm: 150, max: 176, target: t, secondsIntoRest: 179, restLength: 180, heldSoFar: 60) == .none)
        // Short rests (30/30s) keep the clock.
        #expect(HeartIntervals.restCall(bpm: 100, max: 176, target: t, secondsIntoRest: 25, restLength: 30, heldSoFar: 0) == .none)
        #expect(HeartIntervals.restCall(bpm: nil, max: 176, target: t, secondsIntoRest: 100, restLength: 180, heldSoFar: 0) == .none)
    }

    @Test func fadingWhenTwoLateRoundsMissTheZone() {
        let t = 85...95
        #expect(HeartIntervals.fading(peaks: [160, 135, 136], max: 176, target: t))
        #expect(!HeartIntervals.fading(peaks: [160, 158, 136], max: 176, target: t))
        #expect(!HeartIntervals.fading(peaks: [130, 130], max: 176, target: t))
    }

    // MARK: 11. Coach memory

    @Test func coachMemoryKeepsRecentUniqueNotes() {
        var notes: [CoachMemoryNote] = []
        notes = CoachMemory.adding("Left shoulder sore on overhead press", to: notes, date: t0)
        notes = CoachMemory.adding("  left shoulder sore on overhead press ", to: notes, date: t0 + day)
        #expect(notes.count == 1 && notes[0].date == t0 + day)
        notes = CoachMemory.adding("", to: notes, date: t0)
        #expect(notes.count == 1)
        for i in 0..<40 { notes = CoachMemory.adding("note \(i)", to: notes, date: t0) }
        #expect(notes.count == CoachMemory.limit)
        let ctx = CoachMemory.context(notes, skips: [(name: "Bench Press", reason: "Pain")])
        #expect(ctx?.contains("note 39") == true && ctx?.contains("skipped Bench Press last time (pain)") == true)
        #expect(CoachMemory.context([], skips: []) == nil)
    }

    // MARK: Settings

    @Test func newSwitchesStartOnAndOlderSavesGetThem() throws {
        let s = AdaptiveSettings.starting
        #expect(s.intervalPace && s.recoveryPicksDay && s.muscleBalance && s.heartIntervals)
        let old = try JSONDecoder().decode(AdaptiveSettings.self, from: Data(#"{"nutrition":false}"#.utf8))
        #expect(old.intervalPace && !old.nutrition)
    }
}
