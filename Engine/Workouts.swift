import Foundation

/// What gets written to Apple Health for a finished session.
public struct WorkoutRecord: Equatable, Sendable {
    public enum Kind: String, Sendable { case strength, running }
    public var kind: Kind
    public var title: String
    public var start: Date
    public var end: Date

    public var minutes: Int { Int((end.timeIntervalSince(start) / 60).rounded()) }
}

public enum Workouts {
    /// Used when the start time is missing or not believable.
    public static let fallbackStrengthMinutes = 45
    static let minimumMinutes = 5
    static let maximumMinutes = 240

    /// The easy run becomes a running workout as long as the logged minutes, ending at Finish.
    /// Every other session becomes a strength workout from the first tick to Finish.
    /// Nothing logged, nothing written.
    public static func record(session: Session, entries: [String: LoggedItem], startedAt: Date?,
                              finishedAt end: Date, cardioMinutes: Int) -> WorkoutRecord? {
        guard entries.values.contains(where: { $0.hasCompletedWork }) else { return nil }
        if session.slot == .R {
            guard cardioMinutes > 0 else { return nil }
            return WorkoutRecord(kind: .running, title: session.title,
                                 start: end.addingTimeInterval(-Double(cardioMinutes) * 60), end: end)
        }
        var start = end.addingTimeInterval(-Double(fallbackStrengthMinutes) * 60)
        if let startedAt {
            let minutes = end.timeIntervalSince(startedAt) / 60
            if minutes >= Double(minimumMinutes), minutes <= Double(maximumMinutes) { start = startedAt }
        }
        return WorkoutRecord(kind: .strength, title: session.title, start: start, end: end)
    }
}
