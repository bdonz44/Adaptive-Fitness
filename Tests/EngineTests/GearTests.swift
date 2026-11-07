import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct GearTests {
    @Test func standardGearKeepsTheOldNumbers() {
        let g = GearProfile.standard
        #expect(g.bell(30) == 35 && g.bell(43) == 50 && g.bell(26) == 20)
        #expect(g.nextBell(after: 20) == 35 && g.nextBell(after: 50) == 20)
        #expect(g.dumbbell(42) == 35 && g.dumbbell(2) == 5 && g.dumbbell(23) == 25)
        #expect(g.barbellWeight(187) == 185 && g.barbellWeight(30) == 45)
    }

    @Test func snapsToWhatYouOwn() {
        let g = GearProfile(barbellMax: 225, smallestPlate: 5, dumbbells: [10, 20, 30, 50], kettlebells: [26, 35, 53])
        #expect(g.barbellWeight(193) == 190 && g.barbellWeight(196) == 200 && g.barbellWeight(260) == 225)
        #expect(g.dumbbell(42) == 50 && g.dumbbell(38) == 30)
        #expect(g.nextBell(after: 35) == 53 && g.nextBell(after: 53) == 26)
        #expect(Suggestions.clamp(42, equipment: .db, gear: g) == 50)
    }

    @Test func kettlebellProgressionUsesYourBells() {
        let g = GearProfile(kettlebells: [26, 35, 53])
        var rec = LiftRecord(exerciseID: "kbswing", workingWeight: 35)
        let reading = SetReading(usedWeight: 35, topReps: 15, hitAll: true, miss: false, countedSets: 3)
        _ = Progression.kettlebell(&rec, id: "kbswing", used: 35, reading: reading, gear: g)
        #expect(rec.workingWeight == 53)
        var top = LiftRecord(exerciseID: "kbswing", workingWeight: 53)
        let note = Progression.kettlebell(&top, id: "kbswing", used: 53, reading: reading, gear: g)
        #expect(top.workingWeight == 53 && note?.hasPrefix("Heaviest bell") == true)
    }

    @Test func coachStepsStopAtYourHeaviestDumbbell() {
        let row = liftItem("dbrow")
        let atMax = CoachCues.afterSet(item: row, reps: 12, weight: 35, effort: .easy, setsLeft: 2, lightDay: false)
        #expect(atMax.newWeight == nil && atMax.text.contains("3-second lowering"))
        let mid = CoachCues.afterSet(item: row, reps: 12, weight: 25, effort: .easy, setsLeft: 2, lightDay: false)
        #expect(mid.newWeight == 30)
        let drop = CoachCues.afterSet(item: row, reps: 6, weight: 25, effort: .grind, setsLeft: 1, lightDay: false)
        #expect(drop.newWeight == 20)
    }

    @Test func missingGearIsSwappedForSomethingYouCanDo() throws {
        let noBench = GearProfile(bench: false)
        var ctx = SessionContext(week: 1)
        ctx.gear = noBench
        let s = SessionBuilder.build(slot: .D, context: ctx)   // Heavy Upper: bench
        let main = try #require(s.item("main"))
        #expect(main.exerciseID == "floorpress")
        for item in s.items where item.isLift {
            #expect(noBench.has(Catalog.bundled.exercise(item.exerciseID!)!), "\(item.name)")
        }
        // No barbell at all: every lift still has something you can do.
        var bare = SessionContext(week: 5)
        bare.gear = GearProfile(barbell: false)
        for slot in Program.order {
            for item in SessionBuilder.build(slot: slot, context: bare).items where item.isLift {
                #expect(Catalog.bundled.exercise(item.exerciseID!)!.eq != .bb, "\(slot) \(item.name)")
            }
        }
    }

    @Test func pullUpsOnlyWithABar() throws {
        let pull = try #require(Catalog.bundled.exercise("pullup"))
        #expect(!GearProfile.standard.has(pull))
        #expect(GearProfile(pullupBar: true).has(pull))
    }

    @Test func olderSavedGearFillsInNewFields() throws {
        let g = try JSONDecoder().decode(GearProfile.self, from: Data(#"{"kettlebells":[35]}"#.utf8))
        #expect(g.kettlebells == [35] && g.dumbbells == GearProfile.standard.dumbbells && g.bench)
    }
}
