import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct InsightsTests {
    var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Chicago")!; return c }
    func at(_ day: Int, _ hour: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))! }

    @Test func sessionScoresAreAgainstYourPreviousBest() {
        let rec = LiftRecord(exerciseID: "bench", history: [
            HistoryEntry(date: at(1, 8), weight: 200, reps: 5, targetHi: 5),
            HistoryEntry(date: at(3, 8), weight: 210, reps: 5, targetHi: 5),
            HistoryEntry(date: at(5, 8), weight: 200, reps: 5, targetHi: 5),
        ])
        let s = Insights.sessions(["bench": rec], calendar: cal)
        #expect(s.count == 2)
        #expect(abs(s[0].score - 1.05) < 0.001 && abs(s[1].score - 200.0 / 210) < 0.001)
    }

    @Test func findsTheGreenDaySleepAndMorningPatterns() {
        var sessions: [Insights.Session] = []
        var days: [Insights.Day] = []
        for d in 1...12 {
            let good = d % 2 == 0
            sessions.append(.init(date: at(d, good ? 7 : 19), score: good ? 1.04 : 0.96))
            days.append(.init(date: cal.startOfDay(for: at(d, 0)), recovery: good ? 80 : 45, sleepHours: good ? 8 : 6.5))
        }
        let found = Insights.compute(sessions: sessions, days: days, calendar: cal)
        let ids = found.map(\.id)
        #expect(ids.contains("recovery") && ids.contains("sleep") && ids.contains("pr-sleep") && ids.contains("time"))
        #expect(found.first { $0.id == "recovery" }?.headline == "Green days: you lift 8% stronger")
        #expect(found.first { $0.id == "time" }?.headline == "You're stronger in the morning")
    }

    @Test func notEnoughDataSaysNothing() {
        let s = [Insights.Session(date: at(1, 8), score: 1.0)]
        #expect(Insights.compute(sessions: s, days: [], calendar: cal).isEmpty)
    }
}
