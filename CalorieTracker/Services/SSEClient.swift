import Foundation

enum SSEEvent {
    case message(ChatSSEResponse)
    case done
}

final class SSEParser {
    private var currentEvent: String?
    private var currentData: String?
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func feed(line: String) -> SSEEvent? {
        if line.hasPrefix("event: ") {
            currentEvent = String(line.dropFirst(7))
            return nil
        }

        if line.hasPrefix("data: ") {
            currentData = String(line.dropFirst(6))
            return nil
        }

        // Empty line = event dispatch
        if line.isEmpty {
            defer {
                currentEvent = nil
                currentData = nil
            }

            guard let event = currentEvent else { return nil }

            if event == "done" {
                return .done
            }

            if event == "message", let data = currentData?.data(using: .utf8),
               let response = try? decoder.decode(ChatSSEResponse.self, from: data) {
                return .message(response)
            }

            return nil
        }

        return nil
    }
}

final class SSEClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = Configuration.apiBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func sendMessage(_ message: String, token: String) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent("chat"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONEncoder().encode(ChatRequest(message: message))

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw APIError.unknown
                    }

                    if http.statusCode == 401 {
                        throw APIError.unauthorized
                    }

                    guard (200...299).contains(http.statusCode) else {
                        throw APIError.serverError(message: "Chat request failed with status \(http.statusCode)")
                    }

                    let parser = SSEParser()
                    for try await line in bytes.lines {
                        if let event = parser.feed(line: line) {
                            continuation.yield(event)
                            if case .done = event {
                                break
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
