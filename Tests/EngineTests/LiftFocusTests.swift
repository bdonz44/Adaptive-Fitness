import Foundation
import Testing
@testable import Hybrid12Engine

/// Squat, Bench and Deadlift Builder and Olympic Lifts (Nov 28).
@Suite struct LiftFocusTests {
    func week(_ id: ProgramID, days: Int, week w: Int = 1) -> [Session] {
        let s = ProgramState(week: w, program: id, days: days)
        return s.order.map { SessionBuilder.build(slot: $0, context: SessionDraft(slot: $0, state: s).context(for: s)) }
    }

    func days(_ sessions: [Session], with ids: Set<String>) -> Int {
        sessions.filter { s in s.items.contains { ids.contains($0.exerciseID ?? "") } }.count
    }

    @Test func eachBuilderTrainsItsLiftOften() {
        for d in [3, 4, 5] {
            #expect(days(week(.squatFocus, days: d), with: ["squat", "pausesquat", "fsquat"]) >= 3, "squat \(d)d")
            #expect(days(week(.benchFocus, days: d), with: ["bench", "pausebench", "cgbench"]) >= 3, "bench \(d)d")
            #expect(days(week(.deadliftFocus, days: d), with: ["deadlift", "deficitdl"]) >= 2, "deadlift \(d)d")
            #expect(days(week(.olympic, days: d), with: ["powerclean", "hangclean", "powersnatch", "hangsnatch"]) >= 3, "olympic \(d)d")
        }
    }

    @Test func heavyDayGetsHeavierByPhase() throws {
        let reps = try [1, 5, 9].map { w in try #require(week(.squatFocus, days: 4, week: w)[0].item("main")).high }
        #expect(reps == [5, 3, 2])
    }

    @Test func olympicLiftsMoveFromHangToFullLifts() {
        let early = week(.olympic, days: 4, week: 1)[1].item("power")?.exerciseID
        let late = week(.olympic, days: 4, week: 9)[1].item("power")?.exerciseID
        #expect(early == "hangclean" && late == "powerclean")
    }

    @Test func newLiftsGetWeightsFromTheMainLift() {
        let s = ProgramState(program: .squatFocus, days: 4)
        let session = SessionBuilder.build(slot: .D, context: SessionDraft(slot: .D, state: s).context(for: s))
        let pause = session.item("power")!
        #expect(pause.exerciseID == "pausesquat")
        let squat = LiftRecord(exerciseID: "squat", workingWeight: 275,
                               history: [HistoryEntry(date: t0, weight: 275, reps: 5, targetHi: 5)])
        let w = Suggestions.suggest(item: pause, lifts: ["squat": squat], lightenToday: false).weight
        #expect(w != nil && w! < 275 && w! > 150)
    }

    @Test func newLiftsHaveStandInsWithoutABarbell() {
        var ctx = SessionDraft(slot: .D, state: ProgramState(program: .squatFocus, days: 4))
            .context(for: ProgramState(program: .squatFocus, days: 4))
        ctx.gear = GearProfile(barbell: false)
        let s = SessionBuilder.build(slot: .D, context: ctx)
        #expect(s.items.filter(\.isLift).allSatisfy { $0.equipment != .bb })
    }
}
