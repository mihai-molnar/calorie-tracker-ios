import XCTest
@testable import CalorieTracker

final class APIErrorTests: XCTestCase {
    func testDecodeDetailError() throws {
        let json = #"{"detail": "Invalid credentials"}"#
        let data = json.data(using: .utf8)!
        let error = try JSONDecoder().decode(APIErrorResponse.self, from: data)
        XCTAssertEqual(error.detail, "Invalid credentials")
    }

    func testAPIErrorLocalizedDescription() {
        let error = APIError.serverError(message: "Not found")
        XCTAssertEqual(error.localizedDescription, "Not found")
    }

    func testAPIErrorUnauthorized() {
        let error = APIError.unauthorized
        XCTAssertTrue(error.isUnauthorized)
    }

    func testAPIErrorNetwork() {
        let error = APIError.networkError(URLError(.notConnectedToInternet))
        XCTAssertFalse(error.isUnauthorized)
    }
}
