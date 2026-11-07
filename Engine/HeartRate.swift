import Foundation

/// Live heart rate (WHOOP's Bluetooth heart-rate broadcast, or any standard strap):
/// reading the signal, zones, targets for conditioning, and time in each zone.
public enum HeartRate {
    /// Age-predicted max for 45 (Tanaka: 208 - 0.7 × age). Used until set or read from WHOOP.
    public static let defaultMax = 176

    public static func estimatedMax(age: Int) -> Int { Int((208 - 0.7 * Double(age)).rounded()) }

    // MARK: Reading the Bluetooth signal

    /// Bluetooth Heart Rate Measurement (characteristic 0x2A37): flags byte, then
    /// beats per minute as 8 bits, or 16 bits little-endian when flag bit 0 is set.
    public static func bpm(fromMeasurement bytes: [UInt8]) -> Int? {
        guard let flags = bytes.first else { return nil }
        let value: Int
        if flags & 0x01 == 0 {
            guard bytes.count >= 2 else { return nil }
            value = Int(bytes[1])
        } else {
            guard bytes.count >= 3 else { return nil }
            value = Int(bytes[1]) | Int(bytes[2]) << 8
        }
        return (25...250).contains(value) ? value : nil
    }

    // MARK: Zones (WHOOP style: % of max heart rate)

    /// 0: under 50%, 1: 50-60, 2: 60-70, 3: 70-80, 4: 80-90, 5: 90+.
    public static func zone(bpm: Int, max: Int) -> Int {
        let pct = percent(bpm: bpm, max: max)
        switch pct {
        case ..<50: return 0
        case ..<60: return 1
        case ..<70: return 2
        case ..<80: return 3
        case ..<90: return 4
        default: return 5
        }
    }

    public static func percent(bpm: Int, max: Int) -> Int {
        Int((Double(bpm) / Double(Swift.max(max, 1)) * 100).rounded())
    }

    public static func bpm(percent: Int, max: Int) -> Int {
        Int((Double(percent) / 100 * Double(max)).rounded())
    }

    // MARK: Targets

    /// Where heart rate should be during the work of this conditioning block (% of max), or nil.
    public static func target(for item: SessionItem) -> ClosedRange<Int>? {
        if let low = item.hrLow, let high = item.hrHigh { return low...high }
        switch item.kind {
        case .run: return 60...75
        case .engine: return item.intervalWork == nil ? 75...90 : 80...90
        case .finisher: return 80...95
        default: return nil
        }
    }

    public enum Status: Equatable, Sendable { case below, inZone, above }

    public static func status(bpm: Int, max: Int, target: ClosedRange<Int>) -> Status {
        let pct = percent(bpm: bpm, max: max)
        if pct < target.lowerBound { return .below }
        if pct > target.upperBound { return .above }
        return .inZone
    }

    /// "150-168 bpm"
    public static func targetText(_ target: ClosedRange<Int>, max: Int) -> String {
        "\(bpm(percent: target.lowerBound, max: max))-\(bpm(percent: target.upperBound, max: max)) bpm"
    }

    // MARK: Time in zone

    public struct Sample: Equatable, Codable, Sendable {
        public var date: Date
        public var bpm: Int
        public init(date: Date, bpm: Int) { self.date = date; self.bpm = bpm }
    }

    /// One session's heart rate: seconds in zones 0-5, average and peak.
    public struct Summary: Equatable, Codable, Sendable {
        public var zoneSeconds: [Double]
        public var average: Int
        public var peak: Int
        public var seconds: Double { zoneSeconds.reduce(0, +) }
        /// Seconds in zones 4 and 5 (80%+ of max): the VO2 max work.
        public var hardSeconds: Double { zoneSeconds[4] + zoneSeconds[5] }
    }

    /// Samples from `start` to `end`. Each sample counts until the next one, up to 5 sec
    /// (a dropped connection doesn't count as time in the last zone).
    public static func summary(_ samples: [Sample], from start: Date, to end: Date, max: Int) -> Summary? {
        let inside = samples.filter { $0.date >= start && $0.date <= end }.sorted { $0.date < $1.date }
        guard !inside.isEmpty else { return nil }
        var zones = [Double](repeating: 0, count: 6)
        var weighted = 0.0, total = 0.0
        for (i, s) in inside.enumerated() {
            let next = i + 1 < inside.count ? inside[i + 1].date : end
            let dt = Swift.min(5, Swift.max(0, next.timeIntervalSince(s.date)))
            zones[zone(bpm: s.bpm, max: max)] += dt
            weighted += Double(s.bpm) * dt
            total += dt
        }
        let avg = total > 0 ? Int((weighted / total).rounded()) : inside[0].bpm
        return Summary(zoneSeconds: zones, average: avg, peak: inside.map(\.bpm).max() ?? 0)
    }
}

/// A WHOOP-scored workout (from the WHOOP API).
public struct WhoopWorkout: Equatable, Codable, Sendable {
    public var start: Date
    public var end: Date
    public var sport: String?
    public var strain: Double?
    public var averageHR: Int?
    public var maxHR: Int?
    public var kilojoules: Double?
    /// Seconds in WHOOP zones 0-5.
    public var zoneSeconds: [Double]

    public var calories: Int? { kilojoules.map { Int(($0 / 4.184).rounded()) } }

    /// Reads `/developer/v2/activity/workout` records; unscored workouts are skipped.
    public static func parse(_ json: [String: Any]) -> [WhoopWorkout] {
        let records = (json["records"] as? [[String: Any]]) ?? []
        return records.compactMap { r in
            guard r["score_state"] as? String == "SCORED", let score = r["score"] as? [String: Any],
                  let s = (r["start"] as? String).flatMap(WhoopDate.parse),
                  let e = (r["end"] as? String).flatMap(WhoopDate.parse) else { return nil }
            let zd = score["zone_durations"] as? [String: Any] ?? [:]
            let names = ["zone_zero_milli", "zone_one_milli", "zone_two_milli", "zone_three_milli", "zone_four_milli", "zone_five_milli"]
            return WhoopWorkout(
                start: s, end: e, sport: r["sport_name"] as? String,
                strain: (score["strain"] as? NSNumber)?.doubleValue,
                averageHR: (score["average_heart_rate"] as? NSNumber)?.intValue,
                maxHR: (score["max_heart_rate"] as? NSNumber)?.intValue,
                kilojoules: (score["kilojoule"] as? NSNumber)?.doubleValue,
                zoneSeconds: names.map { ((zd[$0] as? NSNumber)?.doubleValue ?? 0) / 1000 })
        }
    }

    /// For a session saved before heart rate was stored: only its finish time is known,
    /// so look at the 90 minutes before it.
    public static func match(_ workouts: [WhoopWorkout], finishedAt end: Date) -> WhoopWorkout? {
        match(workouts, start: end.addingTimeInterval(-90 * 60), end: end.addingTimeInterval(5 * 60))
    }

    /// The WHOOP workout that overlaps the session most (at least 5 minutes), if any.
    public static func match(_ workouts: [WhoopWorkout], start: Date, end: Date) -> WhoopWorkout? {
        func overlap(_ w: WhoopWorkout) -> TimeInterval {
            max(0, min(w.end, end).timeIntervalSince(max(w.start, start)))
        }
        return workouts.filter { overlap($0) >= 5 * 60 }.max { overlap($0) < overlap($1) }
    }
}

/// WHOOP API timestamps ("2026-11-07T18:02:11.123Z", fraction optional).
public enum WhoopDate {
    public static func parse(_ text: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: text) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: text)
    }

    public static func string(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }
}

/// A finished session's heart rate, saved with the session log (synced through iCloud):
/// the app's live readings, and WHOOP's numbers once WHOOP scores the workout.
public struct SessionHeart: Codable, Equatable, Sendable {
    public var average: Int?
    public var peak: Int?
    /// Seconds in zones 0-5 (WHOOP's when known, else the app's live readings).
    public var zoneSeconds: [Double]
    public var strain: Double?
    public var calories: Int?
    public var fromWhoop: Bool

    public init(live: HeartRate.Summary) {
        average = live.average
        peak = live.peak
        zoneSeconds = live.zoneSeconds
        fromWhoop = false
    }

    /// WHOOP's scored workout replaces the live numbers (WHOOP has the full picture).
    public mutating func apply(_ w: WhoopWorkout) {
        if let a = w.averageHR { average = a }
        if let m = w.maxHR { peak = m }
        if w.zoneSeconds.reduce(0, +) > 0 { zoneSeconds = w.zoneSeconds }
        strain = w.strain
        calories = w.calories
        fromWhoop = true
    }

    public init(whoop w: WhoopWorkout) {
        zoneSeconds = [Double](repeating: 0, count: 6)
        fromWhoop = true
        apply(w)
    }

    /// Minutes at 80%+ of max: the VO2 max work.
    public var hardMinutes: Double { (zoneSeconds.count == 6 ? zoneSeconds[4] + zoneSeconds[5] : 0) / 60 }

    /// "Avg 132 · Max 171 · Zone 4-5 18 min · Strain 12.4"
    public var line: String {
        var parts: [String] = []
        if let a = average { parts.append("Avg \(a)") }
        if let p = peak { parts.append("Max \(p)") }
        parts.append("Zone 4-5 \(Int(hardMinutes.rounded())) min")
        if let s = strain { parts.append(String(format: "Strain %.1f", s)) }
        return parts.joined(separator: " · ")
    }

    /// Kept in the log's entries under this key (as an otherwise empty LoggedItem),
    /// so the synced record's shape doesn't change.
    public static let entryKey = "_session"

    public static func read(_ entries: [String: LoggedItem]) -> SessionHeart? { entries[entryKey]?.heart }

    public static func write(_ heart: SessionHeart?, into entries: inout [String: LoggedItem]) {
        guard let heart else { return }
        var e = entries[entryKey] ?? LoggedItem()
        e.heart = heart
        entries[entryKey] = e
    }

    /// Hard minutes per stored week, oldest first.
    public static func hardMinutesByWeek(_ logs: [(week: Int, heart: SessionHeart)]) -> [(week: Int, minutes: Double)] {
        var by: [Int: Double] = [:]
        for l in logs { by[l.week, default: 0] += l.heart.hardMinutes }
        return by.keys.sorted().map { (week: $0, minutes: by[$0]!) }
    }
}
