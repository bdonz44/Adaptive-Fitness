import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct SessionInsightsTests {
    @Test func platesPerSide() {
        #expect(Plates.perSide(235) == [45, 45, 5])
        #expect(Plates.perSide(135) == [45])
        #expect(Plates.perSide(150) == [45, 5, 2.5])
        #expect(Plates.perSide(45).isEmpty)
        #expect(Plates.text(45) == "Empty bar")
        #expect(Plates.text(185) == "45 + 25")
    }

    func session(_ slot: Slot = .A) -> Session {
        SessionBuilder.build(slot: slot, context: SessionDraft(slot: slot, week: 1).context(runMinutes: 25))
    }

    @Test func nextSetStartsWithTheMainLift() {
        let s = session()
        let main = s.items.first { $0.kind == .main }!
        #expect(SessionInsights.nextOpenSet(session: s, entries: [:]) == .init(key: main.key, set: 0))
        let oneDone = [main.key: LoggedItem(sets: sets(235, [5]))]
        #expect(SessionInsights.nextOpenSet(session: s, entries: oneDone) == .init(key: main.key, set: 1))
    }

    @Test func supersetPartnersAlternate() {
        let s = session()
        let main = s.items.first { $0.kind == .main }!
        let pair = s.items.filter { $0.pair == 0 }
        try? #require(pair.count == 2)
        var entries = [main.key: LoggedItem(sets: sets(235, Array(repeating: 5, count: main.sets)))]
        #expect(SessionInsights.nextOpenSet(session: s, entries: entries)?.key == pair[0].key)
        entries[pair[0].key] = LoggedItem(sets: sets(100, [10]))
        #expect(SessionInsights.nextOpenSet(session: s, entries: entries) == .init(key: pair[1].key, set: 0))
        entries[pair[1].key] = LoggedItem(sets: sets(nil, [12]))
        #expect(SessionInsights.nextOpenSet(session: s, entries: entries) == .init(key: pair[0].key, set: 1))
    }

    @Test func allDoneMeansNoNextSet() {
        let s = session()
        var entries: [String: LoggedItem] = [:]
        for item in s.items where item.isLift {
            entries[item.key] = LoggedItem(sets: sets(50, Array(repeating: 8, count: item.sets)))
        }
        #expect(SessionInsights.nextOpenSet(session: s, entries: entries) == nil)
    }

    @Test func statsCountDoneSetsAndVolume() {
        let s = session()
        let main = s.items.first { $0.kind == .main }!
        let st = SessionInsights.stats(session: s, entries: [main.key: LoggedItem(sets: sets(200, [5, 5]))])
        #expect(st.setsDone == 2)
        #expect(st.volume == 2000)
        #expect(st.setsPlanned == s.items.filter(\.isLift).map(\.sets).reduce(0, +))
    }

    @Test func recordsBeatEveryEarlierEstimate() {
        let today = t0
        var squat = LiftRecord(exerciseID: "squat")
        squat.history = [entry(225, 5, daysAgo: 14), entry(230, 5, daysAgo: 7),
                         HistoryEntry(date: today, weight: 235, reps: 5, targetHi: 5)]
        var bench = LiftRecord(exerciseID: "bench")
        bench.history = [entry(185, 5, daysAgo: 7), HistoryEntry(date: today, weight: 180, reps: 5, targetHi: 5)]
        var first = LiftRecord(exerciseID: "ohp")
        first.history = [HistoryEntry(date: today, weight: 95, reps: 5, targetHi: 5)]
        let recs = SessionInsights.records(lifts: ["squat": squat, "bench": bench, "ohp": first], date: today)
        #expect(recs.map(\.exerciseID) == ["squat"])
        #expect(abs(recs[0].gain - 5 * (1 + 5.0 / 30)) < 0.001)
    }
}
