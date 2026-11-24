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
        // Lifts done: conditioning (the finisher) is next, then nothing.
        if let cardio = s.items.first(where: \.isCardio) {
            #expect(SessionInsights.nextOpenSet(session: s, entries: entries)?.key == cardio.key)
            for item in s.items where item.isCardio { entries[item.key] = LoggedItem(rounds: 1, ticked: true) }
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

@Suite struct RemoveSkipTests {
    func session() -> Session {
        SessionBuilder.build(slot: .A, context: SessionDraft(slot: .A, week: 1).context(runMinutes: 25))
    }

    @Test func removingSetsShrinksTodayOnly() {
        let s = session()
        let main = s.items.first { $0.kind == .main }!
        var d = SessionDraft(slot: .A, week: 1)
        d.removeSet(key: main.key, planned: main.sets)
        #expect(d.entries[main.key]!.activeSets(planned: main.sets) == main.sets - 1)
        let full = SessionInsights.stats(session: s, entries: [:]).setsPlanned
        #expect(SessionInsights.stats(session: s, entries: d.entries).setsPlanned == full - 1)
        for _ in 0..<10 { d.removeSet(key: main.key, planned: main.sets) }
        #expect(d.entries[main.key]!.activeSets(planned: main.sets) == 1)
        d.restoreSets(key: main.key)
        #expect(d.entries[main.key]!.activeSets(planned: main.sets) == main.sets)
    }

    @Test func doneSetsAreNeverRemoved() {
        var d = SessionDraft(slot: .A, week: 1)
        d.entries["x"] = LoggedItem(sets: sets(100, [5, 5]))
        d.removeSet(key: "x", planned: 2)
        #expect(d.entries["x"]!.activeSets(planned: 2) == 2)
    }

    @Test func skippedExerciseIsPassedOver() {
        let s = session()
        let main = s.items.first { $0.kind == .main }!
        var d = SessionDraft(slot: .A, week: 1)
        d.entries[main.key] = LoggedItem(sets: sets(200, [5]))
        d.skip(key: main.key, reason: "Pain")
        // The set already done is kept (and comes back with "Bring it back"), but doesn't progress.
        #expect(d.entries[main.key]!.sets.count == 1)
        #expect(Progression.progress(session: s, entries: d.entries, lifts: [:], date: t0, runMinutes: 25)
            .lifts[main.exerciseID!] == nil)
        #expect(SessionInsights.nextOpenSet(session: s, entries: d.entries)?.key != main.key)
        let lifts = Progression.applySkips(session: s, entries: d.entries, lifts: [:])
        #expect(lifts[main.exerciseID!]?.lastSkip == "Pain")
        let after = Progression.progress(session: s, entries: [main.key: LoggedItem(sets: sets(200, [5, 5, 5, 5]))],
                                         lifts: lifts, date: t0, runMinutes: 25)
        #expect(after.lifts[main.exerciseID!]?.lastSkip == nil)
    }

    @Test func markAllDoneTicksActiveSets() {
        var d = SessionDraft(slot: .A, week: 1)
        d.entries["x"] = LoggedItem(sets: [LoggedSet(weight: 95, reps: 4, ticked: true)], removedSets: 1)
        d.markAllDone(key: "x", planned: 4, weight: 100)
        let e = d.entries["x"]!
        let ticked = e.sets.prefix(3).allSatisfy { $0.ticked }
        #expect(ticked)
        #expect(e.sets[0].weight == 95 && e.sets[0].reps == 4)
        #expect(e.sets[2].weight == 100 && e.sets[2].reps == nil)
    }
}
