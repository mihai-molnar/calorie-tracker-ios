import Foundation

struct FoodEntryUpdateRequest: Codable {
    let estimatedCalories: Int

    enum CodingKeys: String, CodingKey {
        case estimatedCalories = "estimated_calories"
    }
}

struct FoodEntryUpdateResponse: Codable {
    let message: String
    let newTotalCalories: Int
}
