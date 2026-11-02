import ActivityKit
import Foundation

/// The rest timer's Live Activity (Lock Screen and Dynamic Island).
/// Compiled into both the app and the Hybrid12Widgets extension.
struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var label: String
        var start: Date
        var end: Date
    }
}
