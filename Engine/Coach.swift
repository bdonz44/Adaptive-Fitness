import Foundation

public struct WeighIn: Codable, Equatable, Sendable {
    public var date: Date
    public var pounds: Double
    public init(date: Date, pounds: Double) { self.date = date; self.pounds = pounds }
}

public struct WaistEntry: Codable, Equatable, Sendable {
    public var date: Date
    public var inches: Double
    public init(date: Date, inches: Double) { self.date = date; self.inches = inches }
}

public struct CoachNote: Equatable, Sendable {
    public enum Kind: String, Sendable { case weight, cardio, strength }
    public var kind: Kind
    public var text: String
}

/// Turns weigh-ins, cardio and lifts into one to three plain-language adjustments.
public enum Coach {
    public static let weighInLimit = 120
    public static let waistLimit = 60

    public static func coachNotes(weighIns: [WeighIn], cardioByWeek: [Int: Int], week: Int,
                                  lifts: [String: LiftRecord], now: Date,
                                  cardioGoal: Int = Program.cardioGoalMinutes,
                                  catalog: Catalog = .bundled) -> [CoachNote] {
        var notes = [CoachNote(kind: .weight, text: weightTrend(weighIns: weighIns, now: now))]
        if let cardio = cardioNote(cardioByWeek: cardioByWeek, week: week, goal: cardioGoal) {
            notes.append(cardio)
        }
        if let strength = strengthNote(lifts: lifts, catalog: catalog) {
            notes.append(strength)
        }
        return notes
    }

    /// Weigh-ins from the last 28 days. Rate = (last - first) / days × 7.
    public static func weightTrend(weighIns: [WeighIn], now: Date) -> String {
        let cutoff = now.addingTimeInterval(-28 * 86400)
        let recent = weighIns.filter { $0.date >= cutoff && $0.date <= now }.sorted { $0.date < $1.date }
        guard recent.count >= 2, let first = recent.first, let last = recent.last else {
            return "Log your weight once or twice a week and this checks whether the fat loss is on pace."
        }
        let days = last.date.timeIntervalSince(first.date) / 86400
        if days < 10 {
            return "Keep weighing in. The trend check needs about 10 days."
        }
        let rate = (last.pounds - first.pounds) / days * 7
        if rate > -0.25 {
            return "Keep the lifting as is. Trim about 300 calories a day or add one more easy run."
        }
        if -rate > 0.01 * last.pounds {
            return "Eat a little more and keep protein high (about 1 g per pound of goal weight)."
        }
        return "Losing about \(String(format: "%.1f", -rate)) lb a week. Stay the course."
    }

    /// Last week's cardio: under 60% of goal = add an easy run on a non-leg day; otherwise praise.
    public static func cardioNote(cardioByWeek: [Int: Int], week: Int, goal: Int) -> CoachNote? {
        guard week > 1 else { return nil }
        let minutes = cardioByWeek[week - 1] ?? 0
        if Double(minutes) < 0.6 * Double(goal) {
            return CoachNote(kind: .cardio, text: "Cardio was \(minutes) of \(goal) min last week. Add an easy run on a non-leg day.")
        }
        return CoachNote(kind: .cardio, text: "\(minutes) min of cardio last week. Good work, keep it going.")
    }

    /// "N of M main lifts are heavier than where you started", plus any to watch
    /// (holds of 2 or more, or fails of 1 or more).
    public static func strengthNote(lifts: [String: LiftRecord], catalog: Catalog) -> CoachNote? {
        let mains = catalog.mainLifts.compactMap { ex -> (Exercise, LiftRecord)? in
            guard let rec = lifts[ex.id], rec.workingWeight != nil else { return nil }
            return (ex, rec)
        }
        guard !mains.isEmpty else { return nil }
        let heavier = mains.filter { _, rec in
            guard let now = rec.workingWeight,
                  let start = rec.firstWeight ?? rec.history.first?.weight else { return false }
            return now > start
        }.count
        var text = "\(heavier) of \(mains.count) main lifts are heavier than where you started."
        let watch = mains.filter { _, rec in rec.holds >= 2 || rec.fails >= 1 }.map { ex, _ in ex.name }
        if !watch.isEmpty {
            text += " One to watch: \(watch.joined(separator: ", "))."
        }
        return CoachNote(kind: .strength, text: text)
    }
}
