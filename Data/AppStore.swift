import Foundation
import Observation
import SwiftData
import Hybrid12Engine

struct FinishSummary: Identifiable {
    struct PR: Identifiable {
        let id: String
        let name: String
        let weight: Double
        let reps: Int
        let e1RM: Double
        let gain: Double
    }

    let id = UUID()
    let title: String
    let changes: [LiftChange]
    let cardioMinutes: Int
    let weekMessage: String?
    var minutes: Int? = nil
    var setsDone: Int = 0
    var volume: Double = 0
    var records: [PR] = []
    /// Sessions done this week after this one (0-5); 0 when the week just rolled over.
    var weekDone: Int = 0
}

/// One row in "Recent sessions".
struct RecentLog: Identifiable, Equatable {
    let date: Date
    let title: String
    let week: Int
    var id: Date { date }
}

/// Connects the Engine's pure functions to SwiftData storage and the screens.
@Observable
final class AppStore {
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let programModel: StoredProgram
    @ObservationIgnored let catalog = Catalog.bundled

    private(set) var program: ProgramState
    private(set) var lifts: [String: LiftRecord]
    private(set) var logs: [LogStamp]
    private(set) var cardioByWeek: [Int: Int]
    private(set) var draft: SessionDraft
    private(set) var recentLogs: [RecentLog]
    /// Oldest first.
    private(set) var weighIns: [WeighIn]
    /// Oldest first.
    private(set) var waist: [WaistEntry]

    init(context: ModelContext) {
        self.context = context

        let pm: StoredProgram
        if let first = (try? context.fetch(FetchDescriptor<StoredProgram>()))?.first {
            pm = first
        } else {
            pm = StoredProgram()
            context.insert(pm)
        }
        programModel = pm
        let state = ProgramState(week: pm.week, doneSlots: pm.doneSlots, startDate: pm.startDate, runMinutes: pm.runMinutes)
        program = state

        var loadedLifts: [String: LiftRecord] = [:]
        for stored in (try? context.fetch(FetchDescriptor<StoredLift>())) ?? [] {
            if let rec = Self.decode(LiftRecord.self, stored.json) { loadedLifts[stored.exerciseID] = rec }
        }
        lifts = loadedLifts

        let logDescriptor = FetchDescriptor<StoredLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let storedLogs = (try? context.fetch(logDescriptor)) ?? []
        let stamps = storedLogs.compactMap { log in Slot(rawValue: log.slot).map { LogStamp(slot: $0, date: log.date) } }
        logs = stamps
        recentLogs = storedLogs.prefix(Tracking.recentSessionLimit).map { RecentLog(date: $0.date, title: $0.title, week: $0.week) }

        weighIns = ((try? context.fetch(FetchDescriptor<StoredWeighIn>())) ?? [])
            .map { WeighIn(date: $0.date, pounds: $0.pounds) }.sorted { $0.date < $1.date }
        waist = ((try? context.fetch(FetchDescriptor<StoredWaist>())) ?? [])
            .map { WaistEntry(date: $0.date, inches: $0.inches) }.sorted { $0.date < $1.date }

        var cardio: [Int: Int] = [:]
        for week in (try? context.fetch(FetchDescriptor<StoredCardioWeek>())) ?? [] {
            cardio[week.week, default: 0] += week.minutes
        }
        cardioByWeek = cardio

        var saved: SessionDraft? = nil
        if let stored = (try? context.fetch(FetchDescriptor<StoredDraft>()))?.first {
            saved = Self.decode(SessionDraft.self, stored.json)
        }
        if let saved, saved.isCurrent(for: state) {
            draft = saved
        } else {
            draft = SessionDraft(slot: Program.nextSlot(state: state, logs: stamps, now: Date()), week: state.week)
        }
        try? context.save()
    }

    // MARK: Reading

    var week: ProgramWeek { ProgramWeek(program.week) }

    var session: Session {
        SessionBuilder.build(slot: draft.slot, context: draft.context(runMinutes: program.runMinutes), catalog: catalog)
    }

    var nextSlot: Slot { Program.nextSlot(state: program, logs: logs, now: Date()) }

    var cardioThisWeek: Int { cardioByWeek[program.week] ?? 0 }

    func coachNotes(now: Date = Date()) -> [CoachNote] {
        Coach.coachNotes(weighIns: weighIns, cardioByWeek: cardioByWeek, week: program.week,
                         lifts: lifts, now: now, catalog: catalog)
    }

    var workingWeights: [Tracking.WorkingWeight] { Tracking.workingWeights(lifts: lifts, catalog: catalog) }

    func suggestion(for item: SessionItem, in session: Session) -> Suggestion {
        Suggestions.suggest(item: item, lifts: lifts, lightenToday: session.isLightDay, catalog: catalog)
    }

    func entry(_ key: String) -> LoggedItem {
        draft.entries[key] ?? LoggedItem()
    }

    /// The next lift set to do (focus mode and the Now card).
    var nextOpenSet: SessionInsights.OpenSet? {
        SessionInsights.nextOpenSet(session: session, entries: draft.entries)
    }

    var sessionStats: SessionInsights.Stats {
        SessionInsights.stats(session: session, entries: draft.entries)
    }

    /// Weight for a set: what's typed, else the suggestion.
    func weight(for item: SessionItem, set index: Int, in session: Session) -> Double? {
        let sets = entry(item.key).sets
        if index < sets.count, let w = sets[index].weight { return w }
        return suggestion(for: item, in: session).weight
    }

    /// Next set and session progress for the Lock Screen.
    func restContext() -> RestContext {
        let s = session
        let stats = SessionInsights.stats(session: s, entries: draft.entries)
        var next = ""
        if let open = SessionInsights.nextOpenSet(session: s, entries: draft.entries), let item = s.item(open.key) {
            let w = weight(for: item, set: open.set, in: s)
            let amount = w.map { "\(lb($0)) × \(item.high)" } ?? "\(item.high) \(unitWord(item.unit))"
            next = "\(item.name) set \(open.set + 1) · \(amount)"
        }
        return RestContext(next: next, sessionTitle: s.title, setsDone: stats.setsDone, setsTotal: stats.setsPlanned)
    }

    // MARK: Draft changes (saved on every change)

    func select(_ slot: Slot) {
        guard slot != draft.slot else { return }
        draft = SessionDraft(slot: slot, week: program.week)
        saveDraft()
    }

    func setReadiness(_ readiness: Readiness) {
        draft.setReadiness(readiness)
        saveDraft()
    }

    func update(_ key: String, sets count: Int = 0, _ change: (inout LoggedItem) -> Void) {
        var e = draft.entries[key] ?? LoggedItem()
        e.ensureSets(count)
        change(&e)
        draft.entries[key] = e
        saveDraft()
    }

    func setWeight(_ weight: Double?, item: SessionItem, set index: Int, applyToLater: Bool = false) {
        draft.setWeight(weight, key: item.key, set: index, setCount: item.sets, applyToLaterUnfinished: applyToLater)
        saveDraft()
    }

    func swap(_ item: SessionItem) {
        draft.swap(item.key, in: session, catalog: catalog)
        saveDraft()
    }

    func toggleWarmTick(_ index: Int) {
        draft.toggleWarmTick(index)
        saveDraft()
    }

    /// Clears today's logging but keeps the slot and readiness.
    func restartSession() {
        draft = SessionDraft(slot: draft.slot, week: program.week, readiness: draft.readiness)
        saveDraft()
    }

    // MARK: Finishing

    func finish(now: Date = Date()) -> FinishSummary {
        let s = session
        let result = Progression.progress(session: s, entries: draft.entries, lifts: lifts, date: now,
                                          runMinutes: program.runMinutes, catalog: catalog)
        let workout = Workouts.record(session: s, entries: draft.entries, startedAt: draft.startedAt,
                                      finishedAt: now, cardioMinutes: result.cardioMinutes)
        if let workout { Task { await HealthService.shared.save(workout) } }
        let stats = SessionInsights.stats(session: s, entries: draft.entries)
        let records = SessionInsights.records(lifts: result.lifts, date: now).map { r in
            FinishSummary.PR(id: r.exerciseID, name: catalog.exercise(r.exerciseID)?.name ?? r.exerciseID,
                             weight: r.weight, reps: r.reps, e1RM: r.e1RM, gain: r.gain)
        }
        for (id, rec) in result.lifts where rec != lifts[id] {
            saveLift(id, rec)
        }
        lifts = result.lifts

        if result.cardioMinutes > 0 { addCardio(result.cardioMinutes, week: program.week) }

        context.insert(StoredLog(date: now, week: program.week, phase: s.week.phase.rawValue, slot: s.slot.rawValue,
                                 title: s.title, readiness: s.readiness.rawValue,
                                 cardioMinutes: result.cardioMinutes, entries: Self.encode(draft.entries)))
        logs.insert(LogStamp(slot: s.slot, date: now), at: 0)
        recentLogs.insert(RecentLog(date: now, title: s.title, week: program.week), at: 0)
        recentLogs = Array(recentLogs.prefix(Tracking.recentSessionLimit))

        var state = program
        state.runMinutes = result.runMinutes
        if state.startDate == nil { state.startDate = now }
        let advance = Program.markDone(s.slot, state: state)
        setProgram(advance.state)
        resetDraft()

        return FinishSummary(title: s.title, changes: result.changes, cardioMinutes: result.cardioMinutes,
                             weekMessage: advance.message, minutes: workout?.minutes, setsDone: stats.setsDone,
                             volume: stats.volume, records: records, weekDone: program.doneCount)
    }

    /// Skip marks a slot done with no log.
    @discardableResult
    func skip(_ slot: Slot) -> String? {
        let advance = Program.markDone(slot, state: program)
        setProgram(advance.state)
        if slot == draft.slot || !draft.isCurrent(for: program) { resetDraft() }
        return advance.message
    }

    @discardableResult
    func startNextWeek() -> String? {
        let advance = Program.startNextWeek(program)
        setProgram(advance.state)
        resetDraft()
        return advance.message
    }

    // MARK: Progress tab

    func addWeighIn(_ pounds: Double, date: Date = Date()) {
        weighIns = Tracking.adding(WeighIn(date: date, pounds: pounds), to: weighIns)
        syncWeighIns()
    }

    func removeWeighIn(_ entry: WeighIn) {
        weighIns.removeAll { $0 == entry }
        syncWeighIns()
    }

    func addWaist(_ inches: Double, date: Date = Date()) {
        waist = Tracking.adding(WaistEntry(date: date, inches: inches), to: waist)
        syncWaist()
    }

    func removeWaist(_ entry: WaistEntry) {
        waist.removeAll { $0 == entry }
        syncWaist()
    }

    // MARK: Plan controls

    /// Jump to week 1-12 within the current cycle. Clears done and the draft.
    func jump(toWeekInCycle n: Int) {
        setProgram(Program.jump(toWeekInCycle: n, state: program))
        resetDraft()
    }

    /// Erases the program state and every log: lifts, sessions, cardio, weigh-ins and waist.
    func startOver() {
        try? context.delete(model: StoredLift.self)
        try? context.delete(model: StoredLog.self)
        try? context.delete(model: StoredDraft.self)
        try? context.delete(model: StoredCardioWeek.self)
        try? context.delete(model: StoredWeighIn.self)
        try? context.delete(model: StoredWaist.self)
        lifts = [:]
        logs = []
        recentLogs = []
        cardioByWeek = [:]
        weighIns = []
        waist = []
        setProgram(ProgramState())
        resetDraft()
    }

    // MARK: Import

    /// Nothing logged yet (offer the web app import).
    var isEmpty: Bool { lifts.isEmpty && logs.isEmpty && weighIns.isEmpty && waist.isEmpty }

    /// Replaces everything with the web app's data.
    func importWebData(_ r: Importer.Result) {
        startOver()
        for (id, rec) in r.lifts { saveLift(id, rec) }
        lifts = r.lifts
        weighIns = r.weighIns
        syncWeighIns()
        waist = r.waist
        syncWaist()
        for (week, minutes) in r.cardioByWeek { addCardio(minutes, week: week) }
        for log in r.logs {
            context.insert(StoredLog(date: log.date, week: log.week, phase: log.phase, slot: log.slot.rawValue,
                                     title: log.title, readiness: log.readiness, cardioMinutes: 0,
                                     entries: Self.encode(log.entries)))
        }
        let newestFirst = r.logs.reversed()
        logs = newestFirst.map { LogStamp(slot: $0.slot, date: $0.date) }
        recentLogs = newestFirst.prefix(Tracking.recentSessionLimit).map { RecentLog(date: $0.date, title: $0.title, week: $0.week) }
        setProgram(r.program)
        resetDraft()
    }

    // MARK: Saving

    /// Makes stored weigh-ins match `weighIns` (adds new ones, deletes removed or trimmed ones).
    private func syncWeighIns() {
        var keep = weighIns
        for stored in (try? context.fetch(FetchDescriptor<StoredWeighIn>())) ?? [] {
            if let i = keep.firstIndex(of: WeighIn(date: stored.date, pounds: stored.pounds)) {
                keep.remove(at: i)
            } else {
                context.delete(stored)
            }
        }
        for new in keep { context.insert(StoredWeighIn(date: new.date, pounds: new.pounds)) }
        save()
    }

    private func syncWaist() {
        var keep = waist
        for stored in (try? context.fetch(FetchDescriptor<StoredWaist>())) ?? [] {
            if let i = keep.firstIndex(of: WaistEntry(date: stored.date, inches: stored.inches)) {
                keep.remove(at: i)
            } else {
                context.delete(stored)
            }
        }
        for new in keep { context.insert(StoredWaist(date: new.date, inches: new.inches)) }
        save()
    }

    private func resetDraft() {
        draft = SessionDraft(slot: nextSlot, week: program.week)
        saveDraft()
    }

    private func setProgram(_ state: ProgramState) {
        program = state
        programModel.week = state.week
        programModel.doneSlots = state.doneSlots
        programModel.startDate = state.startDate
        programModel.runMinutes = state.runMinutes
        save()
    }

    private func saveDraft() {
        draft.noteStart(at: Date())
        let data = Self.encode(draft)
        if let stored = (try? context.fetch(FetchDescriptor<StoredDraft>()))?.first {
            stored.json = data
            stored.updated = Date()
        } else {
            context.insert(StoredDraft(json: data))
        }
        save()
    }

    private func saveLift(_ id: String, _ rec: LiftRecord) {
        let data = Self.encode(rec)
        let descriptor = FetchDescriptor<StoredLift>(predicate: #Predicate { $0.exerciseID == id })
        if let stored = (try? context.fetch(descriptor))?.first {
            stored.json = data
        } else {
            context.insert(StoredLift(exerciseID: id, json: data))
        }
    }

    private func addCardio(_ minutes: Int, week: Int) {
        let descriptor = FetchDescriptor<StoredCardioWeek>(predicate: #Predicate { $0.week == week })
        if let stored = (try? context.fetch(descriptor))?.first {
            stored.minutes += minutes
        } else {
            context.insert(StoredCardioWeek(week: week, minutes: minutes))
        }
        cardioByWeek[week, default: 0] += minutes
    }

    private func save() {
        try? context.save()
    }

    private static func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }

    #if DEBUG
    /// Sample data for simulator screenshots (launch argument `-seedDemo`). Debug builds only.
    func seedDemo(now: Date = Date()) {
        startOver()
        let d: TimeInterval = 86400
        for (i, lb) in [246.0, 245.2, 244.6, 243.0, 242.4, 241.8, 240.6].enumerated() {
            addWeighIn(lb, date: now.addingTimeInterval(Double(i - 6) * 4 * d))
        }
        addWaist(42.5, date: now.addingTimeInterval(-21 * d))
        addWaist(41.75, date: now.addingTimeInterval(-7 * d))
        func rec(_ id: String, _ weights: [Double], reps: Int = 5) -> LiftRecord {
            let history = weights.enumerated().map { i, w in
                HistoryEntry(date: now.addingTimeInterval(Double(i - weights.count) * 7 * d), weight: w, reps: reps, targetHi: reps)
            }
            return LiftRecord(exerciseID: id, workingWeight: weights.last.map { $0 + 5 }, history: history, firstWeight: weights.first)
        }
        let seeded = [rec("squat", [205, 215, 225]), rec("bench", [165, 170, 175]), rec("ohp", [95, 100, 100]),
                      rec("deadlift", [255, 265, 275]), rec("kbswing", [35, 50], reps: 15)]
        for r in seeded { lifts[r.exerciseID] = r; saveLift(r.exerciseID, r) }
        setProgram(ProgramState(week: 3, doneSlots: ["B", "C"], startDate: now.addingTimeInterval(-16 * d), runMinutes: 30))
        addCardio(95, week: 2)
        addCardio(40, week: 3)
        for (i, slot) in [Slot.C, .B, .E, .D, .A].enumerated() {
            let date = now.addingTimeInterval(Double(-i - 1) * 1.6 * d)
            let title = Program.plan(slot).name
            let week = i < 2 ? 3 : 2
            context.insert(StoredLog(date: date, week: week, phase: 0, slot: slot.rawValue, title: title,
                                     readiness: "normal", cardioMinutes: 0, entries: Data()))
            logs.append(LogStamp(slot: slot, date: date))
            recentLogs.append(RecentLog(date: date, title: title, week: week))
        }
        resetDraft()
    }
    #endif
}
