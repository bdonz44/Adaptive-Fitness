import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct FlowTests {
    func done(_ n: Int, _ w: Double? = 50) -> LoggedItem { LoggedItem(sets: Array(repeating: LoggedSet(weight: w, reps: 10, ticked: true), count: n)) }

    @Test func conditioningFirstWhenTheSessionStartsWithIt() throws {
        // Hybrid 12 Conditioning: Engine block, then the core pair.
        let s = SessionBuilder.build(slot: .C, context: SessionContext(week: 1))
        #expect(s.blocks.first?.kind == .engine)
        let first = try #require(SessionInsights.nextOpenSet(session: s, entries: [:]))
        #expect(first.key == "engine")
        let next = try #require(SessionInsights.nextOpenSet(session: s, entries: ["engine": LoggedItem(rounds: 5, ticked: true)],
                                                            after: "engine"))
        #expect(next.key == "p0c0" && next.set == 0)
    }

    @Test func liftsThenConditioningInProgramOrder() throws {
        let st = ProgramState(program: .engineStrength, days: 4)
        let s = SessionBuilder.build(slot: .A, context: SessionDraft(slot: .A, state: st).context(for: st))
        var entries: [String: LoggedItem] = [:]
        var order: [String] = []
        var last: String? = nil
        while let o = SessionInsights.nextOpenSet(session: s, entries: entries, after: last), order.count < 40 {
            order.append("\(o.key)#\(o.set)")
            let item = try #require(s.item(o.key))
            if item.isCardio {
                entries[o.key] = LoggedItem(rounds: 4, ticked: true)
            } else {
                var e = entries[o.key] ?? LoggedItem()
                e.ensureSets(item.sets)
                e.sets[o.set].ticked = true
                e.sets[o.set].reps = item.high
                entries[o.key] = e
            }
            last = o.key
        }
        #expect(order.first == "main#0")
        #expect(order.last == "engine#0")
        // Superset partners alternate.
        let pair = order.filter { $0.hasPrefix("p0") }
        #expect(pair.prefix(4) == ["p0c0#0", "p0c1#0", "p0c0#1", "p0c1#1"])
    }

    @Test func carriesOnFromWhereYouAreThenCirclesBack() throws {
        let s = SessionBuilder.build(slot: .B, context: SessionContext(week: 1))   // main, two pairs, finisher
        // Jumped ahead: did the second pair's first round before touching the main lift.
        var entries: [String: LoggedItem] = [:]
        var b = LoggedItem(); b.ensureSets(3); b.sets[0].ticked = true; b.sets[0].reps = 12
        entries["p1c0"] = b
        let next = try #require(SessionInsights.nextOpenSet(session: s, entries: entries, after: "p1c0"))
        #expect(next.key == "p1c1" && next.set == 0)   // stays in that superset
        // Finish everything after the main lift: it comes back to the main lift last.
        for item in s.items where item.key != "main" {
            entries[item.key] = item.isCardio ? LoggedItem(rounds: 1, ticked: true) : done(item.sets)
        }
        let back = try #require(SessionInsights.nextOpenSet(session: s, entries: entries, after: "finisher"))
        #expect(back.key == "main" && back.set == 0)
    }

    @Test func skippedConditioningIsPassedOver() {
        let s = SessionBuilder.build(slot: .C, context: SessionContext(week: 1))
        let next = SessionInsights.nextOpenSet(session: s, entries: ["engine": LoggedItem(skipped: "No time")])
        #expect(next?.key == "p0c0")
    }
}
