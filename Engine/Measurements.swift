import Foundation

/// Tape measurements beyond the waist.
public enum BodyPart: String, Codable, CaseIterable, Sendable {
    case chest, arm
    public var name: String { self == .chest ? "Chest" : "Arm (flexed)" }
    public var how: String {
        switch self {
        case .chest: return "Around the nipple line, arms relaxed, after a normal breath out."
        case .arm: return "Biggest point of the flexed right arm."
        }
    }
}

public struct BodyMeasurement: Codable, Equatable, Sendable {
    public var date: Date
    public var part: BodyPart
    public var inches: Double
    public init(date: Date, part: BodyPart, inches: Double) { self.date = date; self.part = part; self.inches = inches }
}
