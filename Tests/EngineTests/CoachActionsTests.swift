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
        #expect(CoachActions.exercise("pull ups", gear: GearProfile(pullupBar: false)) == nil)
        #expect(CoachActions.exercise("pull ups", gear: GearProfile(pullupBar: true))?.id == "pullup")
    }

    @Test func mainLiftSwapsWorkInHybrid() {
        var ctx = SessionContext(week: 1)
        ctx.swaps["main"] = "floorpress"
        #expect(SessionBuilder.build(slot: .D, context: ctx).item("main")?.exerciseID == "floorpress")
    }
}

@Suite struct CoachSwapGuardTests {
    let c = Catalog.bundled
    @Test func swapsMustTrainTheSameMuscles() throws {
        let bench = try #require(c.exercise("bench")), floor = try #require(c.exercise("floorpress"))
        let ohp = try #require(c.exercise("ohp")), squat = try #require(c.exercise("squat"))
        #expect(CoachActions.sameMuscles(bench, floor))
        #expect(!CoachActions.sameMuscles(squat, ohp))
        let alts = CoachActions.alternatives(for: bench)
        #expect(!alts.isEmpty && alts.allSatisfy { CoachActions.primary($0).contains(.chest) })
    }
}
