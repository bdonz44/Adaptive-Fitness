import Foundation
import Observation

/// Rest countdown. Ticking a set starts the item's rest; the first item of a
/// superset pair starts a 20 sec transition instead. (Lock Screen Live Activity
/// and notifications come in milestone 5.)
@Observable
final class RestTimer {
    static let transitionSeconds = 20

    private(set) var endDate: Date?
    private(set) var label: String = ""

    var isActive: Bool { endDate != nil }

    func start(seconds: Int, label: String) {
        guard seconds > 0 else { return }
        self.label = label
        endDate = Date().addingTimeInterval(TimeInterval(seconds))
    }

    func addThirty() {
        guard let end = endDate else { return }
        // If it already hit zero, +30 counts from now.
        endDate = max(end, Date()).addingTimeInterval(30)
    }

    func done() {
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
