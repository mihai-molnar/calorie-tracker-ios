import Foundation

struct EmptyBody: Codable {}

final class APIClient {
    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private weak var authManager: AuthManager?

    init(baseURL: URL = Configuration.apiBaseURL, session: URLSession = .shared, authManager: AuthManager? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.authManager = authManager
    }

    func get<T: Decodable>(path: String, token: String? = nil) async throws -> T {
        var request = makeRequest(path: path, method: "GET")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try await performWithRetry(request, originalToken: token)
    }

    func post<T: Decodable>(path: String, body: some Encodable, token: String? = nil) async throws -> T {
        var request = makeRequest(path: path, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try await performWithRetry(request, originalToken: token)
    }

    func patch<T: Decodable>(path: String, body: some Encodable, token: String? = nil) async throws -> T {
        var request = makeRequest(path: path, method: "PATCH")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try await performWithRetry(request, originalToken: token)
    }

    private func makeRequest(path: String, method: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        return request
    }

    private func performWithRetry<T: Decodable>(_ request: URLRequest, originalToken: String?) async throws -> T {
        do {
            return try await perform(request)
        } catch let error as APIError where error.isUnauthorized {
            // Attempt silent re-login if we have an authManager and credentials
            guard let authManager, originalToken != nil,
                  let newToken = await authManager.refreshToken() else {
                throw error
            }
            // Retry with new token
            var retryRequest = request
            retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            return try await perform(retryRequest)
        }
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        if http.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(message: errorResponse.detail)
            }
            throw APIError.serverError(message: "Request failed with status \(http.statusCode)")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
