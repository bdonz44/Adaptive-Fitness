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
            setsDone: context.setsDone, setsTotal: context.setsTotal, tick: context.tick)
        present(ActivityContent(state: state, staleDate: end))
    }

    /// Between rests: the next set and a Done button (no countdown, no alert).
    func showWorkout(context: RestContext) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        let now = Date()
        let state = RestTimerAttributes.ContentState(
            label: "Workout", start: now, end: now, style: "big", accent: Look.current.accentHex,
            next: context.next, sessionTitle: context.sessionTitle,
            setsDone: context.setsDone, setsTotal: context.setsTotal, working: true, tick: context.tick)
        present(ActivityContent(state: state, staleDate: nil))
    }

    private func present(_ content: ActivityContent<RestTimerAttributes.ContentState>) {
        // A rest that ran past zero goes stale; it can still be updated, and must never be
        // left behind on the Lock Screen while a second one is started.
        if let activity, activity.activityState == .active || activity.activityState == .stale {
            Task { await activity.update(content) }
            return
        }
        if let old = activity {
            Task { await old.end(nil, dismissalPolicy: .immediate) }
        }
        activity = nil
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
        guard seconds > 0.5 else {
            // Moved to zero (−15 s): the alert for the old end time must not still go off.
            center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
            return
        }
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
