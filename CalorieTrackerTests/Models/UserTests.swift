import XCTest
@testable import CalorieTracker

final class UserTests: XCTestCase {
    func testDecodeAuthResponse() throws {
        let json = #"{"access_token": "eyJhbGciOiJ...", "user_id": "abc-123"}"#
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(AuthResponse.self, from: data)
        XCTAssertEqual(response.accessToken, "eyJhbGciOiJ...")
        XCTAssertEqual(response.userId, "abc-123")
    }

    func testEncodeAuthRequest() throws {
        let request = AuthRequest(email: "test@example.com", password: "pass123")
        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: String]
        XCTAssertEqual(dict["email"], "test@example.com")
        XCTAssertEqual(dict["password"], "pass123")
    }
}
