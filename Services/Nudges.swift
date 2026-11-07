import Foundation
import Observation
import UserNotifications

/// "Two days off" reminder. Each finished session pushes it back.
enum Nudges {
    static let id = "coach-nudge"

    static func schedule(_ nudge: (date: Date, text: String)) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let seconds = nudge.date.timeIntervalSinceNow
        guard seconds > 60 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Coach"
        content.body = nudge.text
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted { center.add(request) }
        }
    }
}

/// Sunday 6:41 pm: "Your week is in." Opens the weekly review.
enum WeeklyReviewNotice {
    static let id = "weekly-review"

    static func schedule(_ on: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard on else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your week is in"
        content.body = "See what you did, what went up, and what's next. Then go get next week."
        content.sound = .default
        var when = DateComponents()
        when.weekday = 1   // Sunday
        when.hour = 18
        when.minute = 41
        let request = UNNotificationRequest(identifier: id, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted { center.add(request) }
        }
    }
}

/// Handles notification taps (the weekly review opens its screen). Other notifications
/// stay quiet while the app is open, as before.
@Observable
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()
    var showWeeklyReview = false

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == WeeklyReviewNotice.id {
            DispatchQueue.main.async { self.showWeeklyReview = true }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(notification.request.identifier == WeeklyReviewNotice.id ? [.banner, .sound] : [])
    }
}
