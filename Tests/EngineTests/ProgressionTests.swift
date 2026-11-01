import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct ProgressionTests {
    // MARK: Reading the log

    @Test func tickedSetWithBlankRepsLogsTopOfRange() throws {
        let r = try #require(Progression.read(sets: [LoggedSet(weight: 100, reps: nil, ticked: true)], low: 10, high: 12, prescribedSets: 1))
        #expect(r.topReps == 12)
        #expect(r.hitAll)
    }

    @Test func untouchedSetsDoNotCount() {
        #expect(Progression.read(sets: [LoggedSet(weight: 100)], low: 10, high: 12, prescribedSets: 3) == nil)
        let r = Progression.read(sets: [LoggedSet(weight: 100, reps: 10)], low: 10, high: 12, prescribedSets: 3)
        #expect(r?.countedSets == 1)
    }

    @Test func usedWeightIsTheMostLoggedTiesGoHeavier() {
        let most = Progression.read(sets: sets(185, [5, 5]) + sets(195, [5]), low: 5, high: 5, prescribedSets: 3)
        #expect(most?.usedWeight == 185)
        let tie = Progression.read(sets: sets(185, [5]) + sets(195, [3]), low: 5, high: 5, prescribedSets: 3)
        #expect(tie?.usedWeight == 195)
        #expect(tie?.topReps == 3)
        #expect(tie?.miss == true)
    }

    @Test func hitAllNeedsAtLeastMinOfSetsAndThree() {
        let two = Progression.read(sets: sets(185, [5, 5]), low: 5, high: 5, prescribedSets: 4)
        #expect(two?.hitAll == false)
        let three = Progression.read(sets: sets(185, [5, 5, 5]), low: 5, high: 5, prescribedSets: 4)
        #expect(three?.hitAll == true)
        let oneOfOne = Progression.read(sets: sets(185, [5]), low: 5, high: 5, prescribedSets: 1)
        #expect(oneOfOne?.hitAll == true)
    }

    // MARK: Barbell and dumbbell

    @Test func hitAllAddsTheBarbellIncrement() throws {
        let bench = finish(foundationMain("bench"), sets(185, [5, 5, 5, 5]),
                           record: LiftRecord(exerciseID: "bench", workingWeight: 185, fails: 1, holds: 2))
        let rec = try #require(bench.lifts["bench"])
        #expect(rec.workingWeight == 190)
        #expect(rec.fails == 0 && rec.holds == 0)
        #expect(bench.changes.first?.direction == .up)

        let squat = finish(foundationMain("squat"), sets(225, [5, 5, 5, 5]))
        #expect(squat.lifts["squat"]?.workingWeight == 235)
    }

    @Test func hitAllAddsFiveToDumbbells() {
        let r = finish(liftItem("curl"), sets(25, [12, 12, 12]))
        #expect(r.lifts["curl"]?.workingWeight == 30)
    }

    @Test func heaviestDumbbellsGetANote() throws {
        let r = finish(liftItem("curl"), sets(35, [12, 12, 12]))
        let rec = try #require(r.lifts["curl"])
        #expect(rec.workingWeight == 35)
        #expect(rec.note == Progression.maxDumbbellNote)
        #expect(r.changes.first?.note == Progression.maxDumbbellNote)
    }

    @Test func firstMissHolds() throws {
        let r = finish(foundationMain("bench"), sets(185, [5, 5, 4, 3]),
                       record: LiftRecord(exerciseID: "bench", workingWeight: 185))
        let rec = try #require(r.lifts["bench"])
        #expect(rec.workingWeight == 185)
        #expect(rec.fails == 1)
        #expect(r.changes.first?.direction == .same)
    }

    @Test func secondMissInARowDropsTenPercent() throws {
        let r = finish(foundationMain("bench"), sets(185, [5, 4, 4, 3]),
                       record: LiftRecord(exerciseID: "bench", workingWeight: 185, fails: 1))
        let rec = try #require(r.lifts["bench"])
        #expect(rec.workingWeight == 165) // 166.5 rounded to 5
        #expect(rec.fails == 0)
        #expect(rec.note == Progression.droppedTenNote)
        #expect(r.changes.first?.direction == .down)
    }

    @Test func mainLiftInRangeHoldsThenDropsFivePercentOnTheThird() throws {
        let item = liftItem("bench", kind: .main, sets: 4, low: 6, high: 8)
        let first = finish(item, sets(185, [7, 7, 7, 7]), record: LiftRecord(exerciseID: "bench", workingWeight: 185, fails: 1))
        let r1 = try #require(first.lifts["bench"])
        #expect(r1.workingWeight == 185)
        #expect(r1.holds == 1)
        #expect(r1.fails == 0)

        let third = finish(item, sets(185, [7, 7, 7, 7]), record: LiftRecord(exerciseID: "bench", workingWeight: 185, holds: 2))
        let r3 = try #require(third.lifts["bench"])
        #expect(r3.workingWeight == 175) // 175.75 rounded to 5
        #expect(r3.holds == 0)
        #expect(r3.note == Progression.stuckNote)
    }

    @Test func accessoryInRangeStaysAndClearsFails() throws {
        let r = finish(liftItem("curl"), sets(25, [10, 11, 10]), record: LiftRecord(exerciseID: "curl", workingWeight: 25, fails: 1))
        let rec = try #require(r.lifts["curl"])
        #expect(rec.workingWeight == 25)
        #expect(rec.fails == 0)
        #expect(rec.holds == 0)
    }

    @Test func noProgressionOnDeloadOrBeatUp() throws {
        let record = LiftRecord(exerciseID: "bench", workingWeight: 185, fails: 1, holds: 1)
        for (week, readiness) in [(4, Readiness.normal), (1, Readiness.beat)] {
            let r = finish(foundationMain("bench"), sets(165, [5, 5, 5]), record: record, week: week, readiness: readiness)
            let rec = try #require(r.lifts["bench"])
            #expect(rec.workingWeight == 185)
            #expect(rec.fails == 1)
            #expect(rec.holds == 1)
            #expect(rec.history.count == 1)
        }
        // A first-ever log on a light day still stores its weight.
        let fresh = finish(foundationMain("bench"), sets(165, [5, 5, 5]), week: 4)
        #expect(fresh.lifts["bench"]?.workingWeight == 165)
    }

    @Test func historyAppendsAndKeepsTwelve() throws {
        let old = (0..<12).map { entry(100, 5, daysAgo: Double(20 - $0)) }
        let r = finish(foundationMain("bench"), sets(135, [5, 5, 5, 5]),
                       record: LiftRecord(exerciseID: "bench", workingWeight: 135, history: old), rir: 2)
        let rec = try #require(r.lifts["bench"])
        #expect(rec.history.count == 12)
        #expect(rec.history.last == HistoryEntry(date: t0, weight: 135, reps: 5, targetHi: 5, rir: 2))
    }

    @Test func firstWeightIsKept() {
        let first = finish(foundationMain("bench"), sets(135, [5, 5, 5, 5]))
        #expect(first.lifts["bench"]?.firstWeight == 135)
        let later = finish(foundationMain("bench"), sets(140, [5, 5, 5, 5]), record: first.lifts["bench"])
        #expect(later.lifts["bench"]?.firstWeight == 135)
    }

    // MARK: Kettlebell

    @Test func kettlebellHitAllMovesUpABell() {
        #expect(finish(liftItem("gobletsq"), sets(35, [12, 12, 12])).lifts["gobletsq"]?.workingWeight == 50)
        #expect(finish(liftItem("slrdl"), sets(20, [12, 12, 12])).lifts["slrdl"]?.workingWeight == 35)
    }

    @Test func kettlebellAtFiftyStays() throws {
        let rec = try #require(finish(liftItem("gobletsq"), sets(50, [12, 12, 12])).lifts["gobletsq"])
        #expect(rec.workingWeight == 50)
        #expect(rec.note == Progression.ownFiftyNote)
    }

    @Test func kettlebellSecondMissAboveDefaultDropsABell() throws {
        // Goblet Reverse Lunge starts at 35.
        let down = try #require(finish(liftItem("revlunge"), sets(50, [8, 8, 8]),
                                       record: LiftRecord(exerciseID: "revlunge", workingWeight: 50, fails: 1)).lifts["revlunge"])
        #expect(down.workingWeight == 35)
        #expect(down.fails == 0)

        let atDefault = try #require(finish(liftItem("revlunge"), sets(35, [8, 8, 8]),
                                            record: LiftRecord(exerciseID: "revlunge", workingWeight: 35, fails: 1)).lifts["revlunge"])
        #expect(atDefault.workingWeight == 35)
        #expect(atDefault.fails == 2)

        let firstMiss = try #require(finish(liftItem("revlunge"), sets(50, [8, 8, 8])).lifts["revlunge"])
        #expect(firstMiss.workingWeight == 50)
        #expect(firstMiss.fails == 1)
    }

    @Test func kettlebellInRangeChasesReps() throws {
        let rec = try #require(finish(liftItem("slrdl"), sets(35, [10, 11, 10])).lifts["slrdl"])
        #expect(rec.workingWeight == 35)
        #expect(rec.note == Progression.chaseRepsNote)
    }

    // MARK: Bodyweight

    @Test func bodyweightHitAllGetsAHarderNote() throws {
        let plank = liftItem("plank", low: 30, high: 45)
        let rec = try #require(finish(plank, sets(nil, [45, 45, 45])).lifts["plank"])
        #expect(rec.note == "Harder: add 10 to 15 seconds.")
        #expect(rec.workingWeight == nil)

        let carry = liftItem("bearcrawl", low: 40, high: 40)
        #expect(finish(carry, sets(nil, [40, 40, 40])).lifts["bearcrawl"]?.note == "Harder: go a little farther or faster.")
        #expect(finish(liftItem("pushup"), sets(nil, [12, 12, 12])).lifts["pushup"]?.note == "Harder: slow the lowering to 3 seconds or add reps.")
        // Not on a light day.
        #expect(finish(plank, sets(nil, [45, 45, 45]), week: 4).lifts["plank"]?.note == nil)
    }

    // MARK: Cardio and runs

    @Test func cardioMinutesFromEngineAndFinishers() throws {
        let cond = SessionBuilder.build(slot: .C, context: SessionContext(week: 1))
        let typed = Progression.progress(session: cond, entries: ["engine": LoggedItem(rounds: 8)], lifts: [:], date: t0, runMinutes: 25)
        #expect(typed.cardioMinutes == 24) // 8 rounds x 3 min
        let ticked = Progression.progress(session: cond, entries: ["engine": LoggedItem(ticked: true)], lifts: [:], date: t0, runMinutes: 25)
        #expect(ticked.cardioMinutes == 24)
        let none = Progression.progress(session: cond, entries: [:], lifts: [:], date: t0, runMinutes: 25)
        #expect(none.cardioMinutes == 0)

        // EMOM rounds are minutes.
        let lower = SessionBuilder.build(slot: .A, context: SessionContext(week: 1))
        let emom = Progression.progress(session: lower, entries: ["finisher": LoggedItem(ticked: true)], lifts: [:], date: t0, runMinutes: 25)
        #expect(emom.cardioMinutes == 10)

        // Farmer Carry: 4 rounds x default 2 min.
        let upper = SessionBuilder.build(slot: .D, context: SessionContext(week: 1))
        #expect(try #require(upper.item("finisher")).name == "Farmer Carry")
        let carry = Progression.progress(session: upper, entries: ["finisher": LoggedItem(ticked: true)], lifts: [:], date: t0, runMinutes: 25)
        #expect(carry.cardioMinutes == 8)
    }

    @Test func easyRunLength() {
        #expect(Progression.nextRunMinutes(planned: 25, logged: 25, rating: .tooHard, current: 25, beat: false) == 20)
        #expect(Progression.nextRunMinutes(planned: 25, logged: 21, rating: .solid, current: 25, beat: false) == 20)
        #expect(Progression.nextRunMinutes(planned: 25, logged: 22, rating: .solid, current: 25, beat: false) == 25)
        #expect(Progression.nextRunMinutes(planned: 20, logged: 20, rating: .tooHard, current: 20, beat: false) == 20)
        #expect(Progression.nextRunMinutes(planned: 25, logged: 25, rating: .feltEasy, current: 25, beat: false) == 30)
        #expect(Progression.nextRunMinutes(planned: 50, logged: 50, rating: .feltEasy, current: 50, beat: false) == 50)
        #expect(Progression.nextRunMinutes(planned: 15, logged: 15, rating: .feltEasy, current: 25, beat: true) == 25)
        #expect(Progression.nextRunMinutes(planned: 25, logged: 25, rating: .solid, current: 25, beat: false) == 25)
    }

    @Test func runSessionUpdatesRunLengthAndCardio() {
        let run = SessionBuilder.build(slot: .R, context: SessionContext(week: 1, runMinutes: 25))
        let r = Progression.progress(session: run, entries: ["run": LoggedItem(rounds: 25, runRating: .feltEasy, miles: 2.5)],
                                     lifts: [:], date: t0, runMinutes: 25)
        #expect(r.runMinutes == 30)
        #expect(r.cardioMinutes == 25)
    }
}
