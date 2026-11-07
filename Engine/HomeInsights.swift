import Foundation

/// The Home screen's numbers: streak, the coach line of the day, the next PR to chase,
/// and how far you've come.
public enum HomeInsights {
    // MARK: Streak

    /// Full weeks in a row (every session logged), counting back from last week.
    /// `logged`: (slot, absolute week) of every log; the optional run doesn't count.
    public static func streak(logged: [(slot: String, week: Int)], currentWeek: Int, sessionsPerWeek: Int) -> Int {
        var byWeek: [Int: Set<String>] = [:]
        for l in logged where l.slot != Slot.R.rawValue { byWeek[l.week, default: []].insert(l.slot) }
        var n = 0
        var w = currentWeek - 1
        while w >= 1, (byWeek[w]?.count ?? 0) >= sessionsPerWeek {
            n += 1
            w -= 1
        }
        return n
    }

    // MARK: Next PR

    /// For today's main lift: the planned weight × top reps, when that beats your best estimated max.
    public static func prChase(item: SessionItem, weight: Double?, record: LiftRecord?) -> String? {
        guard item.isLift, item.unit == .reps, let w = weight, w > 0, let best = Suggestions.best1RM(record) else { return nil }
        let target = Suggestions.e1RM(weight: w, reps: item.high)
        guard target > best + 0.5 else { return nil }
        return "\(item.name) \(Fmt.lb(w)) × \(item.high) would be a new best."
    }

    // MARK: Since you started

    public struct Since: Equatable, Sendable {
        public var lines: [String]
    }

    /// "+40 lb squat", "-11 lb bodyweight", "-2 in waist" (only what has data, biggest lift gain first).
    public static func sinceStart(lifts: [String: LiftRecord], weighIns: [WeighIn], waist: [WaistEntry],
                                  catalog: Catalog = .bundled) -> [String] {
        var out: [String] = []
        let gains = catalog.mainLifts.compactMap { ex -> (String, Double)? in
            guard let rec = lifts[ex.id], let now = rec.workingWeight,
                  let start = rec.firstWeight ?? rec.history.first?.weight, now > start else { return nil }
            return (ex.name.lowercased(), now - start)
        }.sorted { $0.1 > $1.1 }
        if let top = gains.first { out.append("+\(Fmt.lb(top.1)) lb \(top.0)") }
        let w = weighIns.sorted { $0.date < $1.date }
        if let first = w.first, let last = w.last, w.count > 1, abs(last.pounds - first.pounds) >= 0.5 {
            out.append(Tracking.changeText(last.pounds - first.pounds, unit: "lb") + " bodyweight")
        }
        let wa = waist.sorted { $0.date < $1.date }
        if let first = wa.first, let last = wa.last, wa.count > 1, abs(last.inches - first.inches) >= 0.25 {
            out.append(Tracking.changeText(last.inches - first.inches, unit: "in") + " waist")
        }
        return out
    }

    // MARK: Coach line of the day

    public struct Facts: Sendable {
        public var cardioMinutes: Int
        public var cardioGoal: Int
        public var sessionsDone: Int
        public var sessionsPerWeek: Int
        public var streak: Int
        public var liftsUpLately: [String]
        public var hardMinutes: Double
        public var isDeload: Bool
        public var doneToday: Bool
        public init(cardioMinutes: Int, cardioGoal: Int, sessionsDone: Int, sessionsPerWeek: Int, streak: Int,
                    liftsUpLately: [String], hardMinutes: Double, isDeload: Bool, doneToday: Bool) {
            self.cardioMinutes = cardioMinutes; self.cardioGoal = cardioGoal; self.sessionsDone = sessionsDone
            self.sessionsPerWeek = sessionsPerWeek; self.streak = streak; self.liftsUpLately = liftsUpLately
            self.hardMinutes = hardMinutes; self.isDeload = isDeload; self.doneToday = doneToday
        }
    }

    /// Lifts whose working weight went up in their last 3 logged sessions.
    public static func risingLifts(_ lifts: [String: LiftRecord], catalog: Catalog = .bundled) -> [String] {
        lifts.compactMap { id, rec -> String? in
            let ws = rec.history.suffix(3).compactMap(\.weight)
            guard ws.count == 3, ws[0] < ws[1], ws[1] < ws[2] else { return nil }
            return catalog.exercise(id)?.name
        }.sorted()
    }

    /// Every line that applies today; the screen shows one, changing by day.
    public static func coachLines(_ f: Facts) -> [String] {
        var lines: [String] = []
        if f.doneToday { lines.append("Work's done today. Eat your protein, sleep 7+ hours, and come back hungry.") }
        if let lift = f.liftsUpLately.first {
            lines.append("\(lift) has gone up three sessions straight. Don't you dare stop now.")
        }
        if f.streak >= 2 { lines.append("\(f.streak) full weeks in a row. That's who you are now. Keep it alive.") }
        let short = f.cardioGoal - f.cardioMinutes
        if short > 0 && short <= f.cardioGoal / 2 { lines.append("Cardio is \(short) minutes short. Get a walk in today.") }
        if short > f.cardioGoal / 2 { lines.append("Cardio's behind: \(f.cardioMinutes) of \(f.cardioGoal). Easy miles count. Go.") }
        if f.isDeload { lines.append("Back-off week. Lighter weights, perfect reps. Next week you hit harder.") }
        let left = f.sessionsPerWeek - f.sessionsDone
        if left > 0 && !f.doneToday { lines.append("\(left) session\(left == 1 ? "" : "s") left this week. Nobody's doing them for you.") }
        if f.hardMinutes >= 30 { lines.append("\(Int(f.hardMinutes.rounded())) minutes in zone 4-5 this week. That's how VO2 max climbs.") }
        if lines.isEmpty { lines.append("Show up, do the work, log it. That's the whole secret.") }
        return lines
    }

    public static func lineOfTheDay(_ f: Facts, date: Date, calendar: Calendar = .current) -> String {
        let lines = coachLines(f)
        if f.doneToday { return lines[0] }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return lines[day % lines.count]
    }
}
