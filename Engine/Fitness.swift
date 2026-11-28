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

// MARK: - Lift forecasts

public enum Forecast {
    /// Estimated max over time for a lift (last 120 days, sessions with weight and reps).
    static func points(_ record: LiftRecord?, now: Date) -> [(x: Double, y: Double, date: Date)] {
        (record?.history ?? []).compactMap { e -> (x: Double, y: Double, date: Date)? in
            guard let w = e.weight, w > 0, let r = e.reps, r > 0, e.date <= now,
                  e.date >= now.addingTimeInterval(-120 * 86400) else { return nil }
            return (e.date.timeIntervalSince1970 / 86400, Suggestions.e1RM(weight: w, reps: r), e.date)
        }
    }

    /// When the trend reaches `target` (estimated max). Needs 4+ sessions over 14+ days, still
    /// rising; nil past a year out.
    public static func date(_ record: LiftRecord?, reaching target: Double, now: Date) -> Date? {
        let p = points(record, now: now)
        guard p.count >= 4, let first = p.map(\.x).min(), let last = p.map(\.x).max(), last - first >= 14 else { return nil }
        let mx = p.map(\.x).reduce(0, +) / Double(p.count), my = p.map(\.y).reduce(0, +) / Double(p.count)
        let den = p.map { ($0.x - mx) * ($0.x - mx) }.reduce(0, +)
        guard den > 0 else { return nil }
        let slope = p.map { ($0.x - mx) * ($0.y - my) }.reduce(0, +) / den   // lb per day
        guard slope > 0.02 else { return nil }
        let nowX = now.timeIntervalSince1970 / 86400
        let fittedNow = my + slope * (nowX - mx)
        let days = max(0, (target - fittedNow) / slope)
        guard days <= 365 else { return nil }
        return now.addingTimeInterval(days * 86400)
    }
}

// MARK: - Fitness age

extension Fitness {
    /// Age whose average VO2 max matches yours (ACSM norms for men, straight lines between
    /// the decades, extended past them), nudged a year or two by strength and heart-rate recovery.
    /// `strengthTier`: 0 Beginner ... 4 Elite (average over the main lifts).
    public static func fitnessAge(vo2: Double, age: Int, strengthTier: Double? = nil, recovery: Int? = nil) -> Int? {
        guard vo2.isFinite, vo2 > 10, vo2 < 90, age > 0 else { return nil }
        let pts: [(age: Double, vo2: Double)] = [(25, 43), (35, 41), (45, 38), (55, 35), (65, 31)]
        var a: Double
        if vo2 >= pts[0].vo2 {
            a = pts[0].age - (vo2 - pts[0].vo2) / 0.25        // about 0.25 per year below 25
        } else if vo2 <= pts[pts.count - 1].vo2 {
            a = pts[pts.count - 1].age + (pts[pts.count - 1].vo2 - vo2) / 0.4
        } else {
            a = pts[0].age
            for (p, q) in zip(pts, pts.dropFirst()) where vo2 <= p.vo2 && vo2 >= q.vo2 {
                a = p.age + (p.vo2 - vo2) / (p.vo2 - q.vo2) * (q.age - p.age)
            }
        }
        if let t = strengthTier { a += t >= 3 ? -2 : t >= 2 ? -1 : t < 1 ? 1 : 0 }
        if let r = recovery { a += r >= 30 ? -1 : r < 12 ? 1 : 0 }
        return Int(min(85, max(20, a)).rounded())
    }
}
