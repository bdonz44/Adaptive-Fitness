import Foundation

/// Plates to load on each side of a 45 lb bar.
public enum Plates {
    public static let bar: Double = 45
    public static let standard: [Double] = [45, 35, 25, 10, 5, 2.5]

    /// Largest plates first: 235 -> [45, 45, 5]. Empty for the bar alone or less.
    /// Any remainder smaller than the smallest plate is dropped.
    public static func perSide(_ total: Double, plates: [Double] = standard) -> [Double] {
        var left = (total - bar) / 2
        guard left > 0 else { return [] }
        var out: [Double] = []
        for p in plates.sorted(by: >) {
            while left >= p - 0.001 {
                out.append(p)
                left -= p
            }
        }
        return out
    }

    /// "45 + 45 + 5", or "Empty bar".
    public static func text(_ total: Double) -> String {
        let side = perSide(total)
        return side.isEmpty ? "Empty bar" : side.map(Fmt.lb).joined(separator: " + ")
    }
}

/// Where you are in a session and how it went.
public enum SessionInsights {
    public struct OpenSet: Equatable, Sendable {
        public var key: String
        public var set: Int
    }

    /// The next lift set to do, in session order. Superset partners alternate
    /// (B1 set 1, B2 set 1, B1 set 2...). Nil when every lift set is done.
    public static func nextOpenSet(session: Session, entries: [String: LoggedItem]) -> OpenSet? {
        let lifts = session.items.filter(\.isLift)
        var i = 0
        while i < lifts.count {
            var group = [lifts[i]]
            if let pair = lifts[i].pair {
                while i + group.count < lifts.count, lifts[i + group.count].pair == pair {
                    group.append(lifts[i + group.count])
                }
            }
            let rounds = group.map(\.sets).max() ?? 0
            for s in 0..<rounds {
                for item in group where s < item.sets {
                    let sets = entries[item.key]?.sets ?? []
                    if s >= sets.count || !sets[s].isDone { return OpenSet(key: item.key, set: s) }
                }
            }
            i += group.count
        }
        return nil
    }

    public struct Stats: Equatable, Sendable {
        public var setsDone: Int
        public var setsPlanned: Int
        /// Pounds × reps over finished sets with a weight (a ticked set with blank reps counts the top of the range).
        public var volume: Double
    }

    public static func stats(session: Session, entries: [String: LoggedItem]) -> Stats {
        var done = 0, planned = 0
        var volume = 0.0
        for item in session.items where item.isLift {
            planned += item.sets
            for set in entries[item.key]?.sets ?? [] where set.isDone {
                done += 1
                if let w = set.weight { volume += w * Double(set.reps ?? item.high) }
            }
        }
        return Stats(setsDone: done, setsPlanned: planned, volume: volume)
    }

    public struct Record: Equatable, Sendable {
        public var exerciseID: String
        public var weight: Double
        public var reps: Int
        public var e1RM: Double
        /// Estimated max gained over the previous best.
        public var gain: Double
    }

    /// Lifts whose newest history entry (logged at `date`) beats every earlier
    /// entry's estimated max. A lift's first-ever entry is not a record.
    public static func records(lifts: [String: LiftRecord], date: Date) -> [Record] {
        lifts.values.compactMap { rec -> Record? in
            guard let last = rec.history.last, last.date == date,
                  let w = last.weight, w > 0, let r = last.reps, r > 0 else { return nil }
            let earlier = rec.history.dropLast().compactMap { h -> Double? in
                guard let hw = h.weight, hw > 0, let hr = h.reps, hr > 0 else { return nil }
                return Suggestions.e1RM(weight: hw, reps: hr)
            }
            guard let best = earlier.max() else { return nil }
            let now = Suggestions.e1RM(weight: w, reps: r)
            guard now > best + 0.01 else { return nil }
            return Record(exerciseID: rec.exerciseID, weight: w, reps: r, e1RM: now, gain: now - best)
        }
        .sorted { $0.gain > $1.gain }
    }
}
