import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct RoundTimerTests {
    func item(_ slot: Slot, key: String, week: Int = 1) -> SessionItem? {
        SessionBuilder.build(slot: slot, context: SessionDraft(slot: slot, week: week).context(runMinutes: 25)).item(key)
    }

    @Test func bagRoundsUseTheirWorkAndRest() {
        let all = Catalog.bundled.engineWorkouts
        let i = all.firstIndex { $0.name == "Heavy Bag Rounds" }!
        var ctx = SessionDraft(slot: .C, week: 1).context(runMinutes: 25)
        ctx.condSwap = i
        let bag = SessionBuilder.build(slot: .C, context: ctx).item("engine")!
        let s = RoundPlan.defaults(for: bag)
        #expect(s.work == 120 && s.rest == 60 && s.rounds == 8)
        #expect(RoundPlan.summary(s) == "2:00 on · 1:00 off · 8 rounds · 23 min")
    }

    @Test func noRestAfterTheLastRound() {
        let p = RoundPlan.phases(.init(rounds: 3, work: 60, rest: 30))
        #expect(p.map(\.kind) == [.getReady, .work, .rest, .work, .rest, .work])
        #expect(RoundPlan.phaseStarts(p) == [0, 10, 70, 100, 160, 190])
    }

    @Test func positionCountsFinishedRounds() {
        let p = RoundPlan.phases(.init(rounds: 3, work: 60, rest: 30))
        #expect(RoundPlan.position(p, elapsed: 5) == .init(phase: 0, remaining: 5, roundsDone: 0))
        #expect(RoundPlan.position(p, elapsed: 75) == .init(phase: 2, remaining: 25, roundsDone: 1))
        #expect(RoundPlan.position(p, elapsed: 400).finished)
        #expect(RoundPlan.position(p, elapsed: 400).roundsDone == 3)
    }

    @Test func emomLogsMinutes() {
        let s = RoundPlan.Settings(rounds: 10, work: 60, rest: 0)
        #expect(RoundPlan.phases(s).count == 11)
        #expect(RoundPlan.logged(roundsDone: 10, settings: s, unit: .min) == 10)
        #expect(RoundPlan.logged(roundsDone: 4, settings: .init(rounds: 6, work: 60, rest: 30), unit: .rounds) == 4)
    }

    @Test func settingsNeverGoBelowLimits() {
        let s = RoundPlan.Settings(rounds: 0, work: 1, rest: -5)
        #expect(s.rounds == 1 && s.work == 5 && s.rest == 0)
    }
}
