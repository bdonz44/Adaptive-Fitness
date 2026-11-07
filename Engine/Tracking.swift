import Foundation

/// Progress tab data: bodyweight, waist, working weights and recent sessions.
public enum Tracking {
    /// Waist target shown until there are two entries (heart-health guideline).
    public static let waistTarget = 40.0
    public static let recentSessionLimit = 12
    /// Bodyweight entries shown in the list (each with Remove).
    public static let weighInListLimit = 5

    // MARK: Bodyweight and waist

    /// Adds a weigh-in, keeps the list oldest first, and keeps the last 120.
    public static func adding(_ entry: WeighIn, to list: [WeighIn]) -> [WeighIn] {
        Array((list + [entry]).sorted { $0.date < $1.date }.suffix(Coach.weighInLimit))
    }

    /// Adds a waist entry, keeps the list oldest first, and keeps the last 60.
    public static func adding(_ entry: WaistEntry, to list: [WaistEntry]) -> [WaistEntry] {
        Array((list + [entry]).sorted { $0.date < $1.date }.suffix(Coach.waistLimit))
    }

    public struct Trend: Equatable, Sendable {
        public var latest: Double
        /// Latest minus the first entry; nil with only one entry.
        public var changeSinceFirst: Double?
    }

    /// Latest value and change since the first entry, from values in date order.
    public static func trend(_ values: [Double]) -> Trend? {
        guard let first = values.first, let last = values.last else { return nil }
        return Trend(latest: last, changeSinceFirst: values.count > 1 ? last - first : nil)
    }

    /// "-4.5 lb", "+1 lb", "no change"
    public static func changeText(_ change: Double, unit: String) -> String {
        let rounded = (change * 10).rounded() / 10
        if rounded == 0 { return "no change" }
        return (rounded > 0 ? "+" : "-") + Fmt.lb(abs(rounded)) + " " + unit
    }

    /// Show the under-40 in target until there are two waist entries.
    public static func showsWaistTarget(entryCount: Int) -> Bool { entryCount < 2 }

    // MARK: Working weights

    public struct WorkingWeight: Equatable, Sendable, Identifiable {
        public var id: String
        public var name: String
        public var isMain: Bool
        public var equipment: Equipment
        public var weight: Double
        /// Estimated one-rep max (not for kettlebells).
        public var estimatedMax: Double?
        /// Logged weights, oldest first, for the sparkline.
        public var history: [Double]
    }

    /// Every lift with a stored weight, main lifts first, each group in library order.
    public static func workingWeights(lifts: [String: LiftRecord], catalog: Catalog = .bundled) -> [WorkingWeight] {
        let ordered = catalog.mainLifts.map { ($0, true) } + catalog.accessories.map { ($0, false) }
        return ordered.compactMap { ex, isMain in
            guard let rec = lifts[ex.id], let weight = rec.workingWeight else { return nil }
            let max = ex.eq == .kb ? nil : Suggestions.best1RM(rec).map(Suggestions.round5)
            return WorkingWeight(id: ex.id, name: ex.name, isMain: isMain, equipment: ex.eq, weight: weight,
                                 estimatedMax: max, history: rec.history.compactMap(\.weight))
        }
    }
}

/// Cardio typed in by hand (Progress > Cardio > Log cardio).
public struct ManualCardio: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case run, walk, ride, hike, other
        public var name: String { rawValue.capitalized }
        public var icon: String {
            switch self {
            case .run: return "figure.run"
            case .walk: return "figure.walk"
            case .ride: return "figure.outdoor.cycle"
            case .hike: return "figure.hiking"
            case .other: return "heart.circle"
            }
        }
    }
    public var id: String
    public var date: Date
    public var kind: Kind
    public var minutes: Int
    /// Absolute program week it counts toward.
    public var week: Int

    public init(id: String = UUID().uuidString, date: Date, kind: Kind, minutes: Int, week: Int) {
        self.id = id; self.date = date; self.kind = kind; self.minutes = minutes; self.week = week
    }
}
