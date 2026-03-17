import Foundation

struct APIErrorResponse: Codable {
    let detail: String
}

enum APIError: LocalizedError {
    case networkError(URLError)
    case unauthorized
    case serverError(message: String)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return error.localizedDescription
        case .unauthorized:
            return "Session expired. Please log in again."
        case .serverError(let message):
            return message
        case .decodingError:
            return "Unexpected response from server."
        case .unknown:
            return "Something went wrong."
        }
    }

    var isUnauthorized: Bool {
        if case .unauthorized = self { return true }
        return false
    }
}
