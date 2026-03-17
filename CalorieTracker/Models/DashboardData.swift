import Foundation

struct DashboardResponse: Codable {
    let today: TodaySummary
    let history: [DailyLogEntry]
}

struct TodaySummary: Codable {
    let date: String
    let weightKg: Double?
    let totalCalories: Int
    let dailyCalorieTarget: Int
    let caloriesRemaining: Int
}

struct DailyLogEntry: Codable, Identifiable {
    var id: String { date }
    let date: String
    let weightKg: Double?
    let totalCalories: Int

    enum CodingKeys: String, CodingKey {
        case date, weightKg, totalCalories
    }
}
