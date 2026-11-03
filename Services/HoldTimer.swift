import Foundation
import Observation
import UIKit
import Hybrid12Engine

/// A running timed hold (plank 45 sec). Finishing logs the seconds and ticks the set.
@Observable
final class HoldTimer {
    struct Target: Equatable {
        let key: String
        let set: Int
        let seconds: Int
        let name: String
    }

    private(set) var target: Target?
    private(set) var phases: [HoldPlan.Phase] = []
    private(set) var startDate = Date()

    var isActive: Bool { target != nil }

    func start(_ target: Target, eachSide: Bool) {
        self.target = target
        phases = HoldPlan.phases(seconds: target.seconds, eachSide: eachSide)
        startDate = Date()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func position(at date: Date) -> HoldPlan.Position {
        HoldPlan.position(phases, elapsed: date.timeIntervalSince(startDate))
    }

    func cancel() {
        target = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
