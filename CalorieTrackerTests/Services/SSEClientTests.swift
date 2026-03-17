import XCTest
@testable import CalorieTracker

final class SSEClientTests: XCTestCase {
    func testParseMessageEvent() throws {
        let parser = SSEParser()
        let lines = [
            "event: message",
            #"data: {"text":"Hello!","data_applied":false,"total_calories":100,"weight_kg":null}"#,
            ""
        ]
        var events: [SSEEvent] = []
        for line in lines {
            if let event = parser.feed(line: line) {
                events.append(event)
            }
        }
        XCTAssertEqual(events.count, 1)
        if case .message(let response) = events[0] {
            XCTAssertEqual(response.text, "Hello!")
            XCTAssertFalse(response.dataApplied)
            XCTAssertEqual(response.totalCalories, 100)
            XCTAssertNil(response.weightKg)
        } else {
            XCTFail("Expected message event")
        }
    }

    func testParseDoneEvent() {
        let parser = SSEParser()
        let lines = ["event: done", "data: ", ""]
        var events: [SSEEvent] = []
        for line in lines {
            if let event = parser.feed(line: line) {
                events.append(event)
            }
        }
        XCTAssertEqual(events.count, 1)
        if case .done = events[0] {
            // pass
        } else {
            XCTFail("Expected done event")
        }
    }

    func testParseMultipleEvents() {
        let parser = SSEParser()
        let lines = [
            "event: message",
            #"data: {"text":"Hi","data_applied":true,"total_calories":200,"weight_kg":89.0}"#,
            "",
            "event: done",
            "data: ",
            ""
        ]
        var events: [SSEEvent] = []
        for line in lines {
            if let event = parser.feed(line: line) {
                events.append(event)
            }
        }
        XCTAssertEqual(events.count, 2)
    }
}
