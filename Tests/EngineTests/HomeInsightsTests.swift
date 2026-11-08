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

@Suite struct HomeUpgradeTests {
    let now = Date(timeIntervalSince1970: 1_793_000_000)

    @Test func briefReadsLikeACoach() {
        let b = HomeInsights.brief(recovery: 78, sleepHours: 7 + 40.0 / 60, title: "Heavy Upper", mainLine: "Bench 195 × 5",
                                   isPR: true, minutes: 52, doneToday: false)
        #expect(b == "Green 78%, slept 7:40. Heavy Upper: Bench 195 × 5 is a PR. 52 min. Go.")
        #expect(HomeInsights.brief(recovery: nil, sleepHours: nil, title: "Conditioning", mainLine: nil, isPR: false,
                                   minutes: 40, doneToday: false) == "Conditioning. 40 min. Go.")
    }

    @Test func heatmapAndDaysSince() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let days = HomeInsights.trainingDays([now, now.addingTimeInterval(-2 * 86400)], now: now, days: 7, calendar: cal)
        #expect(days == [false, false, false, false, true, false, true])
        #expect(HomeInsights.daysSince([now.addingTimeInterval(-2 * 86400)], now: now, calendar: cal) == 2)
    }

    @Test func projectsTheNextPlateMilestone() throws {
        let series = (0..<6).map { (date: now.addingTimeInterval(Double($0 - 6) * 7 * 86400), e1RM: 290 + Double($0) * 4) }
        let p = try #require(HomeInsights.projection(series, now: now))
        #expect(p.target == 315)
        #expect(p.date > now && p.date < now.addingTimeInterval(60 * 86400))
        let flat = (0..<6).map { (date: now.addingTimeInterval(Double($0 - 6) * 86400), e1RM: 300.0) }
        #expect(HomeInsights.projection(flat, now: now) == nil)
    }

    @Test func finishLineCountsSessionsAndPace() throws {
        let logs = (0..<8).map { now.addingTimeInterval(-Double($0) * 3.5 * 86400) }   // 8 in 28 days
        let f = HomeInsights.finishLine(week: ProgramWeek(6), doneThisWeek: 2, perWeek: 5, recentLogDates: logs, now: now)
        #expect(f.left == 33)
        let date = try #require(f.date)
        #expect(abs(date.timeIntervalSince(now) / 86400 - 115.5) < 0.1)
    }
}

@Suite struct TrainingCalendarTests {
    @Test func weeksRunMondayToSundayNewestFirst() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "America/Chicago")!
        // Saturday Nov 7, 2026.
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 20))!
        let trained = [cal.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 7))!,   // Mon
                       cal.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 9))!,   // Sat (today)
                       cal.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 9))!]  // Wed last week
        let weeks = HomeInsights.trainingCalendar(trained, now: now, weeks: 3, calendar: cal)
        #expect(weeks.count == 3)
        #expect(cal.component(.day, from: weeks[0].start) == 2)
        #expect(weeks[0].days == [.trained, .rest, .rest, .rest, .rest, .trained, .future])
        #expect(weeks[0].count == 2 && weeks[1].count == 1 && weeks[2].count == 0)
        #expect(weeks[1].days[2] == .trained)
    }
}
