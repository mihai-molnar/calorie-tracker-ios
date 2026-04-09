import XCTest
@testable import CalorieTracker

final class SSEClientTests: XCTestCase {
    func testParseChunkEvent() throws {
        let parser = SSEParser()
        XCTAssertNil(parser.feed(line: "event: chunk"))
        let event = parser.feed(line: #"data: {"text":"Hello"}"#)
        XCTAssertNotNil(event)
        if case .chunk(let text) = event! {
            XCTAssertEqual(text, "Hello")
        } else {
            XCTFail("Expected chunk event")
        }
    }

    func testParseCompleteEvent() throws {
        let parser = SSEParser()
        XCTAssertNil(parser.feed(line: "event: complete"))
        let event = parser.feed(line: #"data: {"data_applied":true,"total_calories":200,"weight_kg":89.0}"#)
        XCTAssertNotNil(event)
        if case .complete(let response) = event! {
            XCTAssertTrue(response.dataApplied)
            XCTAssertEqual(response.totalCalories, 200)
            XCTAssertEqual(response.weightKg, 89.0)
        } else {
            XCTFail("Expected complete event")
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

    func testParseMultipleChunks() {
        let parser = SSEParser()
        XCTAssertNil(parser.feed(line: "event: chunk"))
        let first = parser.feed(line: #"data: {"text":"Hi "}"#)
        XCTAssertNotNil(first)

        XCTAssertNil(parser.feed(line: "event: chunk"))
        let second = parser.feed(line: #"data: {"text":"there"}"#)
        XCTAssertNotNil(second)
        if case .chunk(let text) = second! {
            XCTAssertEqual(text, "there")
        } else {
            XCTFail("Expected chunk event")
        }
    }

    func testParseWithColonNoSpace() {
        // sse-starlette may send "event:chunk" without space after colon
        let parser = SSEParser()
        XCTAssertNil(parser.feed(line: "event:chunk"))
        let event = parser.feed(line: #"data:{"text":"Test"}"#)
        XCTAssertNotNil(event)
        if case .chunk(let text) = event! {
            XCTAssertEqual(text, "Test")
        } else {
            XCTFail("Expected chunk event")
        }
    }

    func testParseErrorEvent() {
        let parser = SSEParser()
        XCTAssertNil(parser.feed(line: "event: error"))
        let event = parser.feed(line: #"data: {"message":"Something broke"}"#)
        XCTAssertNotNil(event)
        if case .error(let message) = event! {
            XCTAssertEqual(message, "Something broke")
        } else {
            XCTFail("Expected error event")
        }
    }
}
