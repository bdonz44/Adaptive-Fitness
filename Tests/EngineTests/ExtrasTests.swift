import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct ExtrasTests {
    func build(_ d: SessionDraft) -> Session {
        SessionBuilder.build(slot: d.slot, context: d.context(runMinutes: 25))
    }

    @Test func addedExercisesShowAsAnExtrasBlockBeforeTheFinisher() throws {
        var d = SessionDraft(slot: .A, week: 1)
        d.addExtra("curl")
        d.addExtra("bbrow")
        d.addExtra("curl")
        let s = build(d)
        let kinds = s.blocks.map(\.kind)
        let i = try #require(kinds.firstIndex(of: .extras))
        #expect(kinds.firstIndex(of: .burnIt).map { $0 > i } ?? true)
        let extras = s.blocks[i].items
        #expect(extras.map(\.exerciseID) == ["curl", "bbrow"])
        #expect(extras.allSatisfy { $0.isExtra && $0.isLift && $0.kind == .accessory })
        #expect(extras[0].key == "x-curl")
    }

    @Test func noExtrasNoBlock() {
        #expect(!build(SessionDraft(slot: .A, week: 1)).blocks.contains { $0.kind == .extras })
    }

    @Test func removingTakesItsLogWithIt() {
        var d = SessionDraft(slot: .A, week: 1)
        d.addExtra("curl")
        d.entries["x-curl"] = LoggedItem(sets: sets(25, [12]))
        d.removeExtra("curl")
        #expect(d.extras == nil)
        #expect(d.entries["x-curl"] == nil)
        #expect(!build(d).blocks.contains { $0.kind == .extras })
    }

    @Test func extrasProgressLikeAccessories() {
        var d = SessionDraft(slot: .A, week: 1)
        d.addExtra("curl")
        let s = build(d)
        let r = Progression.progress(session: s, entries: ["x-curl": LoggedItem(sets: sets(25, [12, 12, 12]))],
                                     lifts: [:], date: t0, runMinutes: 25)
        #expect(r.lifts["curl"]?.workingWeight == 30)
    }

    @Test func extrasCannotBeSwapped() {
        var d = SessionDraft(slot: .A, week: 1)
        d.addExtra("curl")
        #expect(SessionBuilder.swapOption(for: "x-curl", in: build(d)) == nil)
    }

    @Test func oldDraftsWithoutExtrasStillLoad() throws {
        var d = SessionDraft(slot: .B, week: 2)
        d.addExtra("curl")
        var json = try #require(String(data: JSONEncoder().encode(d), encoding: .utf8))
        json = json.replacingOccurrences(of: #","extras":["curl"]"#, with: "")
            .replacingOccurrences(of: #""extras":["curl"],"#, with: "")
        let back = try JSONDecoder().decode(SessionDraft.self, from: Data(json.utf8))
        #expect(back.extras == nil)
    }
}

@Suite struct PowerLiftTests {
    @Test func cleansAndSnatchesAreInTheLibraryButNeverInAPlan() {
        let c = Catalog.bundled
        for id in ["powerclean", "hangclean", "powersnatch", "hangsnatch", "dbhangclean", "dbsnatch", "kbclean", "kbsnatch"] {
            #expect(c.exercise(id)?.category == Catalog.powerCategory)
        }
        for w in 1...12 {
            for slot in Program.order {
                let s = SessionBuilder.build(slot: slot, context: SessionContext(week: w))
                #expect(!s.items.contains { c.exercise($0.exerciseID ?? "")?.category == Catalog.powerCategory })
            }
        }
    }

    @Test func addedPowerLiftsGetLowRepsAndLongRest() throws {
        var d = SessionDraft(slot: .A, week: 1)
        d.addExtra("powerclean")
        let item = try #require(SessionBuilder.build(slot: .A, context: d.context(runMinutes: 25)).item("x-powerclean"))
        #expect(item.low == 3 && item.high == 5)
        #expect(item.restSeconds == 120)
    }
}

@Suite struct TRXTests {
    let c = Catalog.bundled

    @Test func trxMovesAreBodyweightAndNeverInAPlan() {
        let trx = c.accessories.filter { $0.category == Catalog.trxCategory }
        #expect(trx.count == 29)
        #expect(trx.allSatisfy { $0.eq == .bw && $0.name.hasPrefix("TRX") })
        for w in 1...12 {
            for slot in Program.order {
                let s = SessionBuilder.build(slot: slot, context: SessionContext(week: w))
                #expect(!s.items.contains { c.exercise($0.exerciseID ?? "")?.category == Catalog.trxCategory })
            }
        }
    }

    @Test func topOfRangeSaysWalkYourFeetIn() {
        let r = finish(liftItem("trxrow"), sets(nil, [12, 12, 12]))
        #expect(r.lifts["trxrow"]?.note == Progression.trxHarderNote)
        let plank = finish(liftItem("trxplank", low: 30, high: 45), sets(nil, [45, 45, 45]))
        #expect(plank.lifts["trxplank"]?.note == "Harder: add 10 to 15 seconds.")
    }
}

@Suite struct ManyExtrasTests {
    @Test func severalAddedAtOnceKeepThePickedOrder() {
        var d = SessionDraft(slot: .D, week: 1)
        for id in ["trxrow", "powerclean", "curl", "trxrow"] { d.addExtra(id) }
        let s = SessionBuilder.build(slot: .D, context: d.context(runMinutes: 25))
        #expect(s.blocks.first { $0.kind == .extras }?.items.map(\.exerciseID) == ["trxrow", "powerclean", "curl"])
    }
}

@Suite struct AbsTests {
    let c = Catalog.bundled

    @Test func absAndTrxAdditionsExist() {
        #expect(c.accessories(in: Catalog.absCategory).count == 16)
        #expect(c.exercise("trxchestfly")?.name == "TRX Chest Fly")
        #expect(c.exercise("trxchestfly")?.category == Catalog.trxCategory)
    }

    @Test func hybridCoreRotationIsUnchanged() {
        // Abs never rotate into Hybrid 12; the core list is the same six as before.
        #expect(c.accessories(in: "core").map(\.id) == ["plank", "deadbug", "hollow", "sideplank", "suitcase", "bearcrawl"])
        for w in 1...12 {
            for slot in Program.order {
                let s = SessionBuilder.build(slot: slot, context: SessionContext(week: w))
                #expect(!s.items.contains { c.exercise($0.exerciseID ?? "")?.category == Catalog.absCategory })
            }
        }
    }

    @Test func swappingACoreMoveReachesTheAbsList() throws {
        var d = SessionDraft(slot: .C, week: 1)
        var seen = Set<String>()
        for _ in 0..<30 {
            let s = SessionBuilder.build(slot: .C, context: d.context(runMinutes: 25))
            let key = try #require(s.items.first { $0.kind == .accessory && $0.pair == 0 }?.key)
            seen.insert(s.item(key)?.exerciseID ?? "")
            d.swap(key, in: s)
        }
        #expect(seen.contains { c.exercise($0)?.category == Catalog.absCategory })
    }
}

@Suite struct HowToTests {
    @Test func everyExerciseHasAHowTo() {
        let c = Catalog.bundled
        for e in c.mainLifts + c.accessories {
            let h = c.howTo(e.id)
            #expect(h != nil, "\(e.id) has no how-to")
            #expect(!(h?.setup.isEmpty ?? true) && !(h?.movement.isEmpty ?? true) && !(h?.mistake.isEmpty ?? true))
        }
    }

    @Test func formVideoSearch() {
        let url = Catalog.formVideoURL(for: "TRX Chest Fly")?.absoluteString ?? ""
        #expect(url == "https://www.youtube.com/results?search_query=TRX%20Chest%20Fly%20proper%20form%20how%20to")
    }
}
