import Foundation
import Observation
import SwiftData
import Hybrid12Engine

struct FinishSummary: Identifiable {
    let id = UUID()
    let title: String
    let changes: [LiftChange]
    let cardioMinutes: Int
    let weekMessage: String?
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

    func suggestion(for item: SessionItem, in session: Session) -> Suggestion {
        Suggestions.suggest(item: item, lifts: lifts, lightenToday: session.isLightDay, catalog: catalog)
    }

    func entry(_ key: String) -> LoggedItem {
        draft.entries[key] ?? LoggedItem()
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
        for (id, rec) in result.lifts where rec != lifts[id] {
            saveLift(id, rec)
        }
        lifts = result.lifts

        if result.cardioMinutes > 0 { addCardio(result.cardioMinutes, week: program.week) }

        context.insert(StoredLog(date: now, week: program.week, phase: s.week.phase.rawValue, slot: s.slot.rawValue,
                                 title: s.title, readiness: s.readiness.rawValue,
                                 cardioMinutes: result.cardioMinutes, entries: Self.encode(draft.entries)))
        logs.insert(LogStamp(slot: s.slot, date: now), at: 0)

        var state = program
        state.runMinutes = result.runMinutes
        if state.startDate == nil { state.startDate = now }
        let advance = Program.markDone(s.slot, state: state)
        setProgram(advance.state)
        resetDraft()

        return FinishSummary(title: s.title, changes: result.changes, cardioMinutes: result.cardioMinutes,
                             weekMessage: advance.message)
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

    // MARK: Saving

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
}
