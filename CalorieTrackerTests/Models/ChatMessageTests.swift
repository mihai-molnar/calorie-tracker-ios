import XCTest
@testable import CalorieTracker

final class ChatMessageTests: XCTestCase {
    func testDecodeChatHistoryResponse() throws {
        let json = """
        {
            "messages": [
                {"role": "user", "content": "I had 3 eggs"},
                {"role": "assistant", "content": "That's about 210 kcal."}
            ],
            "total_calories": 210,
            "weight_kg": 89.2,
            "daily_calorie_target": 2100
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ChatHistoryResponse.self, from: data)
        XCTAssertEqual(response.messages.count, 2)
        XCTAssertEqual(response.messages[0].role, "user")
        XCTAssertEqual(response.totalCalories, 210)
        XCTAssertEqual(response.weightKg, 89.2)
        XCTAssertEqual(response.dailyCalorieTarget, 2100)
    }

    func testDecodeChatChunkResponse() throws {
        let json = #"{"text": "Got "}"#
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let chunk = try decoder.decode(ChatChunkResponse.self, from: data)
        XCTAssertEqual(chunk.text, "Got ")
    }

    func testDecodeChatCompleteResponse() throws {
        let json = """
        {"data_applied": true, "total_calories": 350, "weight_kg": null}
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ChatCompleteResponse.self, from: data)
        XCTAssertTrue(response.dataApplied)
        XCTAssertEqual(response.totalCalories, 350)
        XCTAssertNil(response.weightKg)
    }

    func testChatMessageIdentifiable() {
        let msg = ChatMessage(id: UUID(), role: "user", content: "Hello")
        XCTAssertEqual(msg.role, "user")
        XCTAssertEqual(msg.content, "Hello")
    }
}
