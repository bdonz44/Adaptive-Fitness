import Foundation

/// Adaptive 2: time-boxed sessions. Estimate a session's minutes and trim it to fit.
public enum TimeBox {
    public static let choices = [20, 30, 45, 60]
    static let workSeconds = 45
    static let warmUpMinutes = 5.0

    /// Lifts: sets × (45 sec work + rest). Cardio: rounds × minutes per round.
    /// Plus a 5 minute warm-up when there's a main lift.
    public static func minutes(_ session: Session) -> Int {
        var seconds = 0.0
        for item in session.items {
            if item.isLift {
                seconds += Double(item.sets * (workSeconds + item.restSeconds))
            } else if item.isCardio {
                seconds += Double(item.rounds ?? item.high) * (item.minutesPerRound ?? 1) * 60
            }
        }
        if session.items.contains(where: { $0.kind == .main }) { seconds += warmUpMinutes * 60 }
        return Int((seconds / 60).rounded())
    }

    /// Trims in order until it fits: finisher, third superset pair, one set off each accessory,
    /// second pair, then main sets (never below 2), then engine rounds (never below half). Items in `keep` (already logged) are left alone,
    /// and so are exercises added by hand.
    public static func fit(_ session: Session, minutes budget: Int, keep: Set<String> = []) -> Session {
        var s = session
        var notes: [String] = []
        func over() -> Bool { minutes(s) > budget }
        func removable(_ i: SessionItem) -> Bool { !keep.contains(i.key) && !i.isExtra }
        func remove(_ match: (SessionItem) -> Bool) {
            s.blocks = s.blocks.map { b in
                var b = b
                b.items.removeAll(where: match)
                return b
            }.filter { !$0.items.isEmpty }
        }
        func edit(_ change: (inout SessionItem) -> Void) {
            for bi in s.blocks.indices {
                for ii in s.blocks[bi].items.indices { change(&s.blocks[bi].items[ii]) }
            }
        }
        func dropPair(_ pair: Int) -> Bool {
            let items = s.items.filter { $0.kind == .accessory && $0.pair == pair }
            guard !items.isEmpty, items.allSatisfy(removable) else { return false }
            remove { $0.kind == .accessory && $0.pair == pair }
            return true
        }

        // 1. Finisher
        if over(), let fin = s.items.first(where: { $0.kind == .finisher }), removable(fin) {
            remove { $0.key == fin.key }
            notes.append("finisher")
        }
        // 2. Third superset pair
        if over(), dropPair(2) { notes.append("third pair") }
        // 3. One set off each accessory
        if over() {
            var changed = false
            edit { item in
                if item.kind == .accessory, item.pair != nil, removable(item), item.sets > 1 {
                    item.sets -= 1
                    changed = true
                }
            }
            if changed { notes.append("one set off each accessory") }
        }
        // 4. Second pair
        if over(), dropPair(1) { notes.append("second pair") }
        // 5. Main lift sets, down to 2
        if let main = s.items.first(where: { $0.kind == .main }), removable(main) {
            let start = main.sets
            while over(), let m = s.item(main.key), m.sets > 2 {
                edit { if $0.kind == .main { $0.sets -= 1 } }
            }
            if let m = s.item(main.key), m.sets < start { notes.append("main lift to \(m.sets) sets") }
        }

        // 6. Engine rounds (Conditioning), down to half. Not in the spec's list; added so 20 min can fit.
        if let eng = s.items.first(where: { $0.kind == .engine }), removable(eng), let start = eng.rounds {
            let floor = (start + 1) / 2
            while over(), let r = s.item(eng.key)?.rounds, r > floor {
                edit { if $0.kind == .engine { $0.rounds = r - 1; $0.low = r - 1; $0.high = r - 1 } }
            }
            if let r = s.item(eng.key)?.rounds, r < start { notes.append("\(r) engine rounds") }
        }

        s.budget = budget
        s.trims = notes
        return s
    }

    /// "Trimmed to fit 30 min: finisher, third pair." or nil when nothing changed.
    public static func summary(_ session: Session) -> String? {
        guard let budget = session.budget else { return nil }
        let est = minutes(session)
        var text = "About \(est) min."
        if !session.trims.isEmpty {
            text += " Cut to fit \(budget): " + session.trims.joined(separator: ", ") + "."
        }
        if est > budget { text += " That's as short as it goes." }
        return text
    }
}
