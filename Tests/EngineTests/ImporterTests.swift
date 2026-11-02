import Foundation
import Testing
@testable import Hybrid12Engine

/// Same shape as the web app's `hybrid12-data.json` export, trimmed.
private let sample = """
{
  "exported": "2026-11-02",
  "app": "Hybrid 12",
  "state": {
    "cardio": { "2": 59, "5": 30 },
    "done": ["B", "C", "A"],
    "lifts": {
      "bench": { "fails": 1, "holds": 2, "note": "", "w": 185,
                 "hist": [ { "d": "2026-10-17", "hi": 5, "r": 5, "w": 180 },
                           { "d": "2026-10-02", "hi": 5, "r": 5, "w": 175 } ] },
      "plank": { "fails": 0, "note": "Hit every rep last time.", "w": 0,
                 "hist": [ { "d": "2026-09-30", "hi": 45, "r": 45, "w": null } ] },
      "kbswing": { "fails": 0, "note": "", "w": 50, "hist": [] }
    },
    "run": { "min": 30 },
    "started": "2026-09-28",
    "waist": [ { "d": "2026-10-22", "in": 42.75 }, { "d": "2026-10-06", "in": 43.5 } ],
    "week": 5,
    "weighIns": [ { "d": "2026-10-06", "lb": 225 }, { "d": "2026-10-31", "lb": 215.2 } ]
  },
  "sessions": [
    { "date": "2026-10-10", "entries": [ { "name": "Easy Run", "rounds": 37, "rpe": "ok", "w": "2.91" } ],
      "phase": "Foundation", "readiness": "normal", "slot": "R", "title": "Easy Run",
      "ts": 1791666971124, "week": 2, "id": "a" },
    { "date": "2026-10-02",
      "entries": [ { "id": "bench", "sets": [ { "r": 4, "w": 185 }, { "r": 5, "w": 175 } ] },
                   { "id": "bench", "sets": [ { "r": 5, "w": 165 } ] },
                   { "name": "Lateral Raise Burnout", "rounds": 2, "rpe": null, "w": "8" } ],
      "phase": "Foundation", "readiness": "great", "slot": "D", "title": "Heavy Upper",
      "ts": 1790983850559, "week": 1, "id": "b" },
    { "date": "2026-10-15", "entries": [ { "name": "Ruck", "rounds": null, "rpe": null, "w": null } ],
      "phase": "Foundation", "readiness": "normal", "slot": "D", "title": "Ruck (in place of Heavy Upper)",
      "ts": 1792083600000, "week": 3, "id": "c" },
    { "date": "2026-10-19", "entries": [], "slot": "Z", "week": 3 }
  ]
}
"""

@Suite struct ImporterTests {
    let utc = TimeZone(identifier: "UTC")!

    func parse(_ json: String = sample) throws -> Importer.Result {
        try Importer.parse(Data(json.utf8), timeZone: utc)
    }

    func day(_ text: String) -> Date { Importer.DayParser(timeZone: utc).date(text)! }

    @Test func programState() throws {
        let r = try parse()
        #expect(r.program.week == 5)
        #expect(r.program.doneSlots == ["B", "C", "A"])
        #expect(r.program.runMinutes == 30)
        #expect(r.program.startDate == day("2026-09-28"))
    }

    @Test func liftsKeepCountersAndSortHistory() throws {
        let bench = try #require(try parse().lifts["bench"])
        #expect(bench.workingWeight == 185)
        #expect(bench.fails == 1)
        #expect(bench.holds == 2)
        #expect(bench.note == nil)
        #expect(bench.history.map(\.weight) == [175, 180])
        #expect(bench.history.first?.targetHi == 5)
        #expect(bench.firstWeight == 175)
    }

    @Test func bodyweightMovesHaveNoWeight() throws {
        let plank = try #require(try parse().lifts["plank"])
        #expect(plank.workingWeight == nil)
        #expect(plank.firstWeight == nil)
        #expect(plank.history.first?.reps == 45)
        #expect(plank.note == "Hit every rep last time.")
    }

    @Test func liftsWithNoHistoryStillImport() throws {
        let swing = try #require(try parse().lifts["kbswing"])
        #expect(swing.workingWeight == 50)
        #expect(swing.history.isEmpty)
    }

    @Test func bodyMeasurementsAndCardio() throws {
        let r = try parse()
        #expect(r.weighIns.map(\.pounds) == [225, 215.2])
        #expect(r.waist.map(\.inches) == [43.5, 42.75])
        #expect(r.waist.first?.date == day("2026-10-06"))
        #expect(r.cardioByWeek == [2: 59, 5: 30])
    }

    @Test func sessionsSortedAndUnknownSlotsSkipped() throws {
        let logs = try parse().logs
        #expect(logs.map(\.slot) == [.D, .R, .D])
        #expect(logs[0].date == Date(timeIntervalSince1970: 1790983850.559))
        #expect(logs[0].readiness == "great")
        #expect(logs[0].phase == 0)
        #expect(logs[2].title == "Ruck (in place of Heavy Upper)")
    }

    @Test func sessionEntries() throws {
        let logs = try parse().logs
        let upper = logs[0].entries
        #expect(upper["bench"]?.sets.map(\.weight) == [185, 175])
        #expect(upper["bench#2"]?.sets.map(\.reps) == [5])
        #expect(upper["Lateral Raise Burnout"]?.rounds == 2)
        #expect(upper["Lateral Raise Burnout"]?.sets.first?.weight == 8)
        let run = try #require(logs[1].entries["Easy Run"])
        #expect(run.rounds == 37)
        #expect(run.miles == 2.91)
        #expect(run.runRating == .solid)
        #expect(logs[2].entries["Ruck"]?.rounds == nil)
    }

    @Test func rejectsOtherFiles() {
        #expect(throws: Importer.ImportError.notHybrid12) {
            try parse(#"{"app": "Bray-Ray", "state": {}}"#)
        }
        #expect(throws: Importer.ImportError.self) { try parse("not json") }
        #expect(throws: Importer.ImportError.self) { try parse(#"{"app": "Hybrid 12"}"#) }
    }

    /// Runs against a real export when HYBRID12_EXPORT points at one (not committed).
    @Test func realExportIfPresent() throws {
        guard let path = ProcessInfo.processInfo.environment["HYBRID12_EXPORT"] else { return }
        let r = try Importer.parse(Data(contentsOf: URL(fileURLWithPath: path)))
        print("Real export: week \(r.program.week), done \(r.program.doneSlots), \(r.summary)")
        let unknown = r.lifts.keys.filter { Catalog.bundled.exercise($0) == nil }
        #expect(unknown.isEmpty, "Lifts not in the library: \(unknown)")
        #expect(!r.logs.isEmpty)
    }
}
