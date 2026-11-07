import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct HomeInsightsTests {
    @Test func streakCountsFullWeeksBackFromLastWeek() {
        var logged: [(slot: String, week: Int)] = []
        for w in 2...4 { for s in ["A", "B", "C", "D", "E"] { logged.append((s, w)) } }
        logged.append(("A", 1))                      // week 1 incomplete
        logged.append(("R", 4))                      // runs don't count
        logged += [("A", 5), ("B", 5)]               // current week in progress
        #expect(HomeInsights.streak(logged: logged, currentWeek: 5, sessionsPerWeek: 5) == 3)
        #expect(HomeInsights.streak(logged: logged, currentWeek: 2, sessionsPerWeek: 5) == 0)
    }

    @Test func prChaseOnlyWhenItBeatsYourBest() {
        let item = foundationMain("bench")
        let rec = LiftRecord(exerciseID: "bench", workingWeight: 195,
                             history: [HistoryEntry(date: t0, weight: 190, reps: 5, targetHi: 5)])
        #expect(HomeInsights.prChase(item: item, weight: 195, record: rec) == "Bench Press 195 × 5 would be a new best.")
        #expect(HomeInsights.prChase(item: item, weight: 185, record: rec) == nil)
        #expect(HomeInsights.prChase(item: item, weight: 195, record: nil) == nil)
    }

    @Test func sinceStartShowsTheBiggestGains() {
        let lifts = ["squat": LiftRecord(exerciseID: "squat", workingWeight: 245, firstWeight: 205),
                     "bench": LiftRecord(exerciseID: "bench", workingWeight: 195, firstWeight: 185)]
        let lines = HomeInsights.sinceStart(lifts: lifts,
                                            weighIns: [WeighIn(date: t0, pounds: 212), WeighIn(date: t0.addingTimeInterval(86400 * 40), pounds: 201)],
                                            waist: [WaistEntry(date: t0, inches: 38)])
        #expect(lines == ["+40 lb back squat", "-11 lb bodyweight"])
    }

    @Test func lineOfTheDayRotatesAndDoneTodayWins() {
        let f = HomeInsights.Facts(cardioMinutes: 85, cardioGoal: 120, sessionsDone: 3, sessionsPerWeek: 5, streak: 4,
                                   liftsUpLately: ["Back Squat"], hardMinutes: 34, isDeload: false, doneToday: false)
        let lines = HomeInsights.coachLines(f)
        #expect(lines.count == 5)
        #expect(lines.contains("Cardio is 35 minutes short. Get a walk in today."))
        let cal = Calendar(identifier: .gregorian)
        let a = HomeInsights.lineOfTheDay(f, date: t0, calendar: cal)
        let b = HomeInsights.lineOfTheDay(f, date: t0.addingTimeInterval(86400), calendar: cal)
        #expect(a != b)
        var done = f
        done.doneToday = true
        #expect(HomeInsights.lineOfTheDay(done, date: t0).hasPrefix("Work's done today"))
    }
}
