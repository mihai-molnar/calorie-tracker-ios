import Foundation

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let role: String
    let content: String

    init(id: UUID = UUID(), role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }

    enum CodingKeys: String, CodingKey {
        case role, content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.role = try container.decode(String.self, forKey: .role)
        self.content = try container.decode(String.self, forKey: .content)
    }
}

struct ChatHistoryResponse: Codable {
    let messages: [ChatMessage]
    let totalCalories: Int
    let weightKg: Double?
    let dailyCalorieTarget: Int
}

struct ChatSSEResponse: Codable {
    let text: String
    let dataApplied: Bool
    let totalCalories: Int
    let weightKg: Double?
}

struct ChatRequest: Codable {
    let message: String
    let image: String?

    init(message: String, image: String? = nil) {
        self.message = message
        self.image = image
    }
}
