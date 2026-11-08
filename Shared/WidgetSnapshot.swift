import Foundation

/// What the Home Screen widget shows, written by the app into the shared App Group.
struct WidgetSnapshot: Codable, Equatable {
    static let group = "group.com.bdonz44.hybrid12"
    static let key = "widget.snapshot"

    var title: String
    var subtitle: String
    var done: Int
    var total: Int
    var streak: Int
    var proteinEaten: Int?
    var proteinTarget: Int?
    var recovery: Int?
    var doneToday: Bool
    var updated: Date

    static let placeholder = WidgetSnapshot(title: "Heavy Upper", subtitle: "Day 4 of 5 · Week 6", done: 3, total: 5,
                                            streak: 6, proteinEaten: 92, proteinTarget: 185, recovery: 78,
                                            doneToday: false, updated: Date())

    static func read() -> WidgetSnapshot? {
        UserDefaults(suiteName: group)?.data(forKey: key).flatMap { try? JSONDecoder().decode(WidgetSnapshot.self, from: $0) }
    }

    func write() {
        guard let d = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.group)?.set(d, forKey: Self.key)
    }
}
