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

// MARK: - Home upgrades

extension HomeInsights {
    /// One line: WHOOP + the plan. "Green 78%, slept 7:40. Heavy Upper: Bench 195 × 5 is a PR. 52 min. Go."
    public static func brief(recovery: Int?, sleepHours: Double?, title: String, mainLine: String?, isPR: Bool,
                             minutes: Int, doneToday: Bool) -> String {
        var parts: [String] = []
        if let r = recovery {
            let zone = WhoopReadiness.zone(r)
            var s = "\(zone == .green ? "Green" : zone == .yellow ? "Yellow" : "Red") \(r)%"
            if let h = sleepHours {
                let m = Int((h * 60).rounded())
                s += ", slept \(m / 60):\(String(format: "%02d", m % 60))"
            }
            parts.append(s + ".")
        }
        if doneToday { return (parts + ["Work's done. Recover and come back hungry."]).joined(separator: " ") }
        var plan = "\(title)"
        if let m = mainLine { plan += ": \(m)\(isPR ? " is a PR" : "")" }
        parts.append(plan + ".")
        parts.append("\(minutes) min. Go.")
        return parts.joined(separator: " ")
    }

    /// Trained or not, for each of the last `days` days (oldest first, today last).
    public static func trainingDays(_ dates: [Date], now: Date, days: Int = 84, calendar: Calendar = .current) -> [Bool] {
        let set = Set(dates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().map { back in
            set.contains(calendar.date(byAdding: .day, value: -back, to: today)!)
        }
    }

    public static func daysSince(_ dates: [Date], now: Date, calendar: Calendar = .current) -> Int? {
        guard let last = dates.filter({ $0 <= now }).max() else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day
    }

    /// Estimated max over time for a lift (one point per logged session with weight and reps).
    public static func e1RMSeries(_ rec: LiftRecord?) -> [(date: Date, e1RM: Double)] {
        (rec?.history ?? []).compactMap { e in
            guard let w = e.weight, w > 0, let r = e.reps, r > 0 else { return nil }
            return (e.date, Suggestions.e1RM(weight: w, reps: r))
        }
    }

    /// Plate milestones for big barbell lifts.
    public static let milestones: [Double] = [135, 185, 225, 275, 315, 365, 405, 455, 495, 545, 585]

    /// "On pace for a 315 deadlift by Jan 12": a straight line through the last 8 sessions' estimated max.
    /// Nil when it isn't climbing or would take more than 6 months.
    public static func projection(_ series: [(date: Date, e1RM: Double)], now: Date) -> (target: Double, date: Date)? {
        let pts = Array(series.suffix(8))
        guard pts.count >= 4, let first = pts.first else { return nil }
        let xs = pts.map { $0.date.timeIntervalSince(first.date) / 86400 }
        let ys = pts.map(\.e1RM)
        let n = Double(pts.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        let sxx = zip(xs, xs).map { ($0 - mx) * ($1 - mx) }.reduce(0, +)
        guard sxx > 0 else { return nil }
        let slope = zip(xs, ys).map { ($0 - mx) * ($1 - my) }.reduce(0, +) / sxx   // lb per day
        guard slope > 0.01 else { return nil }
        let best = ys.max()!
        guard let target = milestones.first(where: { $0 > best }) else { return nil }
        let intercept = my - slope * mx
        let day = (target - intercept) / slope
        let date = first.date.addingTimeInterval(day * 86400)
        guard date > now, date < now.addingTimeInterval(183 * 86400) else { return nil }
        return (target, date)
    }

    /// Sessions left in the 12 weeks and, at your recent pace, when you'll finish.
    public static func finishLine(week: ProgramWeek, doneThisWeek: Int, perWeek: Int, recentLogDates: [Date],
                                  now: Date) -> (left: Int, date: Date?) {
        let left = max(0, (12 - week.wk) * perWeek + (perWeek - doneThisWeek))
        let lastMonth = recentLogDates.filter { $0 > now.addingTimeInterval(-28 * 86400) && $0 <= now }.count
        guard lastMonth >= 2 else { return (left, nil) }
        let perDay = Double(lastMonth) / 28
        return (left, now.addingTimeInterval(Double(left) / perDay * 86400))
    }
}
