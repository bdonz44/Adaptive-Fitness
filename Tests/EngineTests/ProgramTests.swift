import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct ProgramTests {
    @Test func weekMath() {
        let w1 = ProgramWeek(1)
        #expect(w1.wk == 1)
        #expect(w1.cycle == 1)
        #expect(w1.phase == .foundation)
        #expect(!w1.isDeload)
        #expect(ProgramWeek(4).isDeload)
        #expect(ProgramWeek(8).isDeload)
        #expect(!ProgramWeek(12).isDeload)
        #expect(ProgramWeek(5).phase == .build)
        #expect(ProgramWeek(8).phase == .build)
        #expect(ProgramWeek(9).phase == .define)
        #expect(ProgramWeek(12).phase == .define)
        let w13 = ProgramWeek(13)
        #expect(w13.wk == 1)
        #expect(w13.cycle == 2)
        #expect(w13.phase == .foundation)
        #expect(ProgramWeek(16).isDeload)
    }

    @Test func phaseSchemes() {
        let f = PhaseScheme.of(.foundation)
        #expect(f.mainSets == 4 && f.mainLow == 5 && f.mainHigh == 5 && f.mainRest == 150)
        #expect(f.accSets == 3 && f.accLow == 10 && f.accHigh == 12 && f.accRest == 75)
        #expect(f.holdLow == 30 && f.holdHigh == 45 && f.pairs == 2)
        let b = PhaseScheme.of(.build)
        #expect(b.mainSets == 4 && b.mainLow == 6 && b.mainHigh == 8 && b.mainRest == 120)
        #expect(b.accSets == 4 && b.accLow == 10 && b.accHigh == 15 && b.accRest == 60)
        #expect(b.holdLow == 40 && b.holdHigh == 60 && b.pairs == 3)
        let d = PhaseScheme.of(.define)
        #expect(d.mainSets == 3 && d.mainLow == 6 && d.mainHigh == 6 && d.mainRest == 90)
        #expect(d.accSets == 3 && d.accLow == 12 && d.accHigh == 15 && d.accRest == 45)
        #expect(d.holdLow == 45 && d.holdHigh == 60 && d.pairs == 2)
    }

    @Test func completingAllFiveAdvancesTheWeek() {
        var s = ProgramState(week: 3)
        for slot in [Slot.B, .C, .A, .D] { s = Program.markDone(slot, state: s).state }
        #expect(s.week == 3)
        #expect(s.canStartNextWeek)
        let r = Program.markDone(.E, state: s)
        #expect(r.state.week == 4)
        #expect(r.state.doneSlots.isEmpty)
        #expect(r.finishedWeek == 3)
        #expect(r.message == "Week 3 done. Next week is a back-off week.")
    }

    @Test func plainWeekDoneMessage() {
        let s = ProgramState(week: 1, doneSlots: ["A", "B", "C", "D"])
        #expect(Program.markDone(.E, state: s).message == "Week 1 done.")
    }

    @Test func startNextWeekLink() {
        let s = ProgramState(week: 2, doneSlots: ["A", "B", "C", "D"])
        let r = Program.startNextWeek(s)
        #expect(r.state.week == 3)
        #expect(r.state.doneSlots.isEmpty)
    }

    @Test func runNeverCountsOrAdvances() {
        let s = ProgramState(week: 1, doneSlots: ["A", "B", "C", "D"])
        let r = Program.markDone(.R, state: s)
        #expect(r.state == s)
        #expect(r.finishedWeek == nil)
    }

    @Test func markingTwiceDoesNotDuplicate() {
        let s = Program.markDone(.A, state: Program.markDone(.A, state: ProgramState()).state).state
        #expect(s.doneSlots == ["A"])
    }

    @Test func nextSlotFollowsOrder() {
        #expect(Program.nextSlot(state: ProgramState(), logs: [], now: t0) == .B)
        #expect(Program.nextSlot(state: ProgramState(doneSlots: ["B"]), logs: [], now: t0) == .C)
        #expect(Program.nextSlot(state: ProgramState(doneSlots: ["B", "C"]), logs: [], now: t0) == .A)
    }

    @Test func legRecoverySkipsLowerWithin48Hours() {
        let state = ProgramState(doneSlots: ["B", "C"])
        let recent = [LogStamp(slot: .E, date: t0.addingTimeInterval(-20 * 3600))]
        #expect(Program.nextSlot(state: state, logs: recent, now: t0) == .D)
        let old = [LogStamp(slot: .E, date: t0.addingTimeInterval(-50 * 3600))]
        #expect(Program.nextSlot(state: state, logs: old, now: t0) == .A)
    }

    @Test func legRecoveryFallsBackWhenOnlyLowerIsOpen() {
        let state = ProgramState(doneSlots: ["B", "C", "D", "A"])
        let recent = [LogStamp(slot: .A, date: t0.addingTimeInterval(-3600))]
        #expect(Program.nextSlot(state: state, logs: recent, now: t0) == .E)
    }

    @Test func allFiveDoneSuggestsTheRun() {
        let state = ProgramState(doneSlots: ["A", "B", "C", "D", "E"])
        #expect(Program.nextSlot(state: state, logs: [], now: t0) == .R)
    }

    @Test func jumpStaysInCurrentCycle() {
        let s = Program.jump(toWeekInCycle: 5, state: ProgramState(week: 15, doneSlots: ["B"]))
        #expect(s.week == 17)
        #expect(s.doneSlots.isEmpty)
        #expect(Program.jump(toWeekInCycle: 12, state: ProgramState(week: 3)).week == 12)
    }
}

@Suite struct LoggedDoneRepairTests {
    @Test func loggedSlotsCountAsDone() {
        let state = ProgramState(week: 3, doneSlots: ["B"], startDate: nil, runMinutes: 25)
        let fixed = Program.addingLogged([.C, .B, .R], state: state)
        #expect(fixed.doneSlots == ["B", "C"])
        #expect(fixed.week == 3)
    }

    @Test func allFiveLoggedDoesNotAdvance() {
        let fixed = Program.addingLogged(Program.order, state: ProgramState(week: 2, doneSlots: [], startDate: nil, runMinutes: 25))
        #expect(fixed.week == 2)
        #expect(fixed.doneCount == 5)
    }
}
