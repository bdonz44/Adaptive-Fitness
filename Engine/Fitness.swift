import Foundation

// MARK: - 4. VO2 max and 9. heart-rate recovery

/// A VO2 max reading (ml/kg/min): from Apple Health (any app that writes it, e.g. WHOOP or
/// an Apple Watch) or a 12-minute run test typed in.
public struct VO2Reading: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var date: Date
    public var value: Double
    public var source: String
    public init(id: String = UUID().uuidString, date: Date, value: Double, source: String) {
        self.id = id; self.date = date; self.value = value; self.source = source
    }
}

public enum Fitness {
    /// Cooper 12-minute test: the farthest you can run in 12 minutes.
    /// VO2 max ≈ (meters - 504.9) / 44.73. Nil outside 1-5 km (a typo).
    public static func cooper(miles: Double) -> Double? {
        let meters = miles * 1609.344
        guard meters.isFinite, meters >= 1000, meters <= 5000 else { return nil }
        return ((meters - 504.9) / 44.73 * 10).rounded() / 10
    }

    /// Heart-rate recovery: how far heart rate falls in the minute after hard work.
    /// For each work round's end: the highest reading in its last 15 sec minus the reading
    /// nearest 60 sec later (within 5 sec). Averaged; nil without good readings.
    public static func recovery(_ samples: [HeartRate.Sample], workEnds: [Date]) -> Int? {
        let sorted = samples.sorted { $0.date < $1.date }
        var drops: [Int] = []
        for end in workEnds {
            let peak = sorted.filter { $0.date >= end.addingTimeInterval(-15) && $0.date <= end.addingTimeInterval(2) }
                .map(\.bpm).max()
            let after = sorted.filter { abs($0.date.timeIntervalSince(end.addingTimeInterval(60))) <= 5 }
                .min { abs($0.date.timeIntervalSince(end.addingTimeInterval(60))) < abs($1.date.timeIntervalSince(end.addingTimeInterval(60))) }
            if let p = peak, let a = after?.bpm, p - a >= 0, p - a <= 90 { drops.append(p - a) }
        }
        guard !drops.isEmpty else { return nil }
        return Int((Double(drops.reduce(0, +)) / Double(drops.count)).rounded())
    }

    /// What a one-minute drop says (higher is fitter).
    public static func recoveryVerdict(_ drop: Int) -> String {
        switch drop {
        case ..<12: return "Slow recovery: rest well, keep the easy days easy"
        case 12..<20: return "Average recovery"
        case 20..<30: return "Good recovery"
        default: return "Excellent recovery"
        }
    }

    /// Change from the first to the latest of the readings in the last `days` days.
    public static func change(_ points: [(date: Date, value: Double)], days: Int, now: Date) -> Double? {
        let recent = points.filter { $0.date >= now.addingTimeInterval(-Double(days) * 86400) && $0.date <= now }
            .sorted { $0.date < $1.date }
        guard let first = recent.first, let last = recent.last, last.date > first.date else { return nil }
        return last.value - first.value
    }

    /// Typical VO2 max for men by age (ACSM, 50th and 80th percentile), for context.
    public static func norms(age: Int) -> (average: Double, good: Double) {
        switch age {
        case ..<30: return (43, 49)
        case 30..<40: return (41, 47)
        case 40..<50: return (38, 44)
        case 50..<60: return (35, 41)
        default: return (31, 37)
        }
    }
}

// MARK: - 11. Coach memory

public struct CoachMemoryNote: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var date: Date
    public var text: String
    public init(id: String = UUID().uuidString, date: Date, text: String) {
        self.id = id; self.date = date; self.text = text
    }
}

public enum CoachMemory {
    public static let limit = 30
    public static let inContext = 10

    /// Adds a note (trimmed, max 200 characters), replacing an older one with the same text.
    public static func adding(_ text: String, to notes: [CoachMemoryNote], date: Date) -> [CoachMemoryNote] {
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        guard !clean.isEmpty else { return notes }
        var out = notes.filter { $0.text.lowercased() != clean.lowercased() }
        out.append(CoachMemoryNote(date: date, text: clean))
        if out.count > limit { out.removeFirst(out.count - limit) }
        return out
    }

    /// "Notes from earlier chats: Nov 20: left shoulder sore on overhead press; ..."
    public static func context(_ notes: [CoachMemoryNote], skips: [(name: String, reason: String)]) -> String? {
        var parts: [String] = []
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        for n in notes.suffix(inContext) { parts.append("\(f.string(from: n.date)): \(n.text)") }
        for s in skips.prefix(5) { parts.append("skipped \(s.name) last time (\(s.reason.lowercased()))") }
        return parts.isEmpty ? nil : "Notes from earlier: " + parts.joined(separator: "; ") + "."
    }
}
