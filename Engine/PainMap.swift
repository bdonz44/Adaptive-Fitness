import Foundation

// MARK: - Pain map: sore spots change the training around them

public enum BodyArea: String, Codable, CaseIterable, Sendable {
    case shoulder, elbow, wrist, lowerBack, hip, knee, ankle

    public var name: String {
        switch self {
        case .lowerBack: return "Lower back"
        default: return rawValue.capitalized
        }
    }
}

public struct SoreSpot: Codable, Equatable, Identifiable, Sendable {
    public var area: BodyArea
    public var since: Date
    /// When you last said how it feels (asked again 3 days later).
    public var lastCheck: Date
    public var id: String { area.rawValue }
    public init(area: BodyArea, since: Date) { self.area = area; self.since = since; self.lastCheck = since }
}

public enum PainMap {
    public static let checkEveryDays = 3.0

    /// Areas a lift loads. Specific lifts first, then the category.
    public static func loads(_ ex: Exercise) -> Set<BodyArea> {
        if let s = byID[ex.id] { return s }
        return byCategory[ex.category] ?? []
    }

    static let byID: [String: Set<BodyArea>] = [
        "squat": [.knee, .hip, .lowerBack], "fsquat": [.knee, .hip, .wrist],
        "bench": [.shoulder, .elbow, .wrist], "incline": [.shoulder, .elbow, .wrist], "floorpress": [.elbow, .wrist],
        "ohp": [.shoulder, .elbow, .wrist, .lowerBack], "pushpress": [.shoulder, .elbow, .wrist, .knee],
        "deadlift": [.lowerBack, .hip], "hipthrust": [.hip], "slrdl": [.lowerBack, .hip, .ankle],
        "kbswingh": [.lowerBack, .hip], "goodmorning": [.lowerBack, .hip],
        "gobletsq": [.knee, .hip], "splitsq": [.knee, .hip, .ankle], "stepup": [.knee, .ankle],
        "lunge": [.knee, .hip, .ankle], "bulgarian": [.knee, .hip, .ankle], "revlunge": [.knee, .hip],
        "plank": [], "deadbug": [], "hollow": [], "sideplank": [.shoulder], "suitcase": [.lowerBack, .wrist],
        "bearcrawl": [.wrist, .shoulder],
        "lateral": [.shoulder], "reardelt": [.shoulder], "arnold": [.shoulder, .elbow], "dbpress": [.shoulder, .elbow],
        "kbbottoms": [.shoulder, .elbow, .wrist],
        "pushup": [.shoulder, .wrist, .elbow], "deficitpu": [.shoulder, .wrist, .elbow], "dbincline": [.shoulder, .elbow],
        "dbfly": [.shoulder, .elbow], "dbfloor": [.elbow],
        "cgpushup": [.elbow, .wrist], "ohtri": [.elbow, .shoulder],
        "bbrow": [.lowerBack, .elbow], "pendlay": [.lowerBack, .elbow], "gorilla": [.lowerBack, .elbow],
        "dbrow": [.elbow], "csrow": [.elbow], "renegade": [.wrist, .shoulder, .elbow],
        "thruster": [.knee, .shoulder, .wrist], "kbcp": [.shoulder, .wrist, .lowerBack], "squatpress": [.knee, .shoulder, .wrist],
        "kbswing": [.lowerBack, .hip], "burpee": [.wrist, .shoulder, .knee, .ankle],
        "trxrow": [.elbow], "trxsarow": [.elbow], "trxpress": [.shoulder, .wrist], "trxpushup": [.shoulder, .wrist],
        "trxyfly": [.shoulder], "trxtfly": [.shoulder], "trxfacepull": [.shoulder], "trxcurl": [.elbow], "trxtricep": [.elbow],
        "trxsquat": [.knee], "trxpistol": [.knee, .ankle], "trxlunge": [.knee], "trxhamcurl": [.knee, .hip],
        "trxpike": [.shoulder, .wrist], "trxtuck": [.shoulder, .wrist], "trxplank": [.shoulder], "trxsideplank": [.shoulder],
        "trxclimber": [.shoulder, .wrist], "trxchestfly": [.shoulder, .elbow], "trxatomic": [.shoulder, .wrist],
        "trxfallout": [.shoulder, .lowerBack], "trxbodysaw": [.shoulder], "trxoblique": [.shoulder, .wrist],
        "trxpowerpull": [.shoulder, .elbow], "trxhighrow": [.shoulder, .elbow], "trxhippress": [.hip],
        "trxsprinter": [.knee, .ankle], "trxsquatrow": [.knee, .elbow], "trxsideplankreach": [.shoulder],
        "russiantwist": [.lowerBack], "woodchop": [.lowerBack, .shoulder], "kbwindmill": [.shoulder, .lowerBack],
        "getup": [.shoulder, .wrist], "shouldertap": [.wrist, .shoulder], "copenhagen": [.hip], "bearhold": [.wrist, .shoulder],
        "pullup": [.shoulder, .elbow], "chinup": [.shoulder, .elbow],
        "pausesquat": [.knee, .hip, .lowerBack], "pausebench": [.shoulder, .elbow, .wrist], "cgbench": [.elbow, .wrist, .shoulder],
        "deficitdl": [.lowerBack, .hip], "cleanpull": [.lowerBack, .hip, .wrist],
        "powerclean": [.wrist, .shoulder, .elbow, .lowerBack, .knee], "hangclean": [.wrist, .shoulder, .elbow, .lowerBack],
        "powersnatch": [.wrist, .shoulder, .lowerBack, .knee], "hangsnatch": [.wrist, .shoulder, .lowerBack],
    ]

    static let byCategory: [String: Set<BodyArea>] = [
        "main": [.shoulder, .elbow, .wrist, .lowerBack, .hip, .knee], "hinge": [.lowerBack, .hip], "quad": [.knee, .hip],
        "delt": [.shoulder], "chest": [.shoulder, .elbow], "bicep": [.elbow, .wrist], "tricep": [.elbow],
        "row": [.elbow], "full": [.shoulder, .knee, .wrist], "power": [.wrist, .shoulder, .elbow, .lowerBack, .knee],
        "pull": [.shoulder, .elbow], "core": [], "abs": [], "trx": [.shoulder],
    ]

    /// Swaps today's lifts that load a sore area for ones that don't (and that your gear allows);
    /// a lift with nothing that spares the area is taken out for today. Lifts with logged sets stay.
    /// Returns a line per change.
    @discardableResult
    public static func adjust(_ session: inout Session, sore: Set<BodyArea>, keep: Set<String>,
                              catalog: Catalog = .bundled, gear: GearProfile = .standard) -> [String] {
        guard !sore.isEmpty else { return [] }
        var notes: [String] = []
        var used = Set(session.items.compactMap(\.exerciseID))
        for bi in session.blocks.indices.reversed() {
            for ii in session.blocks[bi].items.indices.reversed() {
                let item = session.blocks[bi].items[ii]
                guard item.isLift, !keep.contains(item.key), let id = item.exerciseID, let ex = catalog.exercise(id) else { continue }
                let hit = loads(ex).intersection(sore)
                guard let area = hit.sorted(by: { $0.rawValue < $1.rawValue }).first else { continue }
                let candidates = (SessionBuilder.standIns[id] ?? []).compactMap(catalog.exercise)
                    + catalog.swapChoices(for: ex.category).filter { $0.unit == ex.unit }
                if let pick = candidates.first(where: { gear.has($0) && !used.contains($0.id) && loads($0).isDisjoint(with: sore) }) {
                    used.insert(pick.id)
                    var new = item
                    new.exerciseID = pick.id
                    new.name = pick.name
                    new.equipment = pick.eq
                    new.unit = pick.unit
                    new.side = pick.side
                    new.detail = pick.cue
                    session.blocks[bi].items[ii] = new
                    notes.append("\(item.name) → \(pick.name) (\(area.name.lowercased()))")
                } else {
                    session.blocks[bi].items.remove(at: ii)
                    notes.append("\(item.name) out today (\(area.name.lowercased()))")
                }
            }
            if session.blocks[bi].items.isEmpty { session.blocks.remove(at: bi) }
        }
        // Conditioning isn't swapped automatically: say how to spare the area.
        for item in session.items where item.isCardio {
            if let tip = cardioTip(item.name, sore: sore) { notes.append(tip) }
        }
        return notes.reversed()
    }

    static func cardioTip(_ name: String, sore: Set<BodyArea>) -> String? {
        let n = name.lowercased()
        let running = ["4×4", "hill", "30/30", "run", "roadwork", "zone 2", "walk"].contains { n.contains($0) }
        let arms = ["bag", "box", "technique", "power rounds", "rope", "snatch", "circuit", "complex"].contains { n.contains($0) }
        if running, !sore.isDisjoint(with: [.knee, .ankle, .hip]) {
            return "\(name): use a bike or rower at the same times and heart rate."
        }
        if arms, !sore.isDisjoint(with: [.shoulder, .elbow, .wrist]) {
            return "\(name): do it on the bike or treadmill instead (same work and rest)."
        }
        return nil
    }

    public static func needsCheck(_ spot: SoreSpot, now: Date) -> Bool {
        now.timeIntervalSince(spot.lastCheck) >= checkEveryDays * 86400
    }
}
