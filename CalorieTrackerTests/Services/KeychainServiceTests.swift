import XCTest
@testable import CalorieTracker

final class KeychainServiceTests: XCTestCase {
    let service = KeychainService(service: "com.calorietracker.tests")

    override func tearDown() {
        service.delete(key: "test_token")
        super.tearDown()
    }

    func testSaveAndLoad() throws {
        try service.save(key: "test_token", value: "my-jwt-token")
        let loaded = service.load(key: "test_token")
        XCTAssertEqual(loaded, "my-jwt-token")
    }

    func testLoadMissing() {
        let loaded = service.load(key: "nonexistent")
        XCTAssertNil(loaded)
    }

    func testDelete() throws {
        try service.save(key: "test_token", value: "to-be-deleted")
        service.delete(key: "test_token")
        XCTAssertNil(service.load(key: "test_token"))
    }

    func testOverwrite() throws {
        try service.save(key: "test_token", value: "first")
        try service.save(key: "test_token", value: "second")
        XCTAssertEqual(service.load(key: "test_token"), "second")
    }
}
