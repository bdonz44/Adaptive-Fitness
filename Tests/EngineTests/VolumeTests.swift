import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct VolumeTests {
    @Test func countsDoneSetsWithWeight() {
        var entries: [String: LoggedItem] = [
            "main": LoggedItem(sets: [LoggedSet(weight: 225, reps: 5, ticked: true), LoggedSet(weight: 225, ticked: true),
                                      LoggedSet(weight: 225)]),                       // last set not done
            "p0c0": LoggedItem(sets: [LoggedSet(weight: nil, reps: 12, ticked: true)]),   // bodyweight: no pounds
            "p0c1": LoggedItem(sets: [LoggedSet(weight: 30, reps: 10, ticked: true)], skipped: "Pain"),
        ]
        SessionHeart.write(nil, into: &entries)
        // 225×5 + 225×(top reps 5) = 2,250; skipped and bodyweight sets don't count.
        #expect(Volume.of(entries: entries, highFor: { $0 == "main" ? 5 : nil }) == 2250)
        #expect(Volume.of(entries: entries) == 225 * 5 + 225 * 8)
    }

    @Test func absurdNumbersAreIgnored() {
        let e = ["x": LoggedItem(sets: [LoggedSet(weight: .infinity, reps: 5, ticked: true), LoggedSet(weight: 100, reps: 5000, ticked: true)])]
        #expect(Volume.of(entries: e) == 0)
    }

    @Test func weeklyTotals() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = t0
        let weeks = Volume.byWeek([(date: now, pounds: 1000), (date: now - 8 * day, pounds: 500)], now: now, weeks: 3, calendar: cal)
        #expect(weeks.count == 3)
        #expect(weeks.last?.pounds == 1000)
        #expect(weeks.map(\.pounds).reduce(0, +) == 1500)
    }

    @Test func shortAndComparison() {
        #expect(Volume.short(950) == "950")
        #expect(Volume.short(8_640) == "8.6k")
        #expect(Volume.short(86_400) == "86k")
        #expect(Volume.short(1_234_567) == "1.2M")
        #expect(Volume.comparison(500) == nil)
        #expect(Volume.comparison(1_000) == "That's a grand piano.")
        #expect(Volume.comparison(1_215_000) == "That's 2.7 Statues of Liberty.")
    }
}
