import Foundation

struct OnboardingRequest: Codable {
    let age: Int
    let gender: String
    let heightCm: Double
    let weightKg: Double
    let activityLevel: String
    let targetWeightKg: Double
    let dailyCalorieTarget: Int?
    let timezone: String
    let openaiApiKey: String

    enum CodingKeys: String, CodingKey {
        case age, gender, timezone
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case activityLevel = "activity_level"
        case targetWeightKg = "target_weight_kg"
        case dailyCalorieTarget = "daily_calorie_target"
        case openaiApiKey = "openai_api_key"
    }
}

struct OnboardingResponse: Codable {
    let dailyCalorieTarget: Int
    let message: String
}

enum Gender: String, CaseIterable {
    case male, female, other
}

enum ActivityLevel: String, CaseIterable {
    case sedentary, light, moderate, active
    case veryActive = "very_active"

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly Active"
        case .moderate: return "Moderately Active"
        case .active: return "Active"
        case .veryActive: return "Very Active"
        }
    }

    var description: String {
        switch self {
        case .sedentary: return "Little or no exercise"
        case .light: return "Light exercise 1-3 days/week"
        case .moderate: return "Moderate exercise 3-5 days/week"
        case .active: return "Hard exercise 6-7 days/week"
        case .veryActive: return "Very hard exercise, physical job"
        }
    }
}
