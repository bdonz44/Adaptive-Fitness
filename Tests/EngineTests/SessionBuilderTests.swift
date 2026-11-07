import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct SessionBuilderTests {
    let catalog = Catalog.bundled

    @Test func bundledDataLoads() {
        #expect(catalog.mainLifts.count == 8)
        #expect(catalog.accessories.count == 72)
        #expect(catalog.engineWorkouts.count == 6)
        for slot in [Slot.A, .B, .D, .E] {
            #expect(catalog.finishers(for: slot).count == 3)
        }
        for plan in Program.plans.values {
            for pair in plan.pairs {
                for category in pair { #expect(!catalog.accessories(in: category).isEmpty, "\(category)") }
            }
            for id in plan.mainLifts ?? [] { #expect(catalog.exercise(id) != nil, "\(id)") }
        }
        let ids = (catalog.mainLifts + catalog.accessories).map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func rotationSeed() {
        #expect(SessionBuilder.seed(slot: .A, week: ProgramWeek(1)) == 0)
        #expect(SessionBuilder.seed(slot: .D, week: ProgramWeek(1)) == 6)
        #expect(SessionBuilder.seed(slot: .B, week: ProgramWeek(3)) == 4)
        #expect(SessionBuilder.seed(slot: .A, week: ProgramWeek(13)) == 5)
    }

    @Test func pickWalksTheListAndSkipsUsed() {
        let hinge = catalog.accessories(in: "hinge")
        #expect(SessionBuilder.pick(hinge, n: 0, used: [])?.id == "rdl")
        #expect(SessionBuilder.pick(hinge, n: 0, used: ["rdl"])?.id == "slrdl")
        #expect(SessionBuilder.pick(hinge, n: 7, used: [])?.id == "hipthrust")
        #expect(SessionBuilder.pick(hinge, n: 4, used: ["goodmorning"])?.id == "rdl")
    }

    @Test func heavyLowerWeekOne() throws {
        let s = SessionBuilder.build(slot: .A, context: SessionContext(week: 1))
        #expect(s.title == "Heavy Lower")
        #expect(s.blocks.map(\.kind) == [.getStrong, .buildTheLook, .burnIt])

        let main = try #require(s.item("main"))
        #expect(main.exerciseID == "squat")
        #expect(main.tag == "A")
        #expect(main.sets == 4 && main.low == 5 && main.high == 5 && main.restSeconds == 150)

        let acc = s.blocks[1].items
        #expect(acc.map { $0.exerciseID ?? "" } == ["rdl", "sideplank", "gobletsq", "suitcase"])
        #expect(acc.map(\.tag) == ["B1", "B2", "C1", "C2"])
        #expect(acc[0].sets == 3 && acc[0].low == 10 && acc[0].high == 12 && acc[0].restSeconds == 75)
        // Timed holds use the hold range; carries are a fixed 40 yd.
        #expect(acc[1].low == 30 && acc[1].high == 45)
        #expect(acc[3].low == 40 && acc[3].high == 40)
        #expect(acc[0].startsPair && !acc[1].startsPair)

        let fin = try #require(s.item("finisher"))
        #expect(fin.name == "KB Swing EMOM")
        #expect(fin.rounds == 10)
        #expect(fin.unit == .min)
    }

    @Test func mainSetModifiers() {
        let w1 = ProgramWeek(1)
        #expect(SessionBuilder.mainSets(liftID: "deadlift", week: w1, readiness: .normal) == 3)
        #expect(SessionBuilder.mainSets(liftID: "deadlift", week: w1, readiness: .great) == 4)
        #expect(SessionBuilder.mainSets(liftID: "deadlift", week: w1, readiness: .beat) == 2)
        #expect(SessionBuilder.mainSets(liftID: "deadlift", week: ProgramWeek(4), readiness: .normal) == 2)
        #expect(SessionBuilder.mainSets(liftID: "bench", week: w1, readiness: .great) == 5)
        #expect(SessionBuilder.mainSets(liftID: "bench", week: ProgramWeek(9), readiness: .normal) == 3)
        // Beat up on a deload week is still minus 1, not minus 2.
        #expect(SessionBuilder.mainSets(liftID: "bench", week: ProgramWeek(4), readiness: .beat) == 3)
    }

    @Test func beatUpIsAShortDay() throws {
        let s = SessionBuilder.build(slot: .A, context: SessionContext(week: 1, readiness: .beat))
        #expect(s.blocks.map(\.kind) == [.getStrong, .burnIt])
        #expect(try #require(s.item("main")).sets == 3)
        #expect(try #require(s.item("finisher")).rounds == 5)
        #expect(s.isLightDay)
    }

    @Test func deloadWeekDropsAccessorySets() throws {
        let s = SessionBuilder.build(slot: .A, context: SessionContext(week: 4))
        #expect(try #require(s.item("main")).sets == 3)
        #expect(try #require(s.item("p0c0")).sets == 2)
        #expect(s.isLightDay)
    }

    @Test func defineFinisherIsLonger() throws {
        let s = SessionBuilder.build(slot: .A, context: SessionContext(week: 9))
        let fin = try #require(s.item("finisher"))
        #expect(fin.name == "Bag Burnout")
        #expect(fin.rounds == 7) // 5 x 1.3 = 6.5, rounded up
        let emom = SessionBuilder.build(slot: .A, context: SessionContext(week: 9, finSwap: 0))
        #expect(emom.item("finisher")?.rounds == 13) // 10 x 1.3
        let beat = SessionBuilder.build(slot: .A, context: SessionContext(week: 9, readiness: .beat))
        #expect(beat.item("finisher")?.rounds == 4) // 7 halved, rounded up
    }

    @Test func conditioningDay() throws {
        let s = SessionBuilder.build(slot: .C, context: SessionContext(week: 1))
        #expect(s.blocks.map(\.kind) == [.engine, .buildTheLook])
        let engine = try #require(s.item("engine"))
        #expect(engine.name == "Heavy Bag Rounds")
        #expect(engine.rounds == 8)
        #expect(engine.minutesPerRound == 3)
        let acc = s.blocks[1].items
        #expect(acc.map { $0.exerciseID ?? "" } == ["suitcase", "deadbug"])
        #expect(acc.map(\.tag) == ["A1", "A2"])
        #expect(s.item("finisher") == nil)
    }

    @Test func conditioningRotationAndSwap() {
        // Week 2: index (2 - 1 + 1 - 1) % 6 = 1
        #expect(SessionBuilder.build(slot: .C, context: SessionContext(week: 2)).item("engine")?.name == "Treadmill Hill Intervals")
        // Cycle 2 week 1: index (0 + 1) % 6 = 1
        #expect(SessionBuilder.build(slot: .C, context: SessionContext(week: 13)).item("engine")?.name == "Treadmill Hill Intervals")
        #expect(SessionBuilder.build(slot: .C, context: SessionContext(week: 1, condSwap: 2)).item("engine")?.name == "Kettlebell Circuit")
        let beat = SessionBuilder.build(slot: .C, context: SessionContext(week: 1, readiness: .beat))
        #expect(beat.item("engine")?.rounds == 4)
        #expect(beat.blocks.map(\.kind) == [.engine])
    }

    @Test func buildPhaseHasThreePairs() throws {
        let s = SessionBuilder.build(slot: .B, context: SessionContext(week: 5))
        #expect(try #require(s.item("main")).exerciseID == "incline")
        let acc = s.blocks[1].items
        #expect(acc.count == 6)
        #expect(acc.map(\.tag) == ["B1", "B2", "C1", "C2", "D1", "D2"])
        #expect(acc[0].sets == 4 && acc[0].low == 10 && acc[0].high == 15 && acc[0].restSeconds == 60)
        #expect(Set(acc.compactMap(\.exerciseID)).count == 6)
    }

    @Test func mainLiftByPhase() {
        #expect(SessionBuilder.build(slot: .B, context: SessionContext(week: 1)).item("main")?.exerciseID == "ohp")
        #expect(SessionBuilder.build(slot: .B, context: SessionContext(week: 9)).item("main")?.exerciseID == "pushpress")
        #expect(SessionBuilder.build(slot: .D, context: SessionContext(week: 9)).item("main")?.exerciseID == "floorpress")
        #expect(SessionBuilder.build(slot: .E, context: SessionContext(week: 1)).item("main")?.exerciseID == "deadlift")
    }

    @Test func userSwapOverridesThePick() {
        let s = SessionBuilder.build(slot: .A, context: SessionContext(week: 1, swaps: ["p0c0": "goodmorning"]))
        #expect(s.item("p0c0")?.exerciseID == "goodmorning")
    }

    @Test func swapMovesToNextUnusedInCategory() {
        let s = SessionBuilder.build(slot: .A, context: SessionContext(week: 1))
        #expect(SessionBuilder.swapOption(for: "p0c0", in: s) == "slrdl")
        // Core list: plank, deadbug, hollow, sideplank, suitcase, bearcrawl. Suitcase is in the session.
        #expect(SessionBuilder.swapOption(for: "p0c1", in: s) == "bearcrawl")
    }

    @Test func easyRun() throws {
        let s = SessionBuilder.build(slot: .R, context: SessionContext(week: 1, runMinutes: 30))
        #expect(s.blocks.map(\.kind) == [.run])
        #expect(try #require(s.item("run")).rounds == 30)
        #expect(SessionBuilder.build(slot: .R, context: SessionContext(week: 1, readiness: .beat, runMinutes: 30)).item("run")?.rounds == 20)
        #expect(SessionBuilder.build(slot: .R, context: SessionContext(week: 1, readiness: .beat, runMinutes: 20)).item("run")?.rounds == 15)
    }
}
