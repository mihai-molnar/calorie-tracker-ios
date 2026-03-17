import XCTest
@testable import CalorieTracker

// MARK: - Mock URLProtocol

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            XCTFail("No request handler set")
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Tests

final class APIClientTests: XCTestCase {
    var apiClient: APIClient!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        apiClient = APIClient(baseURL: URL(string: "http://test.local")!, session: session)
    }

    func testGetRequestWithAuth() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"messages":[],"total_calories":0,"weight_kg":null,"daily_calorie_target":2100}"#.data(using: .utf8)!
            return (response, data)
        }

        let response: ChatHistoryResponse = try await apiClient.get(path: "/chat/history", token: "test-token")
        XCTAssertEqual(response.dailyCalorieTarget, 2100)
    }

    func testPostRequest() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            // Note: httpBody may be nil in URLProtocol; body is moved to httpBodyStream
            if let body = request.httpBody {
                let dict = try! JSONSerialization.jsonObject(with: body) as! [String: String]
                XCTAssertEqual(dict["email"], "test@test.com")
            } else if let stream = request.httpBodyStream {
                stream.open()
                let bufferSize = 4096
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate(); stream.close() }
                var data = Data()
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: bufferSize)
                    if read > 0 { data.append(buffer, count: read) }
                    else { break }
                }
                let dict = try! JSONSerialization.jsonObject(with: data) as! [String: String]
                XCTAssertEqual(dict["email"], "test@test.com")
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"access_token":"tok","user_id":"uid"}"#.data(using: .utf8)!
            return (response, data)
        }

        let body = AuthRequest(email: "test@test.com", password: "pass")
        let response: AuthResponse = try await apiClient.post(path: "/auth/login", body: body)
        XCTAssertEqual(response.accessToken, "tok")
    }

    func testUnauthorizedThrows() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let data = #"{"detail":"Invalid token"}"#.data(using: .utf8)!
            return (response, data)
        }

        do {
            let _: ChatHistoryResponse = try await apiClient.get(path: "/chat/history", token: "bad")
            XCTFail("Should have thrown")
        } catch let error as APIError {
            XCTAssertTrue(error.isUnauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testServerErrorThrows() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            let data = #"{"detail":"Bad request"}"#.data(using: .utf8)!
            return (response, data)
        }

        do {
            let _: AuthResponse = try await apiClient.post(path: "/auth/login", body: AuthRequest(email: "", password: ""))
            XCTFail("Should have thrown")
        } catch let error as APIError {
            XCTAssertEqual(error.localizedDescription, "Bad request")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
