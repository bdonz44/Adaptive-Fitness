import Foundation

/// Progress photos (front, side, back) every two weeks, and tape measurements beyond the waist.
public enum PhotoPose: String, Codable, CaseIterable, Sendable {
    case front, side, back
    public var name: String { rawValue.capitalized }
    public var tip: String {
        switch self {
        case .front: return "Face the camera, arms relaxed at your sides, feet hip width."
        case .side: return "Turn your right side to the camera, arms relaxed, stand tall."
        case .back: return "Back to the camera, arms relaxed at your sides."
        }
    }
}

public struct ProgressPhoto: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var date: Date
    public var pose: PhotoPose
    /// File name inside the app's progress folder.
    public var file: String

    public init(id: String = UUID().uuidString, date: Date, pose: PhotoPose, file: String) {
        self.id = id; self.date = date; self.pose = pose; self.file = file
    }
}

public enum ProgressPhotos {
    public static let everyDays = 14

    /// The newest photo of a pose (the ghost to line up against), optionally before a date.
    public static func latest(_ photos: [ProgressPhoto], pose: PhotoPose, before: Date? = nil) -> ProgressPhoto? {
        photos.filter { p in p.pose == pose && (before.map { p.date < $0 } ?? true) }.max { $0.date < $1.date }
    }

    /// Photo days, newest first (one entry per calendar day that has any photo).
    public static func days(_ photos: [ProgressPhoto], calendar: Calendar = .current) -> [Date] {
        Array(Set(photos.map { calendar.startOfDay(for: $0.date) })).sorted(by: >)
    }

    public static func photo(_ photos: [ProgressPhoto], pose: PhotoPose, on day: Date, calendar: Calendar = .current) -> ProgressPhoto? {
        photos.filter { $0.pose == pose && calendar.isDate($0.date, inSameDayAs: day) }.max { $0.date < $1.date }
    }

    /// Days until photos are due again (0 or less: due now). Nil when there are none yet (due now).
    public static func daysUntilDue(_ photos: [ProgressPhoto], now: Date, calendar: Calendar = .current) -> Int? {
        guard let last = photos.map(\.date).max() else { return nil }
        let since = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 0
        return everyDays - since
    }
}

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
