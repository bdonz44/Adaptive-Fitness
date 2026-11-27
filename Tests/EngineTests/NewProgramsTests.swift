import Foundation
import Testing
@testable import Hybrid12Engine

/// VO2 Max (cardio first, 80/20) and Ripped (lean and defined), added Nov 27.
@Suite struct NewProgramsTests {
    func state(_ id: ProgramID, days: Int, week: Int = 1) -> ProgramState {
        ProgramState(week: week, program: id, days: days)
    }

    func week(_ s: ProgramState) -> [Session] {
        s.order.map { SessionBuilder.build(slot: $0, context: SessionDraft(slot: $0, state: s).context(for: s)) }
    }

    func isHard(_ session: Session) -> Bool {
        session.items.contains { ($0.hrHigh ?? 0) >= 95 }
    }

    // MARK: VO2 Max

    @Test func vo2HasTwoHardDaysNeverBackToBack() {
        for d in ProgramID.vo2Max.dayOptions {
            let sessions = week(state(.vo2Max, days: d))
            #expect(sessions.filter(isHard).count == 2, "\(d) days")
            for (a, b) in zip(sessions, sessions.dropFirst()) {
                #expect(!(isHard(a) && isHard(b)), "\(d) days: \(a.title) then \(b.title)")
            }
        }
    }

    @Test func vo2IntervalDaysHaveNoLiftingBeforeThem() {
        for d in ProgramID.vo2Max.dayOptions {
            for s in week(state(.vo2Max, days: d)) where isHard(s) {
                let lifts = s.items.filter(\.isLift)
                #expect(lifts.isEmpty, "\(s.title)")
            }
        }
    }

    @Test func vo2IsMostlyEasyMinutes() {
        // Mostly easy: interval work is hard; Zone 2 and the easy recoveries between intervals are easy.
        for d in ProgramID.vo2Max.dayOptions {
            var easy = 0.0, hard = 0.0
            for s in week(state(.vo2Max, days: d)) {
                for item in s.items where item.isCardio {
                    let rounds = Double(item.rounds ?? 0)
                    if let work = item.intervalWork {
                        hard += rounds * Double(work) / 60
                        easy += rounds * Double(item.intervalRest ?? 0) / 60
                    } else {
                        easy += rounds
                    }
                }
            }
            #expect(easy / (easy + hard) >= 0.7, "\(d) days: \(Int(easy)) easy vs \(Int(hard)) hard min")
        }
    }

    @Test func vo2IntervalsGrowByPhase() {
        let rounds = [1, 5, 9].map { w in
            week(state(.vo2Max, days: 4, week: w))[2].item("engine")?.rounds
        }
        #expect(rounds == [16, 20, 24])
    }

    @Test func vo2HardDaysGetSpacedByTheScheduler() {
        // After the 4×4 the app suggests the easy strength day, not the 30/30s.
        let s = state(.vo2Max, days: 4)
        var done = s
        done.doneSlots = ["A"]
        let next = Program.nextSlot(state: done, logs: [LogStamp(slot: .A, date: t0)], now: t0 + 3600)
        #expect(next == .B)
    }

    // MARK: Ripped

    @Test func rippedHitsEveryMuscleAtLeast10HardSetsAWeek() {
        for d in [4, 5] {
            var done: [(exerciseID: String, sets: Int)] = []
            for s in week(state(.ripped, days: d)) {
                for item in s.items where item.isLift {
                    if let id = item.exerciseID { done.append((id, item.sets)) }
                }
            }
            let sets = MuscleMap.sets(done)
            for m in Muscle.allCases {
                #expect((sets[m] ?? 0) >= 10, "\(d) days: \(m) only \(sets[m] ?? 0) sets")
            }
        }
    }

    @Test func rippedHasAbsAndConditioningEveryDay() {
        for d in ProgramID.ripped.dayOptions {
            for s in week(state(.ripped, days: d)) {
                let core = s.items.contains { item in
                    item.exerciseID.flatMap(Catalog.bundled.exercise).map { ["core", "abs"].contains($0.category)
                        || ($0.category == "trx" && MuscleMap.work($0)[.core] != nil) } ?? false
                } || s.items.contains { $0.name == "Abs Burner" }
                #expect(core, "\(d) days: \(s.title) has no ab work")
                let cardio = s.items.filter(\.isCardio)
                #expect(!cardio.isEmpty, "\(d) days: \(s.title) has no conditioning")
            }
        }
    }

    @Test func rippedKeepsTheMainLiftHeavyWhileRestShrinks() throws {
        let early = week(state(.ripped, days: 4, week: 1))[0]
        let late = week(state(.ripped, days: 4, week: 9))[0]
        let m1 = try #require(early.item("main")), m3 = try #require(late.item("main"))
        #expect(m3.sets >= 4 && m3.high <= 6)
        #expect(m1.restSeconds == m3.restSeconds)
        let acc1 = try #require(early.items.first { $0.kind == .accessory && $0.key.hasPrefix("p") })
        let acc3 = try #require(late.items.first { $0.kind == .accessory && $0.key.hasPrefix("p") })
        #expect(acc3.restSeconds < acc1.restSeconds)
    }

    @Test func ropesAndPullUpsAreUsedAndHaveStandIns() throws {
        let st = state(.ripped, days: 4)
        let ctx = SessionDraft(slot: .B, state: st).context(for: st)
        #expect(SessionBuilder.build(slot: .B, context: ctx).item("finisher")?.name == "Battle Ropes 30:30")
        #expect(SessionBuilder.build(slot: .C, context: SessionDraft(slot: .C, state: st).context(for: st)).item("s1")?.exerciseID == "pullup")

        var noGear = ctx
        noGear.gear = GearProfile(pullupBar: false, ropes: false)
        #expect(SessionBuilder.build(slot: .B, context: noGear).item("finisher")?.name == "Bag Finisher")
        var upper = SessionDraft(slot: .C, state: st).context(for: st)
        upper.gear = noGear.gear
        let swapped = try #require(SessionBuilder.build(slot: .C, context: upper).item("s1")?.exerciseID)
        #expect(swapped != "pullup" && swapped != "chinup")
    }

    @Test func olderSavedGearGetsRopesAndPullUpBarOn() throws {
        let old = #"{"barbell":true,"smallestPlate":2.5,"dumbbells":[5,10],"kettlebells":[35],"bench":true,"trx":true,"bag":true,"treadmill":true}"#
        let g = try JSONDecoder().decode(GearProfile.self, from: Data(old.utf8))
        #expect(g.ropes && g.pullupBar)
        #expect(g.dumbbells == [5, 10])
    }

    @Test func newProgramsSaveAndLoad() {
        for id in [ProgramID.vo2Max, .ripped] {
            let s = Program.switchTo(id, days: 4, state: ProgramState(week: 3))
            var back = ProgramState(week: s.week)
            back.applyStored(doneSlots: s.storedDoneSlots)
            #expect(back.program == id && back.days == 4 && back.programWeek.week == 1)
        }
    }
}
