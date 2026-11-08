import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct GhostTests {
    @Test func lastTimesSetsAreSavedAndCompared() throws {
        let r = finish(foundationMain("bench"), sets(185, [5, 5, 5, 4]))
        let rec = try #require(r.lifts["bench"])
        #expect(rec.lastSets?.count == 4)
        let last = try #require(Ghost.last(rec, set: 3))
        #expect(last.weight == 185 && last.reps == 4)
        #expect(Ghost.verdict(weight: 185, reps: 5, against: last) == .beat)
        #expect(Ghost.verdict(weight: 185, reps: 4, against: last) == .matched)
        #expect(Ghost.verdict(weight: 175, reps: 4, against: last) == .short)
        #expect(Ghost.text(last, unit: .reps) == "185 × 4")
    }

    @Test func oldRecordsFallBackToTheTopSet() throws {
        let rec = LiftRecord(exerciseID: "bench", history: [HistoryEntry(date: t0, weight: 180, reps: 6, targetHi: 6)])
        let last = try #require(Ghost.last(rec, set: 2))
        #expect(last.weight == 180 && last.reps == 6)
    }
}

@Suite struct LiftStatsTests {
    @Test func bestSetAndRepBests() {
        let rec = LiftRecord(exerciseID: "squat", history: [
            HistoryEntry(date: t0, weight: 225, reps: 5, targetHi: 5),
            HistoryEntry(date: t0.addingTimeInterval(86400 * 7), weight: 235, reps: 5, targetHi: 5),
            HistoryEntry(date: t0.addingTimeInterval(86400 * 14), weight: 255, reps: 3, targetHi: 3),
        ])
        let s = LiftStats(rec)
        #expect(s.sessions.count == 3)
        #expect(s.best?.weight == 255)
        #expect(s.repBests.map(\.reps) == [3, 5] && s.repBests.map(\.weight) == [255, 235])
    }
}

@Suite struct MilestoneTests {
    @Test func plateClubAndBodyweightMilestones() {
        let lifts = [
            "bench": LiftRecord(exerciseID: "bench", history: [HistoryEntry(date: t0, weight: 225, reps: 3, targetHi: 5)]),
            "squat": LiftRecord(exerciseID: "squat", history: [HistoryEntry(date: t0, weight: 315, reps: 3, targetHi: 5)]),
            "deadlift": LiftRecord(exerciseID: "deadlift", history: [HistoryEntry(date: t0, weight: 405, reps: 2, targetHi: 5)]),
        ]
        let f = Milestones.Facts(sessions: 27, bestStreak: 4, lifts: lifts,
                                 weighIns: [WeighIn(date: t0, pounds: 212), WeighIn(date: t0.addingTimeInterval(9e5), pounds: 201)],
                                 blocksFinished: 0)
        let done = Set(Milestones.all(f).filter(\.achieved).map(\.id))
        #expect(done.isSuperset(of: ["sessions-25", "streak-4", "bench-225", "squat-315", "deadlift-405", "club-1000", "lost-10"]))
        #expect(!done.contains("sessions-50") && !done.contains("bench-275") && !done.contains("lost-20") && !done.contains("block-1"))
        let new = Milestones.newlyAchieved(f, known: done.subtracting(["club-1000"]))
        #expect(new.map(\.id) == ["club-1000"])
    }
}

@Suite struct StandardsTests {
    @Test func standardsEaseWithAge() {
        #expect(StrengthStandards.ageFactor(35) == 1)
        #expect(abs(StrengthStandards.ageFactor(45) - 1.06) < 0.001)
        let at45 = StrengthStandards.weights("deadlift", bodyweight: 200, age: 45)
        let at55 = StrengthStandards.weights("deadlift", bodyweight: 200, age: 55)
        #expect(at45 == [190, 285, 375, 470, 565])
        #expect(zip(at45, at55).allSatisfy { $0 > $1 })
    }

    @Test func standingNamesTierAndNext() throws {
        let s = StrengthStandards.standing("squat", e1RM: 300, bodyweight: 200, age: 45)
        #expect(s.tier == "Intermediate" && s.next == "Advanced")
        #expect(s.nextWeight == 425)
        #expect(abs(s.ratio - 1.5) < 0.001)
        let cal = Calendar(identifier: .gregorian)
        let born = cal.date(from: DateComponents(year: 1981, month: 3, day: 15))!
        #expect(StrengthStandards.age(born: born, now: cal.date(from: DateComponents(year: 2026, month: 11, day: 8))!, calendar: cal) == 45)
    }
}
