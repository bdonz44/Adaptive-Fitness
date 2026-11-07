import Foundation

/// Switches for the v2 adaptive layer (spec: "New adaptive features").
/// Each piece ships behind its own switch so it can be turned off.
public struct AdaptiveSettings: Codable, Equatable, Sendable {
    /// 1. Effort-based progression: the Easy / Solid / Grinder call on a lift
    /// (stored as reps in reserve) changes how far the weight moves next time.
    public var effortProgression: Bool
    /// 2. Time-boxed sessions: the "Time today" picker trims the session to fit.
    public var timeBox: Bool
    /// 4. Missed-day re-entry: lighter first sessions back after 7+ days off.
    public var reEntry: Bool
    /// 8. The Sunday evening weekly review notification.
    public var weeklyReview: Bool

    public init(effortProgression: Bool = false, timeBox: Bool = false, reEntry: Bool = false, weeklyReview: Bool = false) {
        self.effortProgression = effortProgression
        self.timeBox = timeBox
        self.reEntry = reEntry
        self.weeklyReview = weeklyReview
    }

    /// A switch missing from older saved settings takes its starting value.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AdaptiveSettings.starting
        effortProgression = try c.decodeIfPresent(Bool.self, forKey: .effortProgression) ?? d.effortProgression
        timeBox = try c.decodeIfPresent(Bool.self, forKey: .timeBox) ?? d.timeBox
        reEntry = try c.decodeIfPresent(Bool.self, forKey: .reEntry) ?? d.reEntry
        weeklyReview = try c.decodeIfPresent(Bool.self, forKey: .weeklyReview) ?? d.weeklyReview
    }

    /// Everything off: the web app's rules exactly.
    public static let off = AdaptiveSettings()
    /// What a new install starts with.
    public static let starting = AdaptiveSettings(effortProgression: true, timeBox: true, reEntry: true, weeklyReview: true)
}

/// Effort-based progression (RIR) rules.
public enum EffortRules {
    /// What a finished lift's effort does to next time's weight.
    public enum Step: Equatable, Sendable {
        /// Existing rules: no effort logged, setting off, or a miss.
        case normal
        /// Top of the range with 3+ reps left: twice the usual jump.
        case double
        /// Top of the range but a grinder (0 left): same weight.
        case hold
        /// In range (not the top) with 3+ left: the usual jump anyway.
        case bump
    }

    public static func step(reading: SetReading, rir: Int?) -> Step {
        guard let rir, !reading.miss else { return .normal }
        if reading.hitAll {
            if rir >= 3 { return .double }
            if rir == 0 { return .hold }
            return .normal
        }
        return rir >= 3 ? .bump : .normal
    }

    /// Reps a logged set had left in it, counted toward the estimated max (capped at 3).
    public static func extraReps(_ rir: Int?) -> Int { min(max(rir ?? 0, 0), 3) }

    public static let doubleNote = "Top reps with plenty left. Double jump."
    public static let holdNote = "You ground out the top reps. Same weight: own it before it goes up."
    public static let bumpNote = "Easy in range. Going up anyway."
}
