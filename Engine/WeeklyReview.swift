import Foundation

/// Adaptive 8: the Sunday review. The last 7 days on one screen, and what's next.
public struct WeeklyReview: Equatable, Sendable {
    public struct Session: Equatable, Sendable {
        public var date: Date
        public var title: String
        public var heart: SessionHeart?
        public init(date: Date, title: String, heart: SessionHeart?) { self.date = date; self.title = title; self.heart = heart }
    }
    public struct LiftUp: Equatable, Sendable { public var name: String; public var from: Double; public var to: Double }
    public struct Record: Equatable, Sendable { public var name: String; public var weight: Double; public var reps: Int }

    public var start: Date
    public var end: Date
    public var sessions: [Session]
    public var sessionsPlanned: Int
    public var cardioMinutes: Int
    public var hardMinutes: Double
    public var strain: Double?
    public var liftsUp: [LiftUp]
    public var records: [Record]
    public var weightChange: Double?
    public var latestWeight: Double?
    public var waistChange: Double?
    public var nextWeek: String
    public var verdict: String

    /// A logged session as the review sees it.
    public struct Log: Sendable {
        public var date: Date
        public var title: String
        public var cardioMinutes: Int
        public var heart: SessionHeart?
        public var counts: Bool
        public init(date: Date, title: String, cardioMinutes: Int, heart: SessionHeart?, counts: Bool = true) {
            self.date = date; self.title = title; self.cardioMinutes = cardioMinutes; self.heart = heart; self.counts = counts
        }
    }

    public static func build(now: Date, logs: [Log], lifts: [String: LiftRecord], weighIns: [WeighIn],
                             waist: [WaistEntry], state: ProgramState, catalog: Catalog = .bundled,
                             calendar: Calendar = .current) -> WeeklyReview {
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let inWeek = logs.filter { $0.date >= start && $0.date <= now }.sorted { $0.date < $1.date }
        let counted = inWeek.filter(\.counts)
        let hearts = inWeek.compactMap(\.heart)
        let strains = hearts.compactMap(\.strain)

        var up: [LiftUp] = []
        var prs: [Record] = []
        for (id, rec) in lifts {
            let before = rec.history.filter { $0.date < start }
            let during = rec.history.filter { $0.date >= start && $0.date <= now }
            guard !during.isEmpty else { continue }
            let name = catalog.exercise(id)?.name ?? id
            if let prev = before.last?.weight, let top = during.compactMap(\.weight).max(), top > prev {
                up.append(LiftUp(name: name, from: prev, to: top))
            }
            func best(_ es: [HistoryEntry]) -> (Double, HistoryEntry)? {
                es.compactMap { e -> (Double, HistoryEntry)? in
                    guard let w = e.weight, w > 0, let r = e.reps, r > 0 else { return nil }
                    return (Suggestions.e1RM(weight: w, reps: r), e)
                }.max { $0.0 < $1.0 }
            }
            if let now = best(during), let old = best(before), now.0 > old.0 + 0.5 {
                prs.append(Record(name: name, weight: now.1.weight ?? 0, reps: now.1.reps ?? 0))
            }
        }

        func change<T>(_ list: [T], date: (T) -> Date, value: (T) -> Double) -> (Double, Double)? {
            let sorted = list.sorted { date($0) < date($1) }
            guard let latest = sorted.last(where: { date($0) <= now && date($0) >= start }) else { return nil }
            let base = sorted.last(where: { date($0) < start }) ?? sorted.first(where: { date($0) >= start })
            guard let base, date(base) != date(latest) else { return (0, value(latest)) }
            return (value(latest) - value(base), value(latest))
        }
        let w = change(weighIns, date: \.date, value: \.pounds)
        let wa = change(waist, date: \.date, value: \.inches)

        let planned = state.order.count
        let done = counted.count
        let verdict: String
        if done >= planned {
            verdict = "Every session done. That's how it's built. Now do it again."
        } else if done == planned - 1 {
            verdict = "One session short. Don't let that become a habit."
        } else if done == 0 {
            verdict = "Nothing logged this week. Tomorrow you start again. No more excuses."
        } else {
            verdict = "\(planned - done) sessions short. This week, every one gets done."
        }

        let pw = state.programWeek
        var next = "\(state.program.name) · Week \(pw.wk) of 12 · \(state.program.phaseName(pw.phase))"
        if pw.isDeload { next += " · back-off week" }
        let left = state.order.filter { !state.isDone($0) }
        if left.count < state.order.count && !left.isEmpty {
            next += ". Still to do: " + left.map { state.slotName($0) }.joined(separator: ", ")
        } else if let first = left.first {
            next += ". First up: \(state.slotName(first))"
        }

        return WeeklyReview(
            start: start, end: now,
            sessions: counted.map { Session(date: $0.date, title: $0.title, heart: $0.heart) },
            sessionsPlanned: planned,
            cardioMinutes: inWeek.reduce(0) { $0 + $1.cardioMinutes },
            hardMinutes: hearts.reduce(0) { $0 + $1.hardMinutes },
            strain: strains.isEmpty ? nil : strains.reduce(0, +),
            liftsUp: up.sorted { $0.to - $0.from > $1.to - $1.from },
            records: prs.sorted { $0.name < $1.name },
            weightChange: w?.0, latestWeight: w?.1, waistChange: wa?.0,
            nextWeek: next + ".", verdict: verdict)
    }
}
