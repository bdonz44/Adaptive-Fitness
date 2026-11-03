import Foundation
import Observation

/// What the Lock Screen shows alongside the countdown.
struct RestContext {
    var next: String = ""
    var sessionTitle: String = ""
    var setsDone: Int = 0
    var setsTotal: Int = 0
}

/// Rest countdown. Ticking a set starts the item's rest; the first item of a
/// superset pair starts a 20 sec transition instead. Every change also moves the
/// end-time notification and the Lock Screen Live Activity.
@Observable
final class RestTimer {
    static let shared = RestTimer()
    static let transitionSeconds = 20

    private(set) var endDate: Date?
    private(set) var startDate = Date()
    private(set) var label: String = ""

    /// Set by the app so the Lock Screen can show the next set and session progress.
    @ObservationIgnored var contextProvider: () -> RestContext = { RestContext() }
    @ObservationIgnored private let alerts = RestAlerts()

    var isActive: Bool { endDate != nil }

    /// Full length of the current rest, for progress rings.
    var total: TimeInterval { endDate.map { $0.timeIntervalSince(startDate) } ?? 0 }

    func start(seconds: Int, label: String) {
        guard seconds > 0 else { return }
        self.label = label
        startDate = Date()
        endDate = startDate.addingTimeInterval(TimeInterval(seconds))
        publish()
    }

    func addThirty() {
        guard let end = endDate else { return }
        // If it already hit zero, +30 counts from now.
        let now = Date()
        if end <= now { startDate = now }
        endDate = max(end, now).addingTimeInterval(30)
        publish()
    }

    /// Takes 15 sec off; never below zero.
    func minusFifteen() {
        guard let end = endDate else { return }
        let now = Date()
        endDate = max(now, end.addingTimeInterval(-15))
        publish()
    }

    func done() {
        if endDate != nil { alerts.clear() }
        endDate = nil
        label = ""
    }

    func remaining(at date: Date) -> TimeInterval {
        guard let end = endDate else { return 0 }
        return max(0, end.timeIntervalSince(date))
    }

    /// Re-sends the Lock Screen (after the look or Lock Screen style changes).
    func refreshLockScreen() {
        if isActive { publish() }
    }

    private func publish() {
        guard let end = endDate else { return }
        alerts.show(label: label, start: startDate, end: end, context: contextProvider())
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Called by the Lock Screen buttons (RestAddThirtyIntent, RestDoneIntent).
enum RestTimerControl {
    @MainActor static func addThirty() { RestTimer.shared.addThirty() }
    @MainActor static func done() { RestTimer.shared.done() }
}
