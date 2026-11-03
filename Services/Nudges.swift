import Foundation
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
