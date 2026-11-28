import Foundation
import Testing
@testable import Hybrid12Engine

/// Pain map, lift forecasts and fitness age (Nov 28).
@Suite struct StandOutTests {
    func session(_ id: ProgramID, _ slot: Slot, days: Int = 4) -> Session {
        let s = ProgramState(program: id, days: days)
        return SessionBuilder.build(slot: slot, context: SessionDraft(slot: slot, state: s).context(for: s))
    }

    // MARK: Pain map

    @Test func soreShoulderSwapsOrRemovesEveryLiftThatLoadsIt() {
        var s = session(.ripped, .A)   // bench, presses, laterals...
        let notes = PainMap.adjust(&s, sore: [.shoulder], keep: [])
        #expect(!notes.isEmpty)
        for item in s.items where item.isLift {
            let ex = Catalog.bundled.exercise(item.exerciseID!)!
            #expect(!PainMap.loads(ex).contains(.shoulder), "\(item.name) still loads the shoulder")
        }
        #expect(Set(s.items.map(\.key)).count == s.items.count)
    }

    @Test func loggedLiftsAreLeftAlone() {
        var s = session(.ripped, .A)
        let main = s.item("main")!
        PainMap.adjust(&s, sore: [.shoulder, .elbow, .wrist], keep: ["main"])
        #expect(s.item("main")?.exerciseID == main.exerciseID)
    }

    @Test func soreKneeGetsACardioTipAndLegsChange() {
        var s = session(.vo2Max, .A)   // Norwegian 4×4 only
        let notes = PainMap.adjust(&s, sore: [.knee], keep: [])
        #expect(notes.contains { $0.contains("bike or rower") })
        var legs = session(.ripped, .B)   // squat day
        PainMap.adjust(&legs, sore: [.knee], keep: [])
        #expect(legs.items.filter(\.isLift).allSatisfy { !PainMap.loads(Catalog.bundled.exercise($0.exerciseID!)!).contains(.knee) })
    }

    @Test func nothingSoreChangesNothing() {
        var s = session(.ripped, .A)
        let before = s
        #expect(PainMap.adjust(&s, sore: [], keep: []).isEmpty)
        #expect(s == before)
    }

    @Test func everyPlannedLiftHasALoadMapping() {
        for id in ProgramID.allCases {
            for d in id.dayOptions {
                let st = ProgramState(program: id, days: d)
                for slot in st.order {
                    for item in session(id, slot, days: d).items where item.isLift {
                        let ex = Catalog.bundled.exercise(item.exerciseID!)!
                        #expect(PainMap.byID[ex.id] != nil || PainMap.byCategory[ex.category] != nil, "\(ex.id)")
                    }
                }
            }
        }
    }

    @Test func checkInEveryThreeDays() {
        let spot = SoreSpot(area: .knee, since: t0)
        #expect(!PainMap.needsCheck(spot, now: t0 + 2 * day))
        #expect(PainMap.needsCheck(spot, now: t0 + 3 * day))
    }

    // MARK: Forecasts

    func record(_ maxes: [(day: Double, weight: Double)]) -> LiftRecord {
        LiftRecord(exerciseID: "squat", workingWeight: 225,
                   history: maxes.map { HistoryEntry(date: t0 + $0.day * day, weight: $0.weight, reps: 1, targetHi: 5) })
    }

    @Test func goalForecastFromTheTrend() throws {
        let r = record([(0, 250), (7, 257), (14, 264), (21, 271)])
        let d = try #require(Forecast.date(r, reaching: 300, now: t0 + 21 * day))
        let days = d.timeIntervalSince(t0 + 21 * day) / day
        #expect(days > 5 && days < 30)
        #expect(Forecast.date(record([(0, 250), (7, 250), (14, 250), (21, 250)]), reaching: 300, now: t0 + 21 * day) == nil)
        #expect(Forecast.date(record([(0, 250), (7, 260)]), reaching: 300, now: t0 + 7 * day) == nil)
        #expect(Forecast.date(nil, reaching: 300, now: t0) == nil)
    }

    // MARK: Fitness age

    @Test func fitnessAgeFollowsVO2() {
        #expect(Fitness.fitnessAge(vo2: 38, age: 45) == 45)
        #expect(Fitness.fitnessAge(vo2: 41, age: 45) == 35)
        #expect(Fitness.fitnessAge(vo2: 35, age: 45) == 55)
        #expect(Fitness.fitnessAge(vo2: 38, age: 45, strengthTier: 3, recovery: 32) == 42)
        #expect(Fitness.fitnessAge(vo2: 38, age: 45, strengthTier: 0.5, recovery: 10) == 47)
        #expect(Fitness.fitnessAge(vo2: 60, age: 45) == 20)
        #expect(Fitness.fitnessAge(vo2: .nan, age: 45) == nil)
    }
}
