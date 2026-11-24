import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct SafeJSONTests {
    @Test func plainEncoderRejectsNaNButSafeJSONKeepsTheRecord() throws {
        var draft = SessionDraft(slot: .A, week: 3)
        draft.entries["p0c0"] = LoggedItem(sets: [LoggedSet(weight: .nan, reps: 5), LoggedSet(weight: 225, reps: 5)])
        #expect(throws: (any Error).self) { try JSONEncoder().encode(draft) }

        let data = try #require(SafeJSON.encode(draft))
        let back = try #require(SafeJSON.decode(SessionDraft.self, data))
        #expect(back.entries["p0c0"]?.sets[1].weight == 225)
        #expect(back.entries["p0c0"]?.sets[0].weight?.isNaN == true)
    }

    @Test func readsDataSavedByThePlainEncoder() throws {
        let rec = LiftRecord(exerciseID: "squat", workingWeight: 225)
        let old = try JSONEncoder().encode(rec)
        #expect(SafeJSON.decode(LiftRecord.self, old) == rec)
    }

    @Test func emptyOrBrokenDataDecodesToNil() {
        #expect(SafeJSON.decode(LiftRecord.self, Data()) == nil)
        #expect(SafeJSON.decode(LiftRecord.self, Data("{".utf8)) == nil)
    }

    @Test func usableAmounts() {
        #expect(225.0.isUsableAmount)
        #expect(0.0.isUsableAmount)
        #expect(!(-5.0).isUsableAmount)
        #expect(!Double.nan.isUsableAmount)
        #expect(!Double.infinity.isUsableAmount)
    }
}
