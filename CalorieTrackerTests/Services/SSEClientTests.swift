import XCTest
@testable import CalorieTracker

final class SSEClientTests: XCTestCase {
    func testParseMessageEvent() throws {
        let parser = SSEParser()
        // Feed event line — no dispatch yet
        XCTAssertNil(parser.feed(line: "event: message"))
        // Feed data line — should dispatch immediately
        let event = parser.feed(line: #"data: {"text":"Hello!","data_applied":false,"total_calories":100,"weight_kg":null}"#)
        XCTAssertNotNil(event)
        if case .message(let response) = event! {
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
        XCTAssertNil(parser.feed(line: "event: done"))
        let event = parser.feed(line: "data: ")
        XCTAssertNotNil(event)
        if case .done = event! {
            // pass
        } else {
            XCTFail("Expected done event")
        }
    }

    func testParseMultipleEvents() {
        let parser = SSEParser()
        XCTAssertNil(parser.feed(line: "event: message"))
        let first = parser.feed(line: #"data: {"text":"Hi","data_applied":true,"total_calories":200,"weight_kg":89.0}"#)
        XCTAssertNotNil(first)

        XCTAssertNil(parser.feed(line: "event: done"))
        let second = parser.feed(line: "data: ")
        XCTAssertNotNil(second)
    }

    func testParseWithColonNoSpace() {
        // sse-starlette may send "event:message" without space after colon
        let parser = SSEParser()
        XCTAssertNil(parser.feed(line: "event:message"))
        let event = parser.feed(line: #"data:{"text":"Test","data_applied":false,"total_calories":0,"weight_kg":null}"#)
        XCTAssertNotNil(event)
        if case .message(let response) = event! {
            XCTAssertEqual(response.text, "Test")
        } else {
            XCTFail("Expected message event")
        }
    }
}
