import Foundation

/// Pounds lifted: weight × reps over every finished set with a weight.
public enum Volume {
    /// A logged session's pounds. `highFor` gives an item's top reps (used when a ticked set
    /// has no reps typed, which logs the top of the range); 8 when unknown.
    public static func of(entries: [String: LoggedItem], highFor: (String) -> Int? = { _ in nil }) -> Double {
        var total = 0.0
        for (key, item) in entries where key != SessionHeart.entryKey && item.skipped == nil {
            for s in item.sets where s.isDone {
                guard let w = s.weight, w.isFinite, w > 0, w < 2000 else { continue }
                let reps = s.reps ?? s.plannedReps ?? highFor(key) ?? 8
                guard reps > 0, reps < 200 else { continue }
                total += w * Double(reps)
            }
        }
        return total
    }

    /// Monday-start weeks, newest last: (week start, pounds) for the last `weeks` weeks.
    public static func byWeek(_ sessions: [(date: Date, pounds: Double)], now: Date, weeks: Int = 12,
                              calendar: Calendar = .current) -> [(start: Date, pounds: Double)] {
        var cal = calendar
        cal.firstWeekday = 2
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        return (0..<weeks).reversed().map { back in
            let start = cal.date(byAdding: .weekOfYear, value: -back, to: thisWeek) ?? thisWeek
            let end = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            let lb = sessions.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.pounds }
            return (start, lb)
        }
    }

    /// "1.2M", "86.4k", "950"
    public static func short(_ pounds: Double) -> String {
        guard pounds.isFinite else { return "–" }
        if pounds >= 1_000_000 { return String(format: "%.1fM", pounds / 1_000_000) }
        if pounds >= 10_000 { return String(format: "%.0fk", pounds / 1_000) }
        if pounds >= 1_000 { return String(format: "%.1fk", pounds / 1_000) }
        return String(Int(pounds.rounded()))
    }

    static let things: [(name: String, plural: String, pounds: Double)] = [
        ("grand piano", "grand pianos", 1_000),
        ("pickup truck", "pickup trucks", 5_000),
        ("African elephant", "African elephants", 13_000),
        ("school bus", "school buses", 25_000),
        ("Boeing 737", "Boeing 737s", 90_000),
        ("blue whale", "blue whales", 330_000),
        ("Statue of Liberty", "Statues of Liberty", 450_000),
        ("space shuttle at launch", "space shuttles at launch", 4_500_000),
    ]

    /// "That's 2.7 Statues of Liberty." (the biggest thing you've passed at least once).
    public static func comparison(_ pounds: Double) -> String? {
        guard let t = things.last(where: { pounds >= $0.pounds }) else { return nil }
        let n = pounds / t.pounds
        if n < 1.05 { return "That's a \(t.name)." }
        return "That's \(n < 10 ? String(format: "%.1f", n) : String(Int(n))) \(t.plural)."
    }
}
