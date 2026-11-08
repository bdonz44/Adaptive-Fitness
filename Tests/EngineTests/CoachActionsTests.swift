import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct CoachActionsTests {
    @Test func findsTodaysItemByLooseName() {
        let s = SessionBuilder.build(slot: .D, context: SessionContext(week: 1))
        #expect(CoachActions.item("bench", in: s)?.key == "main")
        #expect(CoachActions.item("Bench Press", in: s)?.key == "main")
        #expect(CoachActions.item("zzz", in: s) == nil)
    }

    @Test func findsLibraryExercisesYouCanDo() {
        #expect(CoachActions.exercise("TRX chest fly")?.id == "trxchestfly")
        #expect(CoachActions.exercise("hammer curls")?.id == "hammer")
        #expect(CoachActions.exercise("pull ups") == nil)                         // no bar in the standard gym
        #expect(CoachActions.exercise("pull ups", gear: GearProfile(pullupBar: true))?.id == "pullup")
    }

    @Test func mainLiftSwapsWorkInHybrid() {
        var ctx = SessionContext(week: 1)
        ctx.swaps["main"] = "floorpress"
        #expect(SessionBuilder.build(slot: .D, context: ctx).item("main")?.exerciseID == "floorpress")
    }
}
