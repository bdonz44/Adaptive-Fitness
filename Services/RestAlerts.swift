import ActivityKit
import Foundation
import UserNotifications

/// Keeps the rest timer working with the phone locked: a local notification at
/// the end time plus a Live Activity on the Lock Screen and Dynamic Island.
final class RestAlerts {
    private static let notificationID = "rest-timer"
    private let center = UNUserNotificationCenter.current()
    private var activity: Activity<RestTimerAttributes>?

    /// Starts or moves both alerts to a new end time.
    func show(label: String, start: Date, end: Date, context: RestContext) {
        scheduleNotification(label: label, end: end)
        let style = UserDefaults.standard.string(forKey: LockStyle.storageKey) ?? LockStyle.big.rawValue
        let state = RestTimerAttributes.ContentState(
            label: label, start: start, end: end, style: style, accent: Look.current.accentHex,
            next: context.next, sessionTitle: context.sessionTitle,
            setsDone: context.setsDone, setsTotal: context.setsTotal)
        let content = ActivityContent(state: state, staleDate: end)
        if let activity, activity.activityState == .active {
            Task { await activity.update(content) }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        activity = try? Activity.request(attributes: RestTimerAttributes(), content: content, pushType: nil)
    }

    func clear() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        center.removeDeliveredNotifications(withIdentifiers: [Self.notificationID])
        if let activity {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        activity = nil
    }

    /// The timer does not survive the app being closed, so neither should its Live Activity.
    static func endLeftovers() {
        for activity in Activity<RestTimerAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func scheduleNotification(label: String, end: Date) {
        let seconds = end.timeIntervalSinceNow
        guard seconds > 0.5 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Go"
        let transition = "Transition to "
        content.body = label.hasPrefix(transition)
            ? "Time for \(label.dropFirst(transition.count))."
            : "\(label) is over."
        content.sound = .default
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
        // The first timer asks for permission; after that this returns the saved answer.
        center.requestAuthorization(options: [.alert, .sound]) { [center] granted, _ in
            guard granted else { return }
            center.add(request)
        }
    }
}
