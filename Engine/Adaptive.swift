import Foundation

/// Switches for the v2 adaptive layer (spec: "New adaptive features").
/// Each piece ships behind its own switch so it can be turned off.
public struct AdaptiveSettings: Codable, Equatable, Sendable {
    /// 1. Effort-based progression: the Easy / Solid / Grinder call on a lift
    /// (stored as reps in reserve) changes how far the weight moves next time.
    public var effortProgression: Bool

    public init(effortProgression: Bool = false) {
        self.effortProgression = effortProgression
    }

    /// Switches added later read as off from older saved settings.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        effortProgression = try c.decodeIfPresent(Bool.self, forKey: .effortProgression) ?? false
    }

    /// Everything off: the web app's rules exactly.
    public static let off = AdaptiveSettings()
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
