import Foundation
import Testing
@testable import Hybrid12Engine

/// Food from Apple Health (MyFitnessPal), merged with food typed in the app.
@Suite struct HealthFoodTests {
    var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }

    @Test func healthDaysReplaceTypedFoodOnlyOnThoseDays() {
        let d1 = cal.startOfDay(for: t0), d2 = d1 + day
        let typed = [FoodEntry(date: d1 + 3600 * 9, protein: 40, calories: 500),
                     FoodEntry(date: d2 + 3600 * 9, protein: 30, calories: 400)]
        let merged = Nutrition.merged(typed, health: [HealthFoodDay(day: d1 + 600, calories: 2350, protein: 190)], calendar: cal)
        let day1 = Nutrition.totals(merged, on: d1 + 3600, calendar: cal)
        #expect(day1.calories == 2350 && day1.protein == 190)
        let day2 = Nutrition.totals(merged, on: d2 + 3600, calendar: cal)
        #expect(day2.calories == 400 && day2.protein == 30)
        #expect(merged.filter(Nutrition.isFromHealth).count == 1)
    }

    @Test func emptyHealthDaysDontHideTypedFood() {
        let d1 = cal.startOfDay(for: t0)
        let typed = [FoodEntry(date: d1 + 3600 * 9, protein: 40, calories: 500)]
        let merged = Nutrition.merged(typed, health: [HealthFoodDay(day: d1, calories: 0, protein: 0)], calendar: cal)
        #expect(merged == typed)
    }

    @Test func healthFoodFeedsMaintenance() throws {
        // 28 days from MyFitnessPal at 2,400 while losing 1 lb a week: about 2,900 maintenance.
        let days = (0..<28).map { HealthFoodDay(day: t0 + Double($0) * day, calories: 2400, protein: 180) }
        let weigh = stride(from: 0, through: 28, by: 2).map { WeighIn(date: t0 + Double($0) * day, pounds: 220 - Double($0) / 7) }
        let food = Nutrition.merged([], health: days)
        let m = try #require(Nutrition.maintenance(weighIns: weigh, food: food, now: t0 + 28 * day))
        #expect(abs(m.calories - 2900) <= 30)
    }
}
