import Foundation
import Testing
@testable import Hybrid12Engine

private func wrap(_ state: String, sessions: String = "[]") -> Data {
    "{\"app\":\"Hybrid 12\",\"state\":\(state),\"sessions\":\(sessions)}".data(using: .utf8)!
}

@Test func scratchB2_stringRepsKillsWholeImport() {
    let d = wrap(#"{"lifts":{"bench":{"w":185,"hist":[{"d":"2026-10-01","w":"185","r":"5"}]}},"weighIns":[{"d":"2026-10-01","lb":200}]}"#)
    var err: Error?
    do { _ = try Importer.parse(d) } catch { err = error }
    print("SCRATCH string reps error:", String(describing: err))
    #expect(err != nil)
}

@Test func scratchB2_stringPoundsKillsWholeImport() {
    let d = wrap(#"{"weighIns":[{"d":"2026-10-01","lb":"200.4"}]}"#)
    var err: Error?
    do { _ = try Importer.parse(d) } catch { err = error }
    print("SCRATCH string lb error:", String(describing: err))
    #expect(err != nil)
}

@Test func scratchB2_missingHistDateKillsWholeImport() {
    let d = wrap(#"{"lifts":{"bench":{"w":185,"hist":[{"w":185,"r":5},{"d":"2026-10-01","w":185,"r":5}]}}}"#)
    var err: Error?
    do { _ = try Importer.parse(d) } catch { err = error }
    print("SCRATCH missing d error:", String(describing: err))
    #expect(err != nil)
}

@Test func scratchB2_infiniteWeightImported() throws {
    let d = wrap(#"{"lifts":{"bench":{"w":"1e999","hist":[{"d":"2026-10-01","w":"inf","r":5}]}}}"#)
    let r = try Importer.parse(d)
    print("SCRATCH inf:", r.lifts["bench"]!.workingWeight as Any, r.lifts["bench"]!.history.first?.weight as Any)
    #expect(r.lifts["bench"]!.workingWeight == .infinity)
}

@Test func scratchB2_historyTruncatedAndFirstWeightWrong() throws {
    var hist: [String] = []
    for i in 0..<20 { hist.append(#"{"d":"2026-0\#(1 + i / 10)-\#(String(format: "%02d", 1 + i % 10))","w":\#(100 + i * 5),"r":5}"#) }
    let d = wrap(#"{"lifts":{"bench":{"w":200,"hist":[\#(hist.joined(separator: ","))]}}}"#)
    let r = try Importer.parse(d)
    let b = r.lifts["bench"]!
    print("SCRATCH hist count:", b.history.count, "firstWeight:", b.firstWeight as Any)
    #expect(b.history.count == 12)
    #expect(b.firstWeight == 140)
}

@Test func scratchB2_ghostMoreRepsReadsMatched() {
    let v = Ghost.verdict(weight: 100, reps: 15, against: (100, 13))
    print("SCRATCH ghost:", v)
    #expect(v == .matched)
}

@Test func scratchB2_prChaseFalsePositive() {
    let now = Date()
    var rec = LiftRecord(exerciseID: "bench", workingWeight: 195)
    rec.history = [
        HistoryEntry(date: now.addingTimeInterval(-40 * 86400), weight: 225, reps: 5, targetHi: 5),
        HistoryEntry(date: now.addingTimeInterval(-30 * 86400), weight: 185, reps: 5, targetHi: 5),
        HistoryEntry(date: now.addingTimeInterval(-20 * 86400), weight: 185, reps: 5, targetHi: 5),
        HistoryEntry(date: now.addingTimeInterval(-10 * 86400), weight: 185, reps: 5, targetHi: 5),
    ]
    let item = foundationMain("bench")
    let s = HomeInsights.prChase(item: item, weight: 195, record: rec)
    print("SCRATCH prChase:", s as Any, "high:", item.high)
    #expect(s != nil)
}

@Test func scratchB2_insightsMidnightIsMorning() {
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "America/New_York")!
    let day = Importer.DayParser(timeZone: cal.timeZone)
    let d = day.date("2026-10-06")!
    print("SCRATCH imported hour:", cal.component(.hour, from: d))
    #expect(cal.component(.hour, from: d) == 0)
}

@Test func scratchB2crash_hugeReps() throws {
    let d = wrap(#"{"lifts":{"bench":{"w":185,"hist":[{"d":"2026-10-01","w":185,"r":1e20}]}}}"#)
    _ = try Importer.parse(d)
    print("SCRATCH huge reps survived")
}

@Test func scratchB2crash_fmtInf() {
    print("SCRATCH fmt:", Fmt.lb(.infinity))
}
