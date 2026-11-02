import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct TrackingTests {
    @Test func weighInsStaySortedAndKeepTheLast120() {
        var list: [WeighIn] = []
        for i in 0..<125 {
            list = Tracking.adding(WeighIn(date: t0.addingTimeInterval(Double(i) * day), pounds: 250 - Double(i) * 0.1), to: list)
        }
        #expect(list.count == 120)
        #expect(list.first?.date == t0.addingTimeInterval(5 * day))
        let backdated = Tracking.adding(WeighIn(date: t0.addingTimeInterval(50.5 * day), pounds: 200), to: list)
        #expect(backdated.count == 120)
        #expect(backdated.map(\.date) == backdated.map(\.date).sorted())
    }

    @Test func waistKeepsTheLast60() {
        var list: [WaistEntry] = []
        for i in 0..<61 { list = Tracking.adding(WaistEntry(date: t0.addingTimeInterval(Double(i) * 7 * day), inches: 42), to: list) }
        #expect(list.count == 60)
    }

    @Test func trendAndChangeText() {
        #expect(Tracking.trend([]) == nil)
        #expect(Tracking.trend([240]) == Tracking.Trend(latest: 240, changeSinceFirst: nil))
        #expect(Tracking.trend([240, 238, 235.5])?.changeSinceFirst == -4.5)
        #expect(Tracking.changeText(-4.5, unit: "lb") == "-4.5 lb")
        #expect(Tracking.changeText(1, unit: "in") == "+1 in")
        #expect(Tracking.changeText(0.01, unit: "lb") == "no change")
    }

    @Test func waistTargetShowsUntilTwoEntries() {
        #expect(Tracking.showsWaistTarget(entryCount: 0))
        #expect(Tracking.showsWaistTarget(entryCount: 1))
        #expect(!Tracking.showsWaistTarget(entryCount: 2))
    }

    @Test func workingWeightsListMainLiftsFirstWithEstimatedMax() {
        let lifts: [String: LiftRecord] = [
            "bench": LiftRecord(exerciseID: "bench", workingWeight: 185, history: [entry(175, 5), entry(180, 5)]),
            "squat": LiftRecord(exerciseID: "squat", workingWeight: 225, history: [entry(225, 5)]),
            "kbswing": LiftRecord(exerciseID: "kbswing", workingWeight: 50, history: [entry(50, 15, targetHi: 15)]),
            "ohp": LiftRecord(exerciseID: "ohp", workingWeight: nil),
        ]
        let rows = Tracking.workingWeights(lifts: lifts)
        // squat comes before bench in the library; ohp has no stored weight.
        #expect(rows.prefix(2).map(\.id) == ["squat", "bench"])
        let bothMain = rows.prefix(2).allSatisfy { $0.isMain }
        let hasOHP = rows.contains { $0.id == "ohp" }
        #expect(bothMain)
        #expect(!hasOHP)
        // 180 × (1 + 5/30) = 210
        #expect(rows[1].estimatedMax == 210)
        #expect(rows[1].history == [175, 180])
        if let kb = rows.first(where: { $0.equipment == .kb }) {
            #expect(kb.estimatedMax == nil)
            #expect(!kb.isMain)
        }
    }
}

@Suite struct PlanTextTests {
    @Test func phaseLines() {
        #expect(PlanText.weeks(.build) == "Weeks 5-8")
        #expect(PlanText.scheme(.foundation) == "Main 4 × 5, rest 2:30 · Accessories 3 × 10-12, rest 1:15 · 2 superset pairs")
        #expect(PlanText.scheme(.define) == "Main 3 × 6, rest 1:30 · Accessories 3 × 12-15, rest 0:45 · 2 superset pairs")
    }

    @Test func cycleWeeksMarkDeloadsAndProgress() {
        let weeks = PlanText.cycleWeeks(current: 18) // cycle 2, week 6
        #expect(weeks.count == 12)
        #expect(weeks.filter(\.isDeload).map(\.wk) == [4, 8])
        #expect(weeks[4].status == .past)
        #expect(weeks[5].status == .current)
        #expect(weeks[6].status == .upcoming)
        #expect(weeks[8].phase == .define)
    }

    @Test func sessionLinesFollowWeekOrder() {
        let lines = PlanText.sessions(.build)
        #expect(lines.count == 6)
        #expect(lines[0].hasPrefix("Day 1 · Upper Physique: Incline"))
        #expect(lines[0].hasSuffix("3 superset pairs + finisher"))
        #expect(lines[1] == "Day 2 · Conditioning: Engine workout + 1 core pair")
        #expect(lines[5] == "Easy Run (optional): 25 min at a conversational pace. Never counts toward the five.")
        #expect(PlanText.sessions(.build, runMinutes: 35)[5].hasPrefix("Easy Run (optional): 35 min"))
    }
}
