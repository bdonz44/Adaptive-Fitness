import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct HeartRateTests {
    @Test func readsTheBluetoothMeasurement() {
        #expect(HeartRate.bpm(fromMeasurement: [0x00, 152]) == 152)          // 8-bit
        #expect(HeartRate.bpm(fromMeasurement: [0x01, 0xA0, 0x00]) == 160)   // 16-bit little endian
        #expect(HeartRate.bpm(fromMeasurement: [0x16, 71, 0x10, 0x03]) == 71) // contact + RR flags, 8-bit
        #expect(HeartRate.bpm(fromMeasurement: [0x00, 0]) == nil)            // no contact reading
        #expect(HeartRate.bpm(fromMeasurement: []) == nil)
        #expect(HeartRate.bpm(fromMeasurement: [0x01, 0x10]) == nil)         // truncated
    }

    @Test func zonesArePercentOfMax() {
        #expect(HeartRate.estimatedMax(age: 45) == 177)
        #expect(HeartRate.zone(bpm: 80, max: 176) == 0)
        #expect(HeartRate.zone(bpm: 120, max: 176) == 2)
        #expect(HeartRate.zone(bpm: 150, max: 176) == 4)
        #expect(HeartRate.zone(bpm: 165, max: 176) == 5)
    }

    @Test func norwegianTargetIs85To95() throws {
        let st = ProgramState(program: .engineStrength, days: 4)
        let s = SessionBuilder.build(slot: .A, context: SessionDraft(slot: .A, state: st).context(for: st))
        let engine = try #require(s.item("engine"))
        let t = try #require(HeartRate.target(for: engine))
        #expect(t == 85...95)
        #expect(HeartRate.targetText(t, max: 176) == "150-167 bpm")
        #expect(HeartRate.status(bpm: 140, max: 176, target: t) == .below)
        #expect(HeartRate.status(bpm: 158, max: 176, target: t) == .inZone)
        #expect(HeartRate.status(bpm: 172, max: 176, target: t) == .above)
    }

    @Test func everyConditioningBlockHasATarget() {
        for id in ProgramID.allCases {
            for d in id.dayOptions {
                let st = ProgramState(program: id, days: d)
                for slot in st.order + (id == .hybrid12 ? [.R] : []) {
                    let s = SessionBuilder.build(slot: slot, context: SessionDraft(slot: slot, state: st).context(for: st))
                    for item in s.items where item.isCardio {
                        #expect(HeartRate.target(for: item) != nil, "\(id) \(item.name)")
                    }
                    #expect(s.items.filter(\.isLift).allSatisfy { HeartRate.target(for: $0) == nil })
                }
            }
        }
    }

    @Test func timeInZoneAddsUpAndIgnoresGaps() throws {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        var samples: [HeartRate.Sample] = []
        for i in 0..<60 { samples.append(.init(date: t0.addingTimeInterval(Double(i)), bpm: 155)) }   // 1 min zone 4
        for i in 0..<30 { samples.append(.init(date: t0.addingTimeInterval(60 + Double(i)), bpm: 165)) } // 30 s zone 5
        samples.append(.init(date: t0.addingTimeInterval(200), bpm: 100))                              // after a 110 s gap
        let s = try #require(HeartRate.summary(samples, from: t0, to: t0.addingTimeInterval(205), max: 176))
        #expect(s.zoneSeconds[4] == 60)
        #expect(s.zoneSeconds[5] == 34)   // 29 one-second steps, then the gap counts only 5 s
        #expect(s.zoneSeconds[1] == 5)    // 100 bpm = 57% of 176
        #expect(s.hardSeconds == 94)
        #expect(s.peak == 165)
        #expect(HeartRate.summary(samples, from: t0.addingTimeInterval(1000), to: t0.addingTimeInterval(2000), max: 176) == nil)
    }

    @Test func readsWhoopWorkoutsAndMatchesTheSession() throws {
        let json: [String: Any] = ["records": [
            ["start": "2026-11-07T17:00:00.000Z", "end": "2026-11-07T18:05:00.000Z", "sport_name": "weightlifting",
             "score_state": "SCORED",
             "score": ["strain": 12.4, "average_heart_rate": 128, "max_heart_rate": 171, "kilojoule": 2510.0,
                       "zone_durations": ["zone_zero_milli": 60000, "zone_one_milli": 300000, "zone_two_milli": 900000,
                                          "zone_three_milli": 1200000, "zone_four_milli": 900000, "zone_five_milli": 240000]]],
            ["start": "2026-11-07T12:00:00Z", "end": "2026-11-07T12:20:00Z", "score_state": "PENDING_SCORE"],
            ["start": "2026-11-07T19:00:00Z", "end": "2026-11-07T19:30:00Z", "sport_name": "walking",
             "score_state": "SCORED", "score": ["strain": 4.0]],
        ]]
        let ws = WhoopWorkout.parse(json)
        #expect(ws.count == 2)
        let w = try #require(ws.first)
        #expect(w.strain == 12.4 && w.averageHR == 128 && w.maxHR == 171 && w.calories == 600)
        #expect(w.zoneSeconds == [60, 300, 900, 1200, 900, 240])
        let start = try #require(WhoopDate.parse("2026-11-07T17:10:00Z"))
        let end = try #require(WhoopDate.parse("2026-11-07T18:00:00Z"))
        #expect(WhoopWorkout.match(ws, start: start, end: end)?.sport == "weightlifting")
        #expect(WhoopWorkout.match(ws, start: end.addingTimeInterval(7200), end: end.addingTimeInterval(9000)) == nil)
    }
}

@Suite struct SessionHeartTests {
    let live = HeartRate.Summary(zoneSeconds: [60, 120, 600, 900, 720, 240], average: 131, peak: 168)

    @Test func savedInsideTheLogEntriesAndReadBack() throws {
        var entries: [String: LoggedItem] = ["main": LoggedItem(sets: sets(185, [5, 5]))]
        SessionHeart.write(SessionHeart(live: live), into: &entries)
        let data = try JSONEncoder().encode(entries)
        let back = try JSONDecoder().decode([String: LoggedItem].self, from: data)
        let h = try #require(SessionHeart.read(back))
        #expect(h.average == 131 && h.peak == 168 && !h.fromWhoop)
        #expect(h.hardMinutes == 16)
        #expect(back["main"]?.sets.count == 2)
    }

    @Test func whoopNumbersReplaceTheLiveOnes() {
        var h = SessionHeart(live: live)
        let w = WhoopWorkout(start: t0, end: t0.addingTimeInterval(3600), sport: "weightlifting", strain: 12.4,
                             averageHR: 128, maxHR: 171, kilojoules: 2510, zoneSeconds: [0, 0, 0, 0, 1200, 300])
        h.apply(w)
        #expect(h.fromWhoop && h.strain == 12.4 && h.peak == 171 && h.calories == 600)
        #expect(h.hardMinutes == 25)
        #expect(h.line == "Avg 128 · Max 171 · Zone 4-5 25 min · Strain 12.4")
    }

    @Test func hardMinutesAddUpByWeek() {
        let a = SessionHeart(live: live)
        let byWeek = SessionHeart.hardMinutesByWeek([(week: 3, heart: a), (week: 2, heart: a), (week: 3, heart: a)])
        #expect(byWeek.map(\.week) == [2, 3])
        #expect(byWeek.map(\.minutes) == [16, 32])
    }
}
