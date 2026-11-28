import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct CustomWorkoutTests {
    let workout = CustomWorkout(name: "Arms + Abs", items: [
        CustomWorkout.Item(exerciseID: "bench", sets: 4, low: 5, high: 5, rest: 150),
        CustomWorkout.Item(exerciseID: "curl", sets: 3, low: 8, high: 12, rest: 60),
        CustomWorkout.Item(exerciseID: "plank", sets: 3, low: 30, high: 45, rest: 45),
        CustomWorkout.Item(exerciseID: "nope", sets: 3, low: 8, high: 12, rest: 60),
    ])

    @Test func buildsTheWorkoutAsTyped() throws {
        let s = SessionBuilder.buildCustom(workout, week: ProgramWeek(1), readiness: .normal)
        #expect(s.title == "Arms + Abs" && s.slot == .R)
        #expect(s.items.count == 3)   // unknown exercise dropped
        let main = try #require(s.item("main"))
        #expect(main.exerciseID == "bench" && main.kind == .main && main.sets == 4 && main.restSeconds == 150)
        #expect(s.item("c1")?.high == 12)
        #expect(Set(s.items.map(\.key)).count == s.items.count)
    }

    @Test func beatUpDaysDropASet() {
        let s = SessionBuilder.buildCustom(workout, week: ProgramWeek(1), readiness: .beat)
        #expect(s.item("main")?.sets == 3)
    }

    @Test func aCustomSessionNeverCountsOrAdvances() {
        let state = ProgramState(week: 3, program: .ripped, days: 4)
        let s = SessionBuilder.buildCustom(workout, week: ProgramWeek(3), readiness: .normal)
        let after = Program.markDone(s.slot, state: state).state
        #expect(after.doneCount == state.doneCount && after.week == state.week)
    }

    @Test func savedInTheDraftAndReadBack() throws {
        var d = SessionDraft(slot: .R, week: 3)
        d.custom = workout
        let back = try #require(SafeJSON.decode(SessionDraft.self, try JSONEncoder().encode(d)))
        #expect(back.custom == workout)
    }

    @Test func sensibleDefaults() {
        let c = Catalog.bundled
        #expect(CustomWorkout.defaults(for: c.exercise("squat")!).high == 5)
        #expect(CustomWorkout.defaults(for: c.exercise("plank")!).low == 30)
        #expect(CustomWorkout.defaults(for: c.exercise("curl")!).high == 12)
    }
}
