import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct WeeklyReviewTests {
    let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Chicago")!; return c }()
    let now = Date(timeIntervalSince1970: 1_793_000_000)
    func ago(_ d: Double) -> Date { now.addingTimeInterval(-d * 86400) }

    @Test func sumsTheWeek() throws {
        var heart = SessionHeart(live: HeartRate.Summary(zoneSeconds: [0, 0, 0, 0, 900, 300], average: 130, peak: 170))
        heart.strain = 12
        let logs = [
            WeeklyReview.Log(date: ago(1), title: "Heavy Upper", cardioMinutes: 10, heart: heart),
            WeeklyReview.Log(date: ago(3), title: "Conditioning", cardioMinutes: 30, heart: heart),
            WeeklyReview.Log(date: ago(4), title: "Easy Run", cardioMinutes: 25, heart: nil, counts: false),
            WeeklyReview.Log(date: ago(9), title: "Old", cardioMinutes: 60, heart: heart),
        ]
        let bench = LiftRecord(exerciseID: "bench", workingWeight: 195, history: [
            HistoryEntry(date: ago(8), weight: 185, reps: 5, targetHi: 5),
            HistoryEntry(date: ago(1), weight: 190, reps: 5, targetHi: 5),
        ])
        let r = WeeklyReview.build(now: now, logs: logs, lifts: ["bench": bench],
                                   weighIns: [WeighIn(date: ago(10), pounds: 200), WeighIn(date: ago(2), pounds: 198.5)],
                                   waist: [WaistEntry(date: ago(2), inches: 36)],
                                   state: ProgramState(week: 3, doneSlots: ["B"]), calendar: cal)
        #expect(r.sessions.map(\.title) == ["Conditioning", "Heavy Upper"])
        #expect(r.cardioMinutes == 65)
        #expect(r.hardMinutes == 40)
        #expect(r.strain == 24)
        #expect(r.liftsUp == [.init(name: "Bench Press", from: 185, to: 190)])
        #expect(r.records.map(\.name) == ["Bench Press"])
        #expect(r.weightChange == -1.5 && r.latestWeight == 198.5)
        #expect(r.waistChange == 0)
        #expect(r.verdict == "3 sessions short. This week, every one gets done.")
        #expect(r.nextWeek.hasPrefix("Hybrid 12 · Week 3 of 12 · Foundation. Still to do: Conditioning"))
    }

    @Test func fullWeekGetsTheGoodVerdict() {
        let logs = (0..<5).map { WeeklyReview.Log(date: ago(Double($0)), title: "S\($0)", cardioMinutes: 0, heart: nil) }
        let r = WeeklyReview.build(now: now, logs: logs, lifts: [:], weighIns: [], waist: [], state: ProgramState(week: 2), calendar: cal)
        #expect(r.verdict.hasPrefix("Every session done"))
        #expect(r.strain == nil && r.weightChange == nil)
    }
}
