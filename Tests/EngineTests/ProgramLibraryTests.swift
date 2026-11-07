import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct ProgramLibraryTests {
    let custom: [ProgramID] = [.engineStrength, .define45, .strengthBoxing]

    func state(_ id: ProgramID, days: Int, week: Int = 1) -> ProgramState {
        ProgramState(week: week, program: id, days: days)
    }

    func build(_ s: ProgramState, _ slot: Slot, readiness: Readiness = .normal) -> Session {
        SessionBuilder.build(slot: slot, context: SessionDraft(slot: slot, state: s, readiness: readiness).context(for: s))
    }

    @Test func everyPlannedExerciseExists() {
        for id in custom {
            for d in id.dayOptions {
                for day in ProgramLibrary.days(id, days: d) {
                    for lift in day.lifts { for x in lift.ids { #expect(Catalog.bundled.exercise(x) != nil, "\(id) \(day.name): \(x)") } }
                    for pair in day.pairs { for ids in pair { for x in ids { #expect(Catalog.bundled.exercise(x) != nil, "\(id) \(day.name): \(x)") } } }
                }
            }
        }
    }

    @Test func everyDayOfEveryWeekBuilds() {
        for id in custom {
            for d in id.dayOptions {
                let s0 = state(id, days: d)
                #expect(s0.order.count == d)
                for w in 1...12 {
                    let s = state(id, days: d, week: w)
                    for slot in s.order {
                        let session = build(s, slot)
                        #expect(!session.items.isEmpty, "\(id) \(d)d wk\(w) \(slot)")
                        #expect(session.title == s.slotName(slot))
                        #expect(Set(session.items.map(\.key)).count == session.items.count, "duplicate keys")
                        #expect(session.items.filter { $0.kind == .main }.count <= 1)
                        #expect(session.items.allSatisfy { $0.sets >= 1 && $0.low <= $0.high })
                    }
                }
            }
        }
    }

    @Test func engineStrengthDayOneIsSquatThenNorwegian() throws {
        let s = build(state(.engineStrength, days: 4), .A)
        #expect(s.item("main")?.exerciseID == "squat")
        #expect(s.item("main")?.sets == 4 && s.item("main")?.low == 5)
        let e = try #require(s.item("engine"))
        #expect(e.name == "Norwegian 4×4" && e.rounds == 4 && e.intervalWork == 240 && e.intervalRest == 180)
        #expect(!e.canSwap)
    }

    @Test func snatchBlocksGrowByPhase() {
        let rounds = [1, 5, 9].map { build(state(.engineStrength, days: 4, week: $0), .C).item("engine")?.rounds }
        #expect(rounds == [20, 30, 40])
    }

    @Test func boxingDaysHaveABoxBlock() throws {
        let s = build(state(.strengthBoxing, days: 3), .A)
        let box = try #require(s.blocks.first { $0.kind == .box })
        #expect(box.title == "Box")
        #expect(box.items.first?.intervalWork == 180)
        #expect(s.item("power")?.exerciseID == "powerclean")
    }

    @Test func backOffWeeksAndBeatUpDaysAreLighter() throws {
        let normal = build(state(.define45, days: 4, week: 1), .A)
        let deload = build(state(.define45, days: 4, week: 4), .A)
        let dm = try #require(deload.item("main")), nm = try #require(normal.item("main"))
        let da = try #require(deload.item("p0c0")), na = try #require(normal.item("p0c0"))
        #expect(dm.sets == nm.sets - 1)
        #expect(da.sets == na.sets - 1)
        #expect(deload.isLightDay)
        let beat = build(state(.define45, days: 4, week: 1), .A, readiness: .beat)
        #expect(!beat.items.contains { $0.pair == 1 })
        #expect(beat.item("finisher") == nil)
    }

    @Test func threeDayWeekRollsOverAfterThree() {
        var s = state(.strengthBoxing, days: 3)
        s = Program.markDone(.A, state: s).state
        s = Program.markDone(.B, state: s).state
        #expect(s.canStartNextWeek)
        let adv = Program.markDone(.C, state: s)
        #expect(adv.finishedWeek == 1)
        #expect(adv.state.programWeek.week == 2 && adv.state.doneSlots.isEmpty)
    }

    @Test func lowerDaysAreNotBackToBack() {
        let s = state(.engineStrength, days: 4)
        #expect(s.lower == [.A, .C])
        let now = Date()
        let next = Program.nextSlot(state: Program.setDone(.A, true, state: s),
                                    logs: [LogStamp(slot: .A, date: now.addingTimeInterval(-3600))], now: now)
        #expect(next == .B)
    }

    @Test func switchingRemembersEachProgramsWeek() {
        var s = ProgramState(week: 7, doneSlots: ["B"])
        s = Program.switchTo(.define45, days: 3, state: s)
        #expect(s.program == .define45 && s.days == 3)
        #expect(s.programWeek.week == 1 && s.week == 8 && s.doneSlots.isEmpty)
        #expect(s.resumeWeeks["hybrid12"] == 7)
        s.week += 2  // two weeks of Define 45
        s = Program.switchTo(.hybrid12, days: 5, state: s)
        #expect(s.program == .hybrid12 && s.programWeek.week == 7)
        #expect(s.resumeWeeks["define45"] == 3)
        s = Program.switchTo(.define45, days: 4, state: s)
        #expect(s.programWeek.week == 3 && s.days == 4)
    }

    @Test func changingDaysKeepsTheWeek() {
        var s = state(.engineStrength, days: 5, week: 3)
        s.doneSlots = ["A", "E"]
        s = Program.switchTo(.engineStrength, days: 3, state: s)
        #expect(s.week == 3 && s.days == 3 && s.doneSlots == ["A"])
    }

    @Test func storedDoneListRoundTrips() {
        var s = Program.switchTo(.strengthBoxing, days: 5, state: ProgramState(week: 9, doneSlots: ["A"]))
        s.doneSlots = ["A", "B"]
        var back = ProgramState(week: s.week)
        back.applyStored(doneSlots: s.storedDoneSlots)
        #expect(back == ProgramState(week: s.week, doneSlots: ["A", "B"], program: .strengthBoxing, days: 5,
                                     startWeek: s.startWeek, resumeWeeks: ["hybrid12": 9]))
    }

    @Test func hybridRecordsStayExactlyAsBefore() {
        let s = ProgramState(week: 5, doneSlots: ["B", "C"])
        #expect(s.storedDoneSlots == ["B", "C"])
        var back = ProgramState(week: 5)
        back.applyStored(doneSlots: ["B", "C"])
        #expect(back.program == .hybrid12 && back.startWeek == 1 && back.doneSlots == ["B", "C"])
    }

    @Test func planTextListsEachDay() {
        let lines = PlanText.programSessions(state: state(.engineStrength, days: 3))
        #expect(lines.count == 3)
        #expect(lines[0].hasPrefix("Day 1 · Squat + 4×4: Back Squat 4×5"))
        #expect(lines[0].contains("Norwegian 4×4 (4 rounds)"))
    }

    @Test func timeTodayTrimsCustomSessions() {
        let s = build(state(.define45, days: 4, week: 5), .C)  // Upper B, three pairs
        let f = TimeBox.fit(s, minutes: 30)
        #expect(TimeBox.minutes(f) < TimeBox.minutes(s))
        #expect(f.item("main") != nil)
    }

    @Test func swapsWorkInCustomPrograms() {
        let s0 = state(.define45, days: 4)
        let s = build(s0, .A)
        let next = SessionBuilder.swapOption(for: "p0c0", in: s)
        #expect(next != nil)
        var d = SessionDraft(slot: .A, state: s0)
        d.swaps["p0c0"] = next!
        #expect(SessionBuilder.build(slot: .A, context: d.context(for: s0)).item("p0c0")?.exerciseID == next)
    }
}
