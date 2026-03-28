import XCTest
@testable import CalorieTracker

final class DashboardDataTests: XCTestCase {
    func testDecodeDashboardResponse() throws {
        let json = """
        {
            "today": {
                "date": "2026-03-17",
                "weight_kg": 89.0,
                "total_calories": 1200,
                "daily_calorie_target": 2100,
                "calories_remaining": 900
            },
            "history": [
                {"date": "2026-03-16", "weight_kg": 89.5, "total_calories": 1800},
                {"date": "2026-03-15", "weight_kg": null, "total_calories": 2200}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(DashboardResponse.self, from: data)
        XCTAssertEqual(response.today.date, "2026-03-17")
        XCTAssertEqual(response.today.totalCalories, 1200)
        XCTAssertEqual(response.today.caloriesRemaining, 900)
        XCTAssertEqual(response.history.count, 2)
        XCTAssertNil(response.history[1].weightKg)
    }

    func testDecodeDashboardResponseWithHasMore() throws {
        let json = """
        {
            "today": {
                "date": "2026-03-17",
                "weight_kg": 89.0,
                "total_calories": 1200,
                "daily_calorie_target": 2100,
                "calories_remaining": 900
            },
            "history": [
                {"date": "2026-03-16", "weight_kg": 89.5, "total_calories": 1800}
            ],
            "has_more": true
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(DashboardResponse.self, from: data)
        XCTAssertTrue(response.hasMore)
        XCTAssertEqual(response.history.count, 1)
    }

    func testDailyLogEntryParsedDate() {
        let entry = DailyLogEntry(date: "2026-03-17", weightKg: nil, totalCalories: 1500)
        let parsed = entry.parsedDate
        XCTAssertNotNil(parsed)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: parsed!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 17)
    }

    func testDecodeFoodEntryUpdateResponse() throws {
        let json = #"{"message": "Updated", "new_total_calories": 500}"#
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(FoodEntryUpdateResponse.self, from: data)
        XCTAssertEqual(response.newTotalCalories, 500)
    }
}
