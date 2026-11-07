import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct ReEntryTests {
    let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Chicago")!; return c }()
    let now = Date(timeIntervalSince1970: 1_793_000_000)
    func ago(_ days: Int) -> Date { cal.date(byAdding: .day, value: -days, to: now)! }

    @Test func underAWeekIsNormal() {
        #expect(ReEntry.plan(logDates: [ago(6), ago(8)], now: now, calendar: cal) == nil)
        #expect(ReEntry.plan(logDates: [], now: now, calendar: cal) == nil)
    }

    @Test func oneToTwoWeeksIsOneLighterSession() throws {
        let p = try #require(ReEntry.plan(logDates: [ago(10)], now: now, calendar: cal))
        #expect(p.factor == 0.9 && p.sessionsLeft == 1 && !p.restartWeek && !p.offerPhaseRestart)
        // After that session, back to normal.
        #expect(ReEntry.plan(logDates: [ago(0), ago(10)], now: now, calendar: cal) == nil)
    }

    @Test func twoToFourWeeksIsTwoSessionsAndTheWeekRestarts() throws {
        let first = try #require(ReEntry.plan(logDates: [ago(16), ago(18)], now: now, calendar: cal))
        #expect(first.factor == 0.85 && first.sessionsLeft == 2 && first.restartWeek && !first.offerPhaseRestart)
        let second = try #require(ReEntry.plan(logDates: [ago(1), ago(17)], now: now, calendar: cal))
        #expect(second.factor == 0.85 && second.sessionsLeft == 1 && !second.restartWeek)
        #expect(ReEntry.message(second).hasPrefix("Second session back."))
        #expect(ReEntry.plan(logDates: [ago(0), ago(1), ago(17)], now: now, calendar: cal) == nil)
    }

    @Test func fourWeeksPlusOffersAPhaseRestart() throws {
        let p = try #require(ReEntry.plan(logDates: [ago(35)], now: now, calendar: cal))
        #expect(p.factor == 0.8 && p.restartWeek && p.offerPhaseRestart && p.daysOff == 35)
        #expect(ReEntry.message(p) == "35 days off. Today runs at 80% with no weight increases (this session and the next). The week starts over from Day 1. Earn it back.")
    }

    @Test func reEntryLightensWeightsAndHoldsProgression() throws {
        let item = foundationMain("bench")
        let lifts = ["bench": LiftRecord(exerciseID: "bench", workingWeight: 200,
                                         history: [HistoryEntry(date: t0, weight: 200, reps: 5, targetHi: 5)])]
        var session = Session(slot: .A, title: "T", week: ProgramWeek(1), readiness: .normal,
                              blocks: [SessionBlock(kind: .getStrong, items: [item])])
        session.reEntry = ReEntry.plan(logDates: [ago(20)], now: now, calendar: cal)
        #expect(session.isLightDay && session.lightenFactor == 0.85)
        let s = Suggestions.suggest(item: item, lifts: lifts, lightenToday: session.isLightDay,
                                    lightenFactor: session.lightenFactor, lightenNote: session.lightenNote)
        #expect(s.weight == 170)
        #expect(s.reason.hasSuffix("85% after 20 days off."))
        let r = Progression.progress(session: session, entries: [item.key: LoggedItem(sets: sets(170, [5, 5, 5, 5]))],
                                     lifts: lifts, date: t0, runMinutes: 25)
        #expect(r.lifts["bench"]?.workingWeight == 200)   // no progression on a re-entry day
    }

    @Test func olderSavedSettingsTurnReEntryOn() throws {
        let s = try JSONDecoder().decode(AdaptiveSettings.self, from: Data(#"{"effortProgression":true,"timeBox":false}"#.utf8))
        #expect(s.reEntry && !s.timeBox)
    }
}
