import Foundation

/// "What works for you": your WHOOP history against how you actually lift.
/// Each session gets a score: estimated max that day ÷ your best before it (1.0 = matched your best).
public enum Insights {
    public struct Day: Codable, Equatable, Sendable {
        /// Start of the calendar day.
        public var date: Date
        public var recovery: Int?
        public var sleepHours: Double?
        public init(date: Date, recovery: Int?, sleepHours: Double?) {
            self.date = date; self.recovery = recovery; self.sleepHours = sleepHours
        }
    }

    public struct Session: Equatable, Sendable {
        public var date: Date
        public var score: Double
        public init(date: Date, score: Double) { self.date = date; self.score = score }
    }

    public struct Insight: Equatable, Identifiable, Sendable {
        public var id: String
        public var headline: String
        public var detail: String
    }

    static let minGroup = 3
    static let minGap = 0.02

    /// One score per training day from the lifts' history.
    public static func sessions(_ lifts: [String: LiftRecord], calendar: Calendar = .current) -> [Session] {
        var byDay: [Date: (sum: Double, n: Int, time: Date)] = [:]
        for rec in lifts.values {
            var best: Double? = nil
            for e in rec.history.sorted(by: { $0.date < $1.date }) {
                guard let w = e.weight, w > 0, let r = e.reps, r > 0 else { continue }
                let est = Suggestions.e1RM(weight: w, reps: r)
                if let b = best {
                    let day = calendar.startOfDay(for: e.date)
                    let cur = byDay[day] ?? (0, 0, e.date)
                    byDay[day] = (cur.sum + est / b, cur.n + 1, max(cur.time, e.date))
                }
                best = max(best ?? 0, est)
            }
        }
        return byDay.map { Session(date: $0.value.time, score: $0.value.sum / Double($0.value.n)) }.sorted { $0.date < $1.date }
    }

    public static func compute(sessions: [Session], days: [Day], calendar: Calendar = .current) -> [Insight] {
        let dayFor = Dictionary(days.map { (calendar.startOfDay(for: $0.date), $0) }, uniquingKeysWith: { a, _ in a })
        func day(_ s: Session) -> Day? { dayFor[calendar.startOfDay(for: s.date)] }
        func avg(_ xs: [Double]) -> Double? { xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count) }
        func pct(_ a: Double, _ b: Double) -> Int { Int(((a / b - 1) * 100).rounded()) }
        var out: [Insight] = []

        // Recovery zone vs performance.
        let green = sessions.filter { (day($0)?.recovery ?? -1) >= 67 }.map(\.score)
        let notGreen = sessions.filter { r in day(r)?.recovery.map { $0 < 67 } ?? false }.map(\.score)
        if green.count >= minGroup, notGreen.count >= minGroup, let g = avg(green), let n = avg(notGreen), abs(g / n - 1) >= minGap {
            out.append(Insight(id: "recovery",
                               headline: g > n ? "Green days: you lift \(pct(g, n))% stronger" : "Your recovery score doesn't slow you down",
                               detail: g > n ? "On green WHOOP days your lifts run \(pct(g, n))% closer to your best than on yellow or red days. Save PR attempts for green."
                                             : "You lift \(pct(n, g))% better on yellow/red days than green ones. Don't let a low score talk you out of training."))
        }

        // Sleep vs performance.
        let long = sessions.filter { (day($0)?.sleepHours ?? 0) >= 7.5 }.map(\.score)
        let short = sessions.filter { s in day(s)?.sleepHours.map { $0 < 7 } ?? false }.map(\.score)
        if long.count >= minGroup, short.count >= minGroup, let l = avg(long), let s = avg(short), abs(l / s - 1) >= minGap {
            out.append(Insight(id: "sleep",
                               headline: l > s ? "7.5+ hours of sleep is worth \(pct(l, s))%" : "Sleep length isn't what's moving your lifts",
                               detail: l > s ? "After 7.5+ hours you lift \(pct(l, s))% better than after under 7. Sleep is a training session."
                                             : "Your short-sleep days have been as strong as long ones so far. Keep logging; the pattern may change."))
        }

        // PRs and sleep.
        let prSleep = sessions.filter { $0.score > 1.0 }.compactMap { day($0)?.sleepHours }
        let otherSleep = sessions.filter { $0.score <= 1.0 }.compactMap { day($0)?.sleepHours }
        if prSleep.count >= minGroup, otherSleep.count >= minGroup, let p = avg(prSleep), let o = avg(otherSleep), p - o >= 0.25 {
            out.append(Insight(id: "pr-sleep", headline: "Your PRs come after \(hm(p)) of sleep",
                               detail: "Sessions where you beat your best followed \(hm(p)) of sleep on average, vs \(hm(o)) the rest of the time."))
        }

        // Time of day.
        let morning = sessions.filter { calendar.component(.hour, from: $0.date) < 12 }.map(\.score)
        let evening = sessions.filter { calendar.component(.hour, from: $0.date) >= 17 }.map(\.score)
        if morning.count >= minGroup, evening.count >= minGroup, let m = avg(morning), let e = avg(evening), abs(m / e - 1) >= minGap {
            let better = m > e ? "morning" : "evening"
            out.append(Insight(id: "time", headline: "You're stronger in the \(better)",
                               detail: "Your \(better) sessions run \(pct(max(m, e), min(m, e)))% closer to your best. Train then when you can."))
        }

        // Late training vs next-morning recovery.
        let next: (Session) -> Int? = { s in
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: s.date)).flatMap { dayFor[$0]?.recovery }
        }
        let late = sessions.filter { calendar.component(.hour, from: $0.date) >= 19 }.compactMap(next).map(Double.init)
        let early = sessions.filter { calendar.component(.hour, from: $0.date) < 19 }.compactMap(next).map(Double.init)
        if late.count >= minGroup, early.count >= minGroup, let lt = avg(late), let er = avg(early), er - lt >= 5 {
            out.append(Insight(id: "late", headline: "Late workouts cost you \(Int((er - lt).rounded())) recovery points",
                               detail: "Finishing after 7 pm, your next-morning WHOOP recovery averages \(Int(lt.rounded()))% vs \(Int(er.rounded()))% after earlier sessions."))
        }
        return out
    }

    static func hm(_ hours: Double) -> String {
        let m = Int((hours * 60).rounded())
        return "\(m / 60)h \(String(format: "%02d", m % 60))m"
    }
}
