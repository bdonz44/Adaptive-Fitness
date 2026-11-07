import Foundation

/// Adaptive 6: nutrition numbers from the weight trend.
/// Protein 1 g per lb of goal weight. Calories: -300 a day when the weight has been flat
/// (or rising) for 14+ days above goal, +200 when losing more than 1% a week.
public enum Nutrition {
    public struct Settings: Codable, Equatable, Sendable {
        public var goalWeight: Double?
        /// What you eat on a normal day now (optional), so the advice can be a number.
        public var currentCalories: Int?
        public init(goalWeight: Double? = nil, currentCalories: Int? = nil) {
            self.goalWeight = goalWeight; self.currentCalories = currentCalories
        }
    }

    public enum Call: Equatable, Sendable { case needData, cut, add, hold, atGoal }

    public struct Advice: Equatable, Sendable {
        public var proteinGrams: Int?
        /// Change to daily calories: -300, +200 or 0.
        public var calorieChange: Int
        /// Daily calories to aim for (when current calories are known).
        public var calorieTarget: Int?
        /// Pounds per week (negative = losing), from the last 28 days.
        public var ratePerWeek: Double?
        public var call: Call
        public var headline: String
        public var detail: String
    }

    public static let cut = -300
    public static let add = 200

    public static func advice(weighIns: [WeighIn], settings: Settings, now: Date) -> Advice {
        let recent = weighIns.filter { $0.date >= now.addingTimeInterval(-28 * 86400) && $0.date <= now }
            .sorted { $0.date < $1.date }
        let latest = weighIns.filter { $0.date <= now }.max { $0.date < $1.date }?.pounds
        let goal = settings.goalWeight
        let protein = (goal ?? latest).map { Int($0.rounded()) }
        func make(_ change: Int, _ rate: Double?, _ call: Call, _ headline: String, _ detail: String) -> Advice {
            Advice(proteinGrams: protein, calorieChange: change,
                   calorieTarget: settings.currentCalories.map { $0 + change }, ratePerWeek: rate,
                   call: call, headline: headline, detail: detail)
        }
        guard let first = recent.first, let last = recent.last,
              last.date.timeIntervalSince(first.date) >= 14 * 86400 else {
            return make(0, nil, .needData, "Weigh in twice a week",
                        "The calorie call needs about two weeks of weigh-ins. Hit your protein every day until then.")
        }
        let days = last.date.timeIntervalSince(first.date) / 86400
        let rate = (last.pounds - first.pounds) / days * 7
        if let goal, last.pounds <= goal + 1 {
            return make(0, rate, .atGoal, "At your goal. Hold it.",
                        "Eat what you've been eating and keep the lifting heavy.")
        }
        if rate > -0.25 {
            return make(cut, rate, .cut, "Flat for two weeks. Cut 300 a day.",
                        "The scale isn't moving. Take 300 calories a day out: it's one snack or a smaller dinner portion. Protein stays high.")
        }
        if -rate > 0.01 * last.pounds {
            return make(add, rate, .add, "Losing too fast. Add 200 a day.",
                        "Over 1% a week costs muscle. Add 200 calories a day, mostly protein and carbs around training.")
        }
        return make(0, rate, .hold, "On pace. Don't change a thing.",
                    "Losing about \(String(format: "%.1f", -rate)) lb a week. Same food, same training.")
    }
}

/// Food logged today (protein and calories), one entry per quick add.
public struct FoodEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var date: Date
    public var protein: Int
    public var calories: Int
    public init(id: String = UUID().uuidString, date: Date, protein: Int, calories: Int) {
        self.id = id; self.date = date; self.protein = protein; self.calories = calories
    }
}

extension Nutrition {
    public static let quickProtein = [10, 20, 30, 40, 50]

    /// Protein and calories logged on the same day as `date`.
    public static func totals(_ entries: [FoodEntry], on date: Date, calendar: Calendar = .current) -> (protein: Int, calories: Int) {
        let day = entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
        return (day.reduce(0) { $0 + $1.protein }, day.reduce(0) { $0 + $1.calories })
    }

    /// "92 / 185 g"
    public static func progressText(_ done: Int, of target: Int?, unit: String) -> String {
        target.map { "\(done) / \($0) \(unit)" } ?? "\(done) \(unit)"
    }
}
