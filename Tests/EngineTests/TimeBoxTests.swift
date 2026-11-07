import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct TimeBoxTests {
    func build(_ slot: Slot, week: Int = 1) -> Session {
        SessionBuilder.build(slot: slot, context: SessionContext(week: week))
    }

    @Test func estimateCountsSetsRestWarmUpAndRounds() {
        let item = liftItem("curl", sets: 3)          // 3 × (45 + 60) sec = 5.25 min
        let s = Session(slot: .A, title: "T", week: ProgramWeek(1), readiness: .normal,
                        blocks: [SessionBlock(kind: .buildTheLook, items: [item])])
        #expect(TimeBox.minutes(s) == 5)
        var main = foundationMain("bench")             // 4 × (45 + 0)... rest from item
        main.restSeconds = 135                         // 4 × 180 sec = 12 min, + 5 warm-up
        let m = Session(slot: .A, title: "T", week: ProgramWeek(1), readiness: .normal,
                        blocks: [SessionBlock(kind: .getStrong, items: [main])])
        #expect(TimeBox.minutes(m) == 17)
    }

    @Test func fitsWhenThereIsTime() {
        let s = build(.B)
        let f = TimeBox.fit(s, minutes: 60)
        #expect(f.trims.isEmpty)
        #expect(f.items == s.items)
        #expect(f.budget == 60)
    }

    @Test func finisherGoesFirst() {
        let f = TimeBox.fit(build(.A), minutes: 45)
        #expect(f.trims == ["finisher"])
        #expect(!f.items.contains { $0.kind == .finisher })
        #expect(TimeBox.minutes(f) <= 45)
    }

    @Test func thirdPairGoesBeforeAccessorySets() {
        let f = TimeBox.fit(build(.B, week: 5), minutes: 45)
        #expect(f.trims == ["finisher", "third pair"])
        #expect(!f.items.contains { $0.pair == 2 })
        #expect(f.items.filter { $0.pair != nil }.allSatisfy { $0.sets == 4 })
    }

    @Test func twentyMinutesKeepsTheMainLiftAtTwoSetsOrMore() throws {
        let f = TimeBox.fit(build(.A, week: 5), minutes: 20)
        #expect(f.trims == ["finisher", "third pair", "one set off each accessory", "second pair", "main lift to 2 sets"])
        let main = try #require(f.item("main"))
        #expect(main.sets == 2)
        #expect(f.items.filter { $0.kind == .accessory }.map(\.pair) == [0, 0])
        #expect(f.items.filter { $0.kind == .accessory }.allSatisfy { $0.sets == 3 })
        #expect(TimeBox.summary(f)?.contains("as short as it goes") == true)
    }

    @Test func conditioningCutsEngineRoundsToHalfAtMost() throws {
        let full = build(.C)
        let f = TimeBox.fit(full, minutes: 20)
        let before = try #require(full.item("engine")?.rounds)
        let after = try #require(f.item("engine")?.rounds)
        #expect(after < before)
        #expect(after >= (before + 1) / 2)
        #expect(f.trims.last == "\(after) engine rounds")
    }

    @Test func loggedItemsAndExtrasAreNeverTrimmed() throws {
        var d = SessionDraft(slot: .A, week: 5)
        d.addExtra("curl")
        let s = SessionBuilder.build(slot: .A, context: d.context(runMinutes: 25))
        let f = TimeBox.fit(s, minutes: 20, keep: ["finisher", "p2c0"])
        #expect(f.item("finisher") != nil)
        #expect(f.item("p2c0") != nil && f.item("p2c1") != nil)
        #expect(f.item("x-curl")?.sets == s.item("x-curl")?.sets)
        #expect(!f.trims.contains("finisher") && !f.trims.contains("third pair"))
    }

    @Test func summaryReadsPlainly() {
        let f = TimeBox.fit(build(.A), minutes: 45)
        #expect(TimeBox.summary(f) == "About \(TimeBox.minutes(f)) min. Cut to fit 45: finisher.")
        #expect(TimeBox.summary(build(.A)) == nil)
    }

    @Test func newSwitchesTakeTheirStartingValueFromOlderSaves() throws {
        let old = Data(#"{"effortProgression":false}"#.utf8)
        let s = try JSONDecoder().decode(AdaptiveSettings.self, from: old)
        #expect(s.effortProgression == false)
        #expect(s.timeBox == AdaptiveSettings.starting.timeBox)
    }
}
