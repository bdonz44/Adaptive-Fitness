import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct RoundTimerTests {
    func item(_ slot: Slot, key: String, week: Int = 1) -> SessionItem? {
        SessionBuilder.build(slot: slot, context: SessionDraft(slot: slot, week: week).context(runMinutes: 25)).item(key)
    }

    @Test func bagRoundsUseTheirWorkAndRest() {
        let all = Catalog.bundled.engineWorkouts
        let i = all.firstIndex { $0.name == "Heavy Bag Rounds" }!
        var ctx = SessionDraft(slot: .C, week: 1).context(runMinutes: 25)
        ctx.condSwap = i
        let bag = SessionBuilder.build(slot: .C, context: ctx).item("engine")!
        let s = RoundPlan.defaults(for: bag)
        #expect(s.work == 120 && s.rest == 60 && s.rounds == 8)
        #expect(RoundPlan.summary(s) == "2:00 on · 1:00 off · 8 rounds · 23 min")
    }

    @Test func noRestAfterTheLastRound() {
        let p = RoundPlan.phases(.init(rounds: 3, work: 60, rest: 30))
        #expect(p.map(\.kind) == [.getReady, .work, .rest, .work, .rest, .work])
        #expect(RoundPlan.phaseStarts(p) == [0, 10, 70, 100, 160, 190])
    }

    @Test func positionCountsFinishedRounds() {
        let p = RoundPlan.phases(.init(rounds: 3, work: 60, rest: 30))
        #expect(RoundPlan.position(p, elapsed: 5) == .init(phase: 0, remaining: 5, roundsDone: 0))
        #expect(RoundPlan.position(p, elapsed: 75) == .init(phase: 2, remaining: 25, roundsDone: 1))
        #expect(RoundPlan.position(p, elapsed: 400).finished)
        #expect(RoundPlan.position(p, elapsed: 400).roundsDone == 3)
    }

    @Test func emomLogsMinutes() {
        let s = RoundPlan.Settings(rounds: 10, work: 60, rest: 0)
        #expect(RoundPlan.phases(s).count == 11)
        #expect(RoundPlan.logged(roundsDone: 10, settings: s, unit: .min) == 10)
        #expect(RoundPlan.logged(roundsDone: 4, settings: .init(rounds: 6, work: 60, rest: 30), unit: .rounds) == 4)
    }

    @Test func settingsNeverGoBelowLimits() {
        let s = RoundPlan.Settings(rounds: 0, work: 1, rest: -5)
        #expect(s.rounds == 1 && s.work == 5 && s.rest == 0)
    }
}

@Suite struct RoundTimerRestTests {
    /// A workout that says "Rest N sec" must rest N sec between rounds in the timer.
    @Test func statedRestIsInTheTimer() throws {
        let c = Catalog.bundled
        let texts = c.engineWorkouts.map { ($0.name, $0.description, $0.rest) }
            + c.finishers.map { ($0.name, $0.description, $0.rest) }
        let pattern = try Regex(#"[Rr]est (\d+) sec"#)
        for (name, text, rest) in texts {
            guard let m = text.firstMatch(of: pattern), let n = Int(m.output[1].substring ?? "") else { continue }
            #expect(rest == n, "\(name) says rest \(n) sec but the timer rests \(rest.map(String.init) ?? "0")")
        }
    }

    @Test func dumbbellGrinderRests60BetweenRounds() throws {
        let i = try #require(Catalog.bundled.engineWorkouts.firstIndex { $0.name == "Dumbbell Grinder" })
        var ctx = SessionDraft(slot: .C, week: 1).context(runMinutes: 25)
        ctx.condSwap = i
        let item = try #require(SessionBuilder.build(slot: .C, context: ctx).item("engine"))
        let s = RoundPlan.defaults(for: item)
        #expect(s.work == 120 && s.rest == 60)
        #expect(RoundPlan.phases(s).contains { $0.kind == .rest && $0.seconds == 60 })
    }

    @Test func programCircuitsWithRestStatedAlsoRest() {
        for id in ProgramID.allCases where id != .hybrid12 {
            for d in id.dayOptions {
                let st = ProgramState(program: id, days: d)
                for slot in st.order {
                    let s = SessionBuilder.build(slot: slot, context: SessionDraft(slot: slot, state: st).context(for: st))
                    for item in s.items where item.isCardio && item.detail.contains("Rest ") && item.detail.contains(" sec between") {
                        #expect((item.intervalRest ?? 0) > 0, "\(item.name)")
                    }
                }
            }
        }
    }
}

@Suite struct EveryTimerHasRestTests {
    /// Every timed workout has its work and rest set (EMOMs rest inside the minute).
    @Test func everyEngineWorkoutAndFinisherIsTimed() {
        let c = Catalog.bundled
        for w in c.engineWorkouts {
            #expect(w.work != nil, "\(w.name) has no timer settings")
            #expect((w.rest ?? 0) > 0, "\(w.name) has no rest")
        }
        for f in c.finishers {
            #expect(f.work != nil, "\(f.name) has no timer settings")
            #expect((f.rest ?? 0) > 0 || f.description.contains("Every minute"), "\(f.name) has no rest")
        }
        for id in ProgramID.allCases where id != .hybrid12 {
            for d in id.dayOptions {
                for day in ProgramLibrary.days(id, days: d) {
                    for c in [day.engine, day.finisher].compactMap({ $0 }) where c.unit != .min {
                        #expect(c.work != nil, "\(c.name) has no timer settings")
                        #expect((c.rest ?? 0) > 0 || c.details[0].contains("Every minute"), "\(c.name) has no rest")
                    }
                }
            }
        }
    }
}
