import Foundation

/// Reads the web app's "Export data" JSON (`hybrid12-data.json`) into Engine values.
/// The web app stores state in short keys: lifts `{w, fails, holds, note, hist: [{d, w, r, hi}]}`,
/// weigh-ins `{d, lb}`, waist `{d, in}`, cardio `{"week": minutes}`, plus a list of logged sessions.
public enum Importer {
    public enum ImportError: Error, Equatable, LocalizedError {
        case unreadable(String)
        case notHybrid12

        public var errorDescription: String? {
            switch self {
            case .unreadable(let detail): return "This file could not be read as a Hybrid 12 export. (\(detail))"
            case .notHybrid12: return "This file is not a Hybrid 12 export."
            }
        }
    }

    public struct ImportedLog: Equatable, Sendable {
        public var date: Date
        public var week: Int
        public var phase: Int
        public var slot: Slot
        public var title: String
        public var readiness: String
        /// Keyed by exercise id (lifts) or name (engine workouts, finishers, runs).
        public var entries: [String: LoggedItem]
    }

    public struct Result: Equatable, Sendable {
        public var program: ProgramState
        public var lifts: [String: LiftRecord]
        /// Oldest first.
        public var weighIns: [WeighIn]
        /// Oldest first.
        public var waist: [WaistEntry]
        public var cardioByWeek: [Int: Int]
        /// Oldest first.
        public var logs: [ImportedLog]

        /// "5 sessions, 12 lifts, 6 weigh-ins and 4 waist entries"
        public var summary: String {
            "\(logs.count) sessions, \(lifts.count) lifts, \(weighIns.count) weigh-ins and \(waist.count) waist entries"
        }
    }

    public static func parse(_ data: Data, catalog: Catalog = .bundled, timeZone: TimeZone = .current) throws -> Result {
        let file: ExportFile
        do {
            file = try JSONDecoder().decode(ExportFile.self, from: data)
        } catch let error as DecodingError {
            throw ImportError.unreadable(describe(error))
        } catch {
            throw ImportError.unreadable(error.localizedDescription)
        }
        if let app = file.app, app != "Hybrid 12" { throw ImportError.notHybrid12 }

        let day = DayParser(timeZone: timeZone)
        let s = file.state

        let program = ProgramState(
            week: max(1, s.week ?? 1),
            doneSlots: (s.done ?? []).filter { Slot(rawValue: $0) != nil && $0 != Slot.R.rawValue },
            startDate: s.started.flatMap(day.date),
            runMinutes: s.run?.min ?? Program.defaultRunMinutes)

        var lifts: [String: LiftRecord] = [:]
        for (id, web) in s.lifts ?? [:] {
            let bodyweight = catalog.exercise(id)?.eq == .bw
            let allHistory = (web.hist?.items ?? []).compactMap { h -> HistoryEntry? in
                guard let date = h.d.flatMap(day.date) else { return nil }
                return HistoryEntry(date: date, weight: positive(h.w?.value), reps: reps(h.r?.value), targetHi: reps(h.hi?.value))
            }.sorted { $0.date < $1.date }
            let history = allHistory.suffix(Progression.historyLimit)
            let note = web.note?.trimmingCharacters(in: .whitespaces)
            lifts[id] = LiftRecord(
                exerciseID: id,
                workingWeight: bodyweight ? nil : positive(web.w?.value),
                fails: web.fails ?? 0,
                holds: web.holds ?? 0,
                note: (note?.isEmpty ?? true) ? nil : note,
                history: Array(history),
                firstWeight: bodyweight ? nil : allHistory.lazy.compactMap(\.weight).first)
        }

        let weighIns = (s.weighIns?.items ?? []).compactMap { w -> WeighIn? in
            guard let date = w.d.flatMap(day.date), let lb = positive(w.lb?.value) else { return nil }
            return WeighIn(date: date, pounds: lb)
        }.sorted { $0.date < $1.date }.suffix(Coach.weighInLimit)

        let waist = (s.waist?.items ?? []).compactMap { w -> WaistEntry? in
            guard let date = w.d.flatMap(day.date), let inches = positive(w.inches?.value) else { return nil }
            return WaistEntry(date: date, inches: inches)
        }.sorted { $0.date < $1.date }.suffix(Coach.waistLimit)

        var cardio: [Int: Int] = [:]
        for (week, minutes) in s.cardio ?? [:] {
            if let w = Int(week), w > 0, let m = count(minutes.value), m > 0 { cardio[w] = m }
        }

        let logs = (file.sessions?.items ?? []).compactMap { session -> ImportedLog? in
            guard let slot = Slot(rawValue: session.slot ?? "") else { return nil }
            let date = session.ts.flatMap { $0.isFinite ? Date(timeIntervalSince1970: $0 / 1000) : nil }
                ?? session.date.flatMap(day.date).map { $0.addingTimeInterval(12 * 3600) }
            guard let date else { return nil }
            let week = max(1, session.week ?? 1)
            let phase = Phase.allCases.first { $0.name == session.phase }?.rawValue ?? ProgramWeek(week).phase.rawValue
            return ImportedLog(date: date, week: week, phase: phase, slot: slot,
                               title: session.title ?? Program.plan(slot).name,
                               readiness: Readiness(rawValue: session.readiness ?? "")?.rawValue ?? Readiness.normal.rawValue,
                               entries: entries(session.entries?.items ?? [], isRun: slot == .R))
        }.sorted { $0.date < $1.date }

        return Result(program: program, lifts: lifts, weighIns: Array(weighIns), waist: Array(waist),
                      cardioByWeek: cardio, logs: logs)
    }

    /// "ok" is the web app's Solid; it also accepts the other two ratings by name.
    static func runRating(_ rpe: String?) -> RunRating? {
        switch rpe?.lowercased() {
        case "easy", "felteasy", "felt easy": return .feltEasy
        case "ok", "solid": return .solid
        case "hard", "toohard", "too hard": return .tooHard
        default: return nil
        }
    }

    private static func entries(_ list: [ExportEntry], isRun: Bool) -> [String: LoggedItem] {
        var out: [String: LoggedItem] = [:]
        for e in list {
            guard var key = e.id ?? e.name else { continue }
            if out[key] != nil {
                var n = 2
                while out["\(key)#\(n)"] != nil { n += 1 }
                key = "\(key)#\(n)"
            }
            var item = LoggedItem()
            if let sets = e.sets {
                item.sets = sets.items.map { LoggedSet(weight: positive($0.w?.value), reps: reps($0.r?.value), ticked: true) }
            } else {
                item.rounds = count(e.rounds?.value)
                item.ticked = true
                if isRun {
                    item.miles = positive(e.w?.value)
                    item.runRating = runRating(e.rpe)
                } else if let w = positive(e.w?.value) {
                    item.sets = [LoggedSet(weight: w, ticked: true)]
                }
            }
            out[key] = item
        }
        return out
    }

    /// A real weight, distance or measurement: finite, above zero and below anything a person could lift.
    private static func positive(_ v: Double?) -> Double? {
        guard let v, v.isFinite, v > 0, v < 5000 else { return nil }
        return v
    }

    /// A whole number that fits (no crash on 1e20, inf or nan); nil when it doesn't.
    static func count(_ v: Double?) -> Int? {
        guard let v, v.isFinite, abs(v) < 1_000_000 else { return nil }
        return Int(v.rounded())
    }

    /// Reps: a count above zero.
    private static func reps(_ v: Double?) -> Int? {
        count(v).flatMap { $0 > 0 ? $0 : nil }
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(_, let c), .valueNotFound(_, let c), .keyNotFound(_, let c), .dataCorrupted(let c):
            let path = c.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
            return path.isEmpty ? c.debugDescription : "at \(path)"
        @unknown default:
            return "unknown problem"
        }
    }

    // MARK: File shape

    struct DayParser {
        let formatter: DateFormatter
        init(timeZone: TimeZone) {
            formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = timeZone
            formatter.dateFormat = "yyyy-MM-dd"
        }
        /// "2026-10-06" -> midnight that day in the given time zone.
        func date(_ text: String) -> Date? { formatter.date(from: String(text.prefix(10))) }
    }

    /// A number the web app sometimes saved as text ("2.91").
    struct Flex: Decodable {
        let value: Double?
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if c.decodeNil() { value = nil }
            else if let d = try? c.decode(Double.self) { value = d }
            else if let s = try? c.decode(String.self) { value = Double(s.trimmingCharacters(in: .whitespaces)) }
            else { value = nil }
        }
    }

    /// An array where an element that can't be read is skipped instead of failing the whole file.
    struct Lossy<Element: Decodable>: Decodable {
        let items: [Element]
        private struct Skip: Decodable {}
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            var out: [Element] = []
            while !c.isAtEnd {
                if let e = try? c.decode(Element.self) { out.append(e) } else { _ = try? c.decode(Skip.self) }
            }
            items = out
        }
    }

    struct ExportFile: Decodable {
        let app: String?
        let state: ExportState
        let sessions: Lossy<ExportSession>?
    }

    struct ExportState: Decodable {
        struct Lift: Decodable {
            let w: Flex?
            let fails: Int?
            let holds: Int?
            let note: String?
            let hist: Lossy<Hist>?
        }
        struct Hist: Decodable {
            let d: String?
            let w: Flex?
            let r: Flex?
            let hi: Flex?
        }
        struct Weigh: Decodable { let d: String?; let lb: Flex? }
        struct Waist: Decodable {
            let d: String?
            let inches: Flex?
            enum CodingKeys: String, CodingKey { case d, inches = "in" }
        }
        struct Run: Decodable { let min: Int? }

        let week: Int?
        let done: [String]?
        let started: String?
        let run: Run?
        let lifts: [String: Lift]?
        let weighIns: Lossy<Weigh>?
        let waist: Lossy<Waist>?
        let cardio: [String: Flex]?
    }

    struct ExportSession: Decodable {
        let date: String?
        let ts: Double?
        let week: Int?
        let phase: String?
        let slot: String?
        let title: String?
        let readiness: String?
        let entries: Lossy<ExportEntry>?
    }

    struct ExportEntry: Decodable {
        struct Set: Decodable { let w: Flex?; let r: Flex? }
        let id: String?
        let name: String?
        let sets: Lossy<Set>?
        let rounds: Flex?
        let rpe: String?
        let w: Flex?
    }
}
