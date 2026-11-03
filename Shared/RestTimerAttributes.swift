import ActivityKit
import AppIntents
import Foundation

/// The rest timer's Live Activity (Lock Screen and Dynamic Island).
/// Compiled into both the app and the Hybrid12Widgets extension.
struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var label: String
        var start: Date
        var end: Date
        /// Lock Screen layout: "big", "progress" or "buttons".
        var style: String = "big"
        /// Accent color of the chosen look, 0xRRGGBB.
        var accent: UInt32 = 0xFF7A1A
        /// "Back Squat set 4 · 235 × 5", or empty.
        var next: String = ""
        var sessionTitle: String = ""
        var setsDone: Int = 0
        var setsTotal: Int = 0
    }
}

/// Lock Screen layouts the user can pick in Look settings.
enum LockStyle: String, CaseIterable, Identifiable {
    case big, progress, buttons
    var id: String { rawValue }
    static let storageKey = "lockStyle"

    var name: String {
        switch self {
        case .big: return "Big number"
        case .progress: return "Session progress"
        case .buttons: return "With buttons"
        }
    }

    var blurb: String {
        switch self {
        case .big: return "Large countdown and your next set"
        case .progress: return "Sets done so far plus the countdown"
        case .buttons: return "+30s and Done right on the Lock Screen"
        }
    }
}

// Lock Screen buttons. They run inside the app (RestTimerControl); the widget
// extension has a do-nothing copy of RestTimerControl so this file compiles there too.

struct RestAddThirtyIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Add 30 seconds"
    init() {}
    func perform() async throws -> some IntentResult {
        await RestTimerControl.addThirty()
        return .result()
    }
}

struct RestDoneIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End rest"
    init() {}
    func perform() async throws -> some IntentResult {
        await RestTimerControl.done()
        return .result()
    }
}
