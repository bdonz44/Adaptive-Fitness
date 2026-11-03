import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct CoachCuesTests {
    let squat = foundationMain("squat")   // 4 x 5, barbell
    let row = liftItem("dbrow")           // 3 x 10-12, dumbbell

    @Test func tooEasyPushesTheWeightUp() {
        let cue = CoachCues.afterSet(item: row, reps: 12, weight: 50, effort: .easy, setsLeft: 2, lightDay: false)
        #expect(cue.tone == .push)
        #expect(cue.newWeight == 55)
        let big = CoachCues.afterSet(item: squat, reps: 7, weight: 235, effort: nil, setsLeft: 2, lightDay: false)
        #expect(big.newWeight == 245)
    }

    @Test func missedRangeDropsTheWeight() {
        let cue = CoachCues.afterSet(item: row, reps: 8, weight: 50, effort: .grind, setsLeft: 1, lightDay: false)
        #expect(cue.tone == .ease)
        #expect(cue.newWeight == 45)
    }

    @Test func inRangeHoldsAndChasesAnotherRep() {
        let cue = CoachCues.afterSet(item: row, reps: 10, weight: 50, effort: .solid, setsLeft: 2, lightDay: false)
        #expect(cue.newWeight == nil)
        #expect(cue.text.contains("Chase 11"))
        let grind = CoachCues.afterSet(item: row, reps: 12, weight: 50, effort: .grind, setsLeft: 2, lightDay: false)
        #expect(grind.newWeight == nil)
    }

    @Test func lightDaysNeverPush() {
        let cue = CoachCues.afterSet(item: row, reps: 15, weight: 50, effort: .easy, setsLeft: 2, lightDay: true)
        #expect(cue.newWeight == nil)
        #expect(CoachCues.lastSetPush(item: squat, lightDay: true) == nil)
        #expect(CoachCues.lastSetPush(item: squat, lightDay: false) != nil)
        #expect(CoachCues.lastSetPush(item: row, lightDay: false) == nil)
    }

    @Test func lastSetWrapsUpTheLift() {
        let cue = CoachCues.afterSet(item: squat, reps: 5, weight: 235, effort: .solid, setsLeft: 0, lightDay: false)
        #expect(cue.tone == .done)
        #expect(cue.newWeight == nil)
    }

    @Test func targetComparesWithLastTime() {
        var rec = LiftRecord(exerciseID: "squat")
        rec.history = [entry(230, 5)]
        #expect(CoachCues.target(item: squat, record: rec, weight: 235, lightDay: false)!.contains("Up 5 lb"))
        rec.history = [entry(235, 4)]
        #expect(CoachCues.target(item: squat, record: rec, weight: 235, lightDay: false)!.contains("Beat it: 5+"))
        #expect(CoachCues.target(item: squat, record: nil, weight: 235, lightDay: false)!.contains("First time"))
    }

    @Test func nudgeIsTwoDaysLaterInTheMorning() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let n = CoachCues.nudge(after: t0, next: .A, calendar: cal)
        #expect(cal.dateComponents([.hour, .minute], from: n.date) == DateComponents(hour: 7, minute: 30))
        #expect(n.date > t0.addingTimeInterval(day))
        #expect(n.text.contains("Heavy Lower"))
    }
}
