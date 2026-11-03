import Foundation

/// Today's WHOOP numbers (from the WHOOP API).
public struct WhoopToday: Codable, Equatable, Sendable {
    public var recovery: Int?
    public var hrv: Double?
    public var restingHR: Int?
    public var sleepHours: Double?
    public var sleepPerformance: Int?
    public var strain: Double?
    /// Start of the WHOOP day (cycle) these belong to.
    public var cycleStart: Date?
    public var fetchedAt: Date

    public init(recovery: Int? = nil, hrv: Double? = nil, restingHR: Int? = nil, sleepHours: Double? = nil,
                sleepPerformance: Int? = nil, strain: Double? = nil, cycleStart: Date? = nil, fetchedAt: Date) {
        self.recovery = recovery
        self.hrv = hrv
        self.restingHR = restingHR
        self.sleepHours = sleepHours
        self.sleepPerformance = sleepPerformance
        self.strain = strain
        self.cycleStart = cycleStart
        self.fetchedAt = fetchedAt
    }
}

/// Turns WHOOP recovery into the readiness chip and a coach line.
public enum WhoopReadiness {
    public enum Zone: String, Sendable { case green, yellow, red }

    /// WHOOP's own bands: 67-100 green, 34-66 yellow, 0-33 red.
    public static func zone(_ recovery: Int) -> Zone {
        recovery >= 67 ? .green : recovery >= 34 ? .yellow : .red
    }

    public static func readiness(_ t: WhoopToday) -> Readiness? {
        guard let r = t.recovery else { return nil }
        switch zone(r) {
        case .green: return .great
        case .yellow: return .normal
        case .red: return .beat
        }
    }

    /// "Recovery 72% · HRV 58 ms · RHR 54 · Slept 7h 42m"
    public static func summary(_ t: WhoopToday) -> String {
        var parts: [String] = []
        if let r = t.recovery { parts.append("Recovery \(r)%") }
        if let h = t.hrv { parts.append("HRV \(Int(h.rounded())) ms") }
        if let rhr = t.restingHR { parts.append("RHR \(rhr)") }
        if let s = t.sleepHours {
            let m = Int((s * 60).rounded())
            parts.append("Slept \(m / 60)h \(String(format: "%02d", m % 60))m")
        }
        return parts.joined(separator: " · ")
    }

    /// What the coach says about today.
    public static func coachLine(_ t: WhoopToday) -> String? {
        guard let r = t.recovery else { return nil }
        switch zone(r) {
        case .green: return "Green at \(r)%. Your body is ready. Push every set and chase the top of every range."
        case .yellow: return "Yellow at \(r)%. Work hard, hit your numbers, no hero sets."
        case .red:
            let sleep = (t.sleepHours ?? 8) < 6 ? " Short sleep." : ""
            return "Red at \(r)%.\(sleep) Lighter day: get the work in, recover, and come back swinging."
        }
    }

    /// The data is for today's WHOOP day and is under 6 hours old.
    public static func isCurrent(_ t: WhoopToday, now: Date, calendar: Calendar = .current) -> Bool {
        guard now.timeIntervalSince(t.fetchedAt) < 6 * 3600 else { return false }
        guard let start = t.cycleStart else { return true }
        return now.timeIntervalSince(start) < 30 * 3600
    }
}
