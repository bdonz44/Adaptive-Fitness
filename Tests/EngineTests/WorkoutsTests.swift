import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct WorkoutsTests {
    let minute: TimeInterval = 60

    func session(_ slot: Slot) -> Session {
        SessionBuilder.build(slot: slot, context: SessionDraft(slot: slot, week: 1).context(runMinutes: 25))
    }

    let worked = ["x": LoggedItem(sets: sets(100, [5]))]

    @Test func strengthRunsFromFirstTickToFinish() {
        let r = Workouts.record(session: session(.B), entries: worked, startedAt: t0.addingTimeInterval(-52 * minute),
                                finishedAt: t0, cardioMinutes: 0)
        #expect(r?.kind == .strength)
        #expect(r?.start == t0.addingTimeInterval(-52 * minute))
        #expect(r?.end == t0)
        #expect(r?.minutes == 52)
    }

    @Test func unbelievableStartFallsBackTo45Minutes() {
        for started in [nil, t0.addingTimeInterval(-2 * minute), t0.addingTimeInterval(-6 * 3600)] {
            let r = Workouts.record(session: session(.A), entries: worked, startedAt: started,
                                    finishedAt: t0, cardioMinutes: 0)
            #expect(r?.minutes == 45)
        }
    }

    @Test func nothingLoggedWritesNothing() {
        #expect(Workouts.record(session: session(.B), entries: [:], startedAt: nil, finishedAt: t0, cardioMinutes: 0) == nil)
        #expect(Workouts.record(session: session(.B), entries: ["x": LoggedItem()], startedAt: nil,
                                finishedAt: t0, cardioMinutes: 0) == nil)
    }

    @Test func easyRunIsARunningWorkoutOfTheLoggedMinutes() {
        let run = ["run": LoggedItem(rounds: 30, ticked: true)]
        let r = Workouts.record(session: session(.R), entries: run, startedAt: t0.addingTimeInterval(-5 * minute),
                                finishedAt: t0, cardioMinutes: 30)
        #expect(r?.kind == .running)
        #expect(r?.start == t0.addingTimeInterval(-30 * minute))
        #expect(Workouts.record(session: session(.R), entries: run, startedAt: nil, finishedAt: t0, cardioMinutes: 0) == nil)
    }

    @Test func draftNotesStartOnFirstWorkOnly() {
        var d = SessionDraft(slot: .B, week: 1)
        d.noteStart(at: t0)
        #expect(d.startedAt == nil)
        d.toggleWarmTick(0)
        d.noteStart(at: t0)
        d.entries["x"] = LoggedItem(sets: sets(100, [5]))
        d.noteStart(at: t0.addingTimeInterval(600))
        #expect(d.startedAt == t0)
    }
}
