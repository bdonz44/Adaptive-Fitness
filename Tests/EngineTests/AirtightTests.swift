import Foundation
import Testing
@testable import Hybrid12Engine

/// Regression tests for the bugs found in the November 24 audit.
@Suite struct AirtightTests {
    // MARK: Import

    private func importJSON(_ state: String, sessions: String = "[]") throws -> Importer.Result {
        let json = #"{"app":"Hybrid 12","state":"# + state + #","sessions":"# + sessions + "}"
        return try Importer.parse(Data(json.utf8), timeZone: TimeZone(identifier: "UTC")!)
    }

    @Test func hugeNumbersInAnImportDontCrash() throws {
        let r = try importJSON(#"{"lifts":{"bench":{"w":"inf","hist":[{"d":"2026-10-01","w":1e999,"r":1e20,"hi":-3}]}},"cardio":{"2":1e30}}"#,
                               sessions: #"[{"date":"2026-10-01","slot":"A","entries":[{"id":"bench","sets":[{"w":185,"r":1e20}],"rounds":1e40}]}]"#)
        #expect(r.lifts["bench"]?.workingWeight == nil)
        #expect(r.lifts["bench"]?.history.first?.weight == nil)
        #expect(r.lifts["bench"]?.history.first?.reps == nil)
        #expect(r.cardioByWeek.isEmpty)
        #expect(r.logs.first?.entries["bench"]?.sets.first?.reps == nil)
    }

    @Test func oneBadFieldDoesntRejectTheWholeImport() throws {
        let r = try importJSON(#"{"lifts":{"bench":{"w":185,"hist":[{"d":"2026-10-01","w":180,"r":"5"},{"w":1},{"d":"2026-10-08","w":185,"r":5}]}},"weighIns":[{"d":"2026-10-01","lb":"200.4"},{"lb":3},"junk"],"waist":[{"d":"2026-10-01","in":"40"}]}"#)
        #expect(r.lifts["bench"]?.history.map(\.reps) == [5, 5])
        #expect(r.weighIns.map(\.pounds) == [200.4])
        #expect(r.waist.map(\.inches) == [40])
    }

    @Test func importKeepsTheFullHistoryAndTheRealStartingWeight() throws {
        let hist = (0..<20).map { i in #"{"d":"2026-09-\#(String(format: "%02d", i + 1))","w":\#(100 + i * 5),"r":5}"# }
        let r = try importJSON(#"{"lifts":{"bench":{"w":200,"hist":["# + hist.joined(separator: ",") + "]}}}")
        #expect(r.lifts["bench"]?.history.count == 20)
        #expect(r.lifts["bench"]?.firstWeight == 100)
    }

    // MARK: Numbers that can't be shown

    @Test func weightTextNeverCrashes() {
        #expect(Fmt.lb(.infinity) == "–")
        #expect(Fmt.lb(.nan) == "–")
        #expect(Fmt.lb(1e20) == "–")
        #expect(Fmt.lb(225) == "225")
        #expect(Plates.perSide(225_225_225).isEmpty)
        #expect(Plates.perSide(.infinity).isEmpty)
        #expect(Plates.perSide(235) == [45, 45, 5])
    }

    // MARK: Records

    @Test func newBestComparesWithTheWholeHistory() {
        let item = foundationMain("bench")
        let rec = LiftRecord(exerciseID: "bench", workingWeight: 185, history: [
            HistoryEntry(date: t0, weight: 225, reps: 5, targetHi: 5),
            HistoryEntry(date: t0 + day, weight: 185, reps: 5, targetHi: 5),
            HistoryEntry(date: t0 + 2 * day, weight: 185, reps: 5, targetHi: 5),
            HistoryEntry(date: t0 + 3 * day, weight: 185, reps: 5, targetHi: 5),
        ])
        #expect(HomeInsights.prChase(item: item, weight: 195, record: rec) == nil)
        #expect(HomeInsights.prChase(item: item, weight: 235, record: rec) != nil)
    }

    @Test func moreRepsAtTheSameWeightBeatsLastTimeEvenPast12() {
        #expect(Ghost.verdict(weight: 100, reps: 15, against: (100, 13)) == .beat)
        #expect(Ghost.verdict(weight: 100, reps: 13, against: (100, 15)) == .short)
        #expect(Ghost.verdict(weight: nil, reps: 20, against: (nil, 20)) == .matched)
        #expect(Ghost.verdict(weight: 105, reps: 5, against: (100, 5)) == .beat)
    }

    // MARK: Swaps

    @Test func swappingOneAccessoryNeverChangesAnother() throws {
        var d = SessionDraft(slot: .A, week: 5)
        let before = SessionBuilder.build(slot: .A, context: d.context(runMinutes: 25))
        let first = try #require(before.items.first { $0.kind == .accessory })
        d.swap(first.key, in: before)
        let after = SessionBuilder.build(slot: .A, context: d.context(runMinutes: 25))
        #expect(after.item(first.key)?.exerciseID != first.exerciseID)
        for item in before.items where item.kind == .accessory && item.key != first.key {
            #expect(after.item(item.key)?.exerciseID == item.exerciseID, "\(item.key) changed")
        }
    }

    @Test func engineAndFinisherSwapWorkAfterAProgramSwitch() throws {
        // Back on Hybrid 12 at absolute week 6, program week 1.
        let state = ProgramState(week: 6, doneSlots: [], startWeek: 6)
        for slot in Slot.allCases where slot != .R {
            var d = SessionDraft(slot: slot, state: state)
            let before = SessionBuilder.build(slot: slot, context: d.context(for: state))
            for kind in [ItemKind.engine, .finisher] {
                guard let item = before.items.first(where: { $0.kind == kind }) else { continue }
                d.swap(item.key, in: before)
                let after = SessionBuilder.build(slot: slot, context: d.context(for: state))
                #expect(after.item(item.key)?.name != item.name, "\(slot) \(kind) swap did nothing")
            }
        }
    }

    // MARK: Jumping weeks

    @Test func jumpingBackAfterASwitchNeverLandsOnAnotherProgramsWeek() {
        var s = ProgramState(week: 5)
        s = Program.switchTo(.define45, days: 3, state: s)       // Define 45 at absolute 6
        s = Program.startNextWeek(s).state                       // absolute 7
        s = Program.switchTo(.hybrid12, days: 5, state: s)       // Hybrid week 5 at absolute 8
        #expect(s.programWeek.week == 5)
        let jumped = Program.jump(toWeekInCycle: 3, state: s)
        #expect(jumped.programWeek.week == 3)
        #expect(jumped.week > s.week)
    }

    @Test func jumpingWithoutAnySwitchWorksAsBefore() {
        let jumped = Program.jump(toWeekInCycle: 3, state: ProgramState(week: 5))
        #expect(jumped.week == 3)
        #expect(jumped.programWeek.week == 3)
    }

    // MARK: Light days and gear

    @Test func plateauBreakerWaitsOutABeatUpDay() {
        var ctx = SessionDraft(slot: .A, week: 1, readiness: .beat).context(runMinutes: 25)
        let plain = SessionBuilder.build(slot: .A, context: ctx)
        let main = plain.items.first { $0.kind == .main }!
        ctx.breakers = [main.exerciseID!: 2]
        let withBreaker = SessionBuilder.build(slot: .A, context: ctx)
        #expect(withBreaker.items.first { $0.kind == .main }?.sets == main.sets)
    }

    @Test func kettlebellTiesGoToTheLighterBell() {
        let g = GearProfile.standard
        #expect(g.bell(42.5) == 35)
        #expect(g.bell(43) == 50)
        #expect(g.bell(27.5) == 20)
        #expect(g.bell(28) == 35)
    }

    @Test func noDumbbellsNeverSetsAWeightOfZero() {
        var gear = GearProfile.standard
        gear.dumbbells = []
        let item = liftItem("curl")
        let session = Session(slot: .A, title: "Test", week: ProgramWeek(1), readiness: .normal,
                              blocks: [SessionBlock(kind: .getStrong, items: [item])])
        let r = Progression.progress(session: session, entries: [item.key: LoggedItem(sets: sets(20, [12, 12, 12]))],
                                     lifts: ["curl": LiftRecord(exerciseID: "curl", workingWeight: 20)],
                                     date: t0, runMinutes: 25, gear: gear)
        #expect((r.lifts["curl"]?.workingWeight ?? 0) > 0)
    }

    // MARK: Saved workouts

    @Test func aDraftWithAnUnknownValueStillLoads() throws {
        var d = SessionDraft(slot: .B, week: 4)
        d.entries["main"] = LoggedItem(sets: sets(225, [5, 5]))
        d.entries["run"] = LoggedItem(rounds: 30, ticked: true, runRating: .solid)
        var json = try #require(String(data: JSONEncoder().encode(d), encoding: .utf8))
        json = json.replacingOccurrences(of: #""week":4"#, with: #""week":4,"program":"futureProgram","readiness":"sleepy""#)
        json = json.replacingOccurrences(of: #""solid""#, with: #""brandNew""#)
        let back = try #require(SafeJSON.decode(SessionDraft.self, Data(json.utf8)))
        #expect(back.entries["main"]?.sets.count == 2)
        #expect(back.entries["run"]?.rounds == 30)
        #expect(back.readiness == .normal)
    }

    @Test func zeroRoundsIsNotDone() {
        #expect(!LoggedItem(rounds: 0).hasCompletedWork)
        #expect(LoggedItem(rounds: 3).hasCompletedWork)
    }

    @Test func skippingKeepsDoneSetsAndBringingBackRestoresThem() {
        var d = SessionDraft(slot: .A, week: 1)
        d.entries["p0c0"] = LoggedItem(sets: [LoggedSet(weight: 50, reps: 10, ticked: true), LoggedSet(weight: 50)])
        d.skip(key: "p0c0", reason: "Pain")
        #expect(d.entries["p0c0"]?.sets.count == 1)
        d.skip(key: "p0c0", reason: nil)
        #expect(d.entries["p0c0"]?.sets.first?.reps == 10)
    }

    // MARK: Insights

    @Test func importedMidnightSessionsDontDecideTimeOfDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let midnight = cal.startOfDay(for: t0)
        // Only midnight-stamped (imported) sessions: no "morning vs evening" call can be made.
        let sessions = (0..<20).map { Insights.Session(date: midnight + Double($0) * day, score: $0 % 2 == 0 ? 1.0 : 0.9) }
        let days = (0..<21).map { Insights.Day(date: midnight + Double($0) * day, recovery: 60, sleepHours: 7) }
        let found = Insights.compute(sessions: sessions, days: days, calendar: cal)
        #expect(!found.contains { $0.id == "time" || $0.id == "late" })
    }
}
