import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct WhoopReadinessTests {
    @Test func zonesMatchWhoop() {
        #expect(WhoopReadiness.readiness(.init(recovery: 67, fetchedAt: t0)) == .great)
        #expect(WhoopReadiness.readiness(.init(recovery: 66, fetchedAt: t0)) == .normal)
        #expect(WhoopReadiness.readiness(.init(recovery: 34, fetchedAt: t0)) == .normal)
        #expect(WhoopReadiness.readiness(.init(recovery: 33, fetchedAt: t0)) == .beat)
        #expect(WhoopReadiness.readiness(.init(fetchedAt: t0)) == nil)
    }

    @Test func summaryReadsWell() {
        let t = WhoopToday(recovery: 72, hrv: 58.4, restingHR: 54, sleepHours: 7.7, fetchedAt: t0)
        #expect(WhoopReadiness.summary(t) == "Recovery 72% · HRV 58 ms · RHR 54 · Slept 7h 42m")
    }

    @Test func redDayMentionsShortSleep() {
        let line = WhoopReadiness.coachLine(.init(recovery: 20, sleepHours: 5.2, fetchedAt: t0))!
        #expect(line.contains("Red at 20%") && line.contains("Short sleep"))
    }

    @Test func oldDataIsNotCurrent() {
        let t = WhoopToday(recovery: 70, cycleStart: t0, fetchedAt: t0)
        #expect(WhoopReadiness.isCurrent(t, now: t0.addingTimeInterval(3600)))
        #expect(!WhoopReadiness.isCurrent(t, now: t0.addingTimeInterval(7 * 3600)))
    }
}
