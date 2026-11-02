import Foundation
import Observation

/// Rest countdown. Ticking a set starts the item's rest; the first item of a
/// superset pair starts a 20 sec transition instead. Every change also moves the
/// end-time notification and the Lock Screen Live Activity.
@Observable
final class RestTimer {
    static let transitionSeconds = 20

    private(set) var endDate: Date?
    private(set) var label: String = ""
    @ObservationIgnored private var startDate = Date()
    @ObservationIgnored private let alerts = RestAlerts()

    var isActive: Bool { endDate != nil }

    func start(seconds: Int, label: String) {
        guard seconds > 0 else { return }
        self.label = label
        startDate = Date()
        let end = startDate.addingTimeInterval(TimeInterval(seconds))
        endDate = end
        alerts.show(label: label, start: startDate, end: end)
    }

    func addThirty() {
        guard let end = endDate else { return }
        // If it already hit zero, +30 counts from now.
        let now = Date()
        if end <= now { startDate = now }
        let newEnd = max(end, now).addingTimeInterval(30)
        endDate = newEnd
        alerts.show(label: label, start: startDate, end: newEnd)
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

    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
