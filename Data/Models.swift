import Foundation
import SwiftData

// SwiftData models. CloudKit rules (milestone 4): every stored property has a
// default or is optional, and there are no unique constraints.
// Nested Engine values (lift history, logged entries, the draft) are stored as
// JSON so the Engine's plain value types stay the single source of truth.

@Model
final class StoredProgram {
    var week: Int = 1
    var doneSlots: [String] = []
    var startDate: Date? = nil
    var runMinutes: Int = 25

    init() {}
}

@Model
final class StoredLift {
    var exerciseID: String = ""
    /// JSON-encoded `LiftRecord` (working weight, counters, note, history).
    var json: Data = Data()

    init(exerciseID: String, json: Data) {
        self.exerciseID = exerciseID
        self.json = json
    }
}

@Model
final class StoredLog {
    var date: Date = Date()
    var week: Int = 1
    var phase: Int = 0
    var slot: String = ""
    var title: String = ""
    var readiness: String = "normal"
    var cardioMinutes: Int = 0
    /// JSON-encoded `[String: LoggedItem]`.
    var entries: Data = Data()

    init(date: Date, week: Int, phase: Int, slot: String, title: String, readiness: String,
         cardioMinutes: Int, entries: Data) {
        self.date = date
        self.week = week
        self.phase = phase
        self.slot = slot
        self.title = title
        self.readiness = readiness
        self.cardioMinutes = cardioMinutes
        self.entries = entries
    }
}

@Model
final class StoredDraft {
    /// JSON-encoded `SessionDraft`.
    var json: Data = Data()
    var updated: Date = Date()

    init(json: Data) {
        self.json = json
    }
}

@Model
final class StoredCardioWeek {
    var week: Int = 0
    var minutes: Int = 0

    init(week: Int, minutes: Int) {
        self.week = week
        self.minutes = minutes
    }
}

@Model
final class StoredWeighIn {
    var date: Date = Date()
    var pounds: Double = 0

    init(date: Date, pounds: Double) {
        self.date = date
        self.pounds = pounds
    }
}

@Model
final class StoredWaist {
    var date: Date = Date()
    var inches: Double = 0

    init(date: Date, inches: Double) {
        self.date = date
        self.inches = inches
    }
}

enum Schema12 {
    static let models: [any PersistentModel.Type] = [
        StoredProgram.self, StoredLift.self, StoredLog.self, StoredDraft.self,
        StoredCardioWeek.self, StoredWeighIn.self, StoredWaist.self,
    ]
}
