import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct DraftTests {
    @Test func draftBuildsTheSameSessionAsItsContext() {
        var d = SessionDraft(slot: .A, week: 5, readiness: .great)
        d.swaps = ["p0c0": "goodmorning"]
        let s = SessionBuilder.build(slot: d.slot, context: d.context(runMinutes: 30))
        #expect(s.item("p0c0")?.exerciseID == "goodmorning")
        #expect(s.readiness == .great)
    }

    @Test func draftFromAnotherWeekIsNotCurrent() {
        let d = SessionDraft(slot: .B, week: 2)
        #expect(d.isCurrent(for: ProgramState(week: 2)))
        #expect(!d.isCurrent(for: ProgramState(week: 3)))
    }

    @Test func changingReadinessClearsItemsWithNoCompletedSets() {
        var d = SessionDraft(slot: .A, week: 1)
        d.entries["main"] = LoggedItem(sets: [LoggedSet(weight: 185, reps: 5, ticked: true), LoggedSet(weight: 185)])
        d.entries["p0c0"] = LoggedItem(sets: [LoggedSet(weight: 95), LoggedSet(weight: 95)])
        d.entries["finisher"] = LoggedItem(rounds: 6)
        d.setReadiness(.beat)
        #expect(d.readiness == .beat)
        #expect(d.entries["main"] != nil)
        #expect(d.entries["p0c0"] == nil)
        #expect(d.entries["finisher"] != nil)
    }

    @Test func sameReadinessKeepsEverything() {
        var d = SessionDraft(slot: .A, week: 1)
        d.entries["p0c0"] = LoggedItem(sets: [LoggedSet(weight: 95)])
        d.setReadiness(.normal)
        #expect(d.entries["p0c0"] != nil)
    }

    @Test func accessorySwapPicksNextAndClearsLog() {
        var d = SessionDraft(slot: .A, week: 1)
        d.entries["p0c0"] = LoggedItem(sets: [LoggedSet(weight: 95, reps: 10, ticked: true)])
        let s = SessionBuilder.build(slot: .A, context: d.context(runMinutes: 25))
        let swapped1 = d.swap("p0c0", in: s)
        #expect(swapped1)
        #expect(d.swaps["p0c0"] == "slrdl")
        #expect(d.entries["p0c0"] == nil)
        let s2 = SessionBuilder.build(slot: .A, context: d.context(runMinutes: 25))
        #expect(s2.item("p0c0")?.exerciseID == "slrdl")
        // Swapping again moves on from the swapped exercise.
        let swapped2 = d.swap("p0c0", in: s2)
        #expect(swapped2)
        #expect(d.swaps["p0c0"] == "hipthrust")
    }

    @Test func engineAndFinisherSwapsStepTheIndex() {
        var c = SessionDraft(slot: .C, week: 1)
        let cs = SessionBuilder.build(slot: .C, context: c.context(runMinutes: 25))
        let swapped3 = c.swap("engine", in: cs)
        #expect(swapped3)
        #expect(c.condSwap == 1)
        #expect(SessionBuilder.build(slot: .C, context: c.context(runMinutes: 25)).item("engine")?.name == "Treadmill Hill Intervals")

        var a = SessionDraft(slot: .A, week: 1)
        let s = SessionBuilder.build(slot: .A, context: a.context(runMinutes: 25))
        let swapped4 = a.swap("finisher", in: s)
        #expect(swapped4)
        #expect(a.finSwap == 1)
        #expect(SessionBuilder.build(slot: .A, context: a.context(runMinutes: 25)).item("finisher")?.name == "Goblet Squat + Swing Ladder")
        // Wraps around after the last one.
        a.finSwap = 2
        let s3 = SessionBuilder.build(slot: .A, context: a.context(runMinutes: 25))
        a.swap("finisher", in: s3)
        #expect(SessionBuilder.build(slot: .A, context: a.context(runMinutes: 25)).item("finisher")?.name == "KB Swing EMOM")
    }

    @Test func mainLiftCannotBeSwapped() {
        var d = SessionDraft(slot: .A, week: 1)
        let s = SessionBuilder.build(slot: .A, context: d.context(runMinutes: 25))
        let swapped5 = d.swap("main", in: s)
        #expect(!swapped5)
    }

    @Test func bellAppliesToThatSetAndLaterUnfinishedSets() throws {
        var d = SessionDraft(slot: .A, week: 1)
        d.entries["p1c0"] = LoggedItem(sets: [
            LoggedSet(weight: 35, reps: 12, ticked: true),
            LoggedSet(weight: 35),
            LoggedSet(weight: 35, reps: 10, ticked: true),
        ])
        d.setWeight(50, key: "p1c0", set: 1, setCount: 4, applyToLaterUnfinished: true)
        let sets = try #require(d.entries["p1c0"]).sets
        #expect(sets.map(\.weight) == [35, 50, 35, 50])
    }

    @Test func plainWeightOnlyChangesOneSet() throws {
        var d = SessionDraft(slot: .A, week: 1)
        d.setWeight(185, key: "main", set: 0, setCount: 4)
        let sets = try #require(d.entries["main"]).sets
        #expect(sets.count == 4)
        #expect(sets.map(\.weight) == [185, nil, nil, nil])
    }

    @Test func warmUpTicksToggle() {
        var d = SessionDraft(slot: .A, week: 1)
        d.toggleWarmTick(1)
        d.toggleWarmTick(2)
        d.toggleWarmTick(1)
        #expect(d.warmTicks == [2])
    }

    @Test func draftSurvivesARoundTrip() throws {
        var d = SessionDraft(slot: .E, week: 7, readiness: .beat)
        d.entries["main"] = LoggedItem(sets: [LoggedSet(weight: 225, reps: 5, ticked: true)], rir: 2)
        d.swaps["p0c1"] = "csrow"
        d.warmTicks = [0, 1]
        let data = try JSONEncoder().encode(d)
        #expect(try JSONDecoder().decode(SessionDraft.self, from: data) == d)
    }
}

@Suite struct CarryForwardTests {
    @Test func doneSetFillsLaterBlankSets() {
        var d = SessionDraft(slot: .A, week: 1)
        d.entries["main"] = LoggedItem(sets: [LoggedSet(weight: 235, reps: 5, ticked: true)])
        d.carryForward(key: "main", from: 0, setCount: 4)
        let sets = d.entries["main"]!.sets
        #expect(sets.count == 4)
        #expect(sets[1...].allSatisfy { $0.weight == 235 && $0.reps == 5 && !$0.ticked })
    }

    @Test func keepsWhatWasTypedAndDoneSets() {
        var d = SessionDraft(slot: .A, week: 1)
        d.entries["main"] = LoggedItem(sets: [LoggedSet(weight: 235, reps: 4, ticked: true),
                                              LoggedSet(weight: 225, reps: nil),
                                              LoggedSet(weight: 240, reps: 5, ticked: true),
                                              LoggedSet()])
        d.carryForward(key: "main", from: 0, setCount: 4)
        let sets = d.entries["main"]!.sets
        #expect(sets[1].weight == 225 && sets[1].reps == 4)
        #expect(sets[2].weight == 240 && sets[2].reps == 5)
        #expect(sets[3].weight == 235 && sets[3].reps == 4)
    }

    @Test func blankRepsStayBlank() {
        var d = SessionDraft(slot: .A, week: 1)
        d.entries["x"] = LoggedItem(sets: [LoggedSet(weight: 50, reps: nil, ticked: true)])
        d.carryForward(key: "x", from: 0, setCount: 3)
        #expect(d.entries["x"]!.sets[2].weight == 50)
        #expect(d.entries["x"]!.sets[2].reps == nil)
    }
}
