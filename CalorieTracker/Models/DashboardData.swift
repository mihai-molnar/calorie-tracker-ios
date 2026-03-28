import Foundation

struct DashboardResponse: Codable {
    let today: TodaySummary
    let history: [DailyLogEntry]
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case today, history, hasMore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        today = try container.decode(TodaySummary.self, forKey: .today)
        history = try container.decode([DailyLogEntry].self, forKey: .history)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
    }
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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var parsedDate: Date? {
        Self.dateFormatter.date(from: date)
    }

    enum CodingKeys: String, CodingKey {
        case date, weightKg, totalCalories
    }
}
