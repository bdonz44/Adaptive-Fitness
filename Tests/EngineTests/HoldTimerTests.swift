import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct HoldTimerTests {
    @Test func plankIsCountInThenHold() {
        let p = HoldPlan.phases(seconds: 45, eachSide: false)
        #expect(p.map(\.kind) == [.countIn, .hold])
        #expect(p.map(\.seconds) == [3, 45])
    }

    @Test func sidePlankDoesBothSides() {
        let p = HoldPlan.phases(seconds: 30, eachSide: true)
        #expect(p.map(\.kind) == [.countIn, .hold, .switchSides, .hold])
    }

    @Test func positionWalksThroughPhases() {
        let p = HoldPlan.phases(seconds: 45, eachSide: false)
        #expect(HoldPlan.position(p, elapsed: 0) == .init(phase: 0, remaining: 3, held: 0))
        #expect(HoldPlan.position(p, elapsed: 3.2) == .init(phase: 1, remaining: 45, held: 0))
        #expect(HoldPlan.position(p, elapsed: 35) == .init(phase: 1, remaining: 13, held: 32))
        let end = HoldPlan.position(p, elapsed: 48.5)
        #expect(end.finished && end.held == 45)
    }
}
