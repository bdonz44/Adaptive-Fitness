import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct NutritionTests {
    let now = Date(timeIntervalSince1970: 1_793_000_000)
    func w(_ daysAgo: Double, _ lb: Double) -> WeighIn { WeighIn(date: now.addingTimeInterval(-daysAgo * 86400), pounds: lb) }

    @Test func proteinIsGoalWeightInGrams() {
        let a = Nutrition.advice(weighIns: [w(1, 205)], settings: .init(goalWeight: 185), now: now)
        #expect(a.proteinGrams == 185)
        #expect(a.call == .needData)
        let noGoal = Nutrition.advice(weighIns: [w(1, 205)], settings: .init(), now: now)
        #expect(noGoal.proteinGrams == 205)
    }

    @Test func flatForTwoWeeksCuts300() {
        let a = Nutrition.advice(weighIns: [w(20, 200), w(10, 200.4), w(1, 199.8)], settings: .init(goalWeight: 185, currentCalories: 2600), now: now)
        #expect(a.call == .cut && a.calorieChange == -300 && a.calorieTarget == 2300)
    }

    @Test func losingOverOnePercentAWeekAdds200() {
        let a = Nutrition.advice(weighIns: [w(15, 210), w(1, 202)], settings: .init(goalWeight: 185), now: now)
        #expect(a.call == .add && a.calorieChange == 200)
    }

    @Test func onPaceHolds() throws {
        let a = Nutrition.advice(weighIns: [w(15, 205), w(1, 203)], settings: .init(goalWeight: 185), now: now)
        #expect(a.call == .hold && a.calorieChange == 0)
        #expect(abs(try #require(a.ratePerWeek) + 1) < 0.01)
    }

    @Test func atGoalHoldsEvenWhenFlat() {
        let a = Nutrition.advice(weighIns: [w(20, 185.5), w(1, 185.5)], settings: .init(goalWeight: 185), now: now)
        #expect(a.call == .atGoal && a.calorieChange == 0)
    }

    @Test func olderSavesTurnNutritionOn() throws {
        let s = try JSONDecoder().decode(AdaptiveSettings.self, from: Data(#"{"timeBox":true}"#.utf8))
        #expect(s.nutrition)
    }
}

@Suite struct FoodLogTests {
    @Test func totalsAreForTheDayOnly() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let noon = cal.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 12))!
        let entries = [FoodEntry(date: noon, protein: 40, calories: 500),
                       FoodEntry(date: noon.addingTimeInterval(3600 * 6), protein: 30, calories: 0),
                       FoodEntry(date: noon.addingTimeInterval(-86400), protein: 50, calories: 700)]
        let t = Nutrition.totals(entries, on: noon, calendar: cal)
        #expect(t.protein == 70 && t.calories == 500)
        #expect(Nutrition.progressText(70, of: 185, unit: "g") == "70 / 185 g")
        #expect(Nutrition.progressText(70, of: nil, unit: "g") == "70 g")
    }
}
