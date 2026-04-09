import Foundation

enum SSEEvent {
    case chunk(String)
    case complete(ChatCompleteResponse)
    case error(String)
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

    /// Feed a line from the SSE stream. Returns an event when one is complete.
    /// Dispatches as soon as both event and data fields are collected,
    /// since URLSession's bytes.lines skips empty lines.
    func feed(line: String) -> SSEEvent? {
        if line.hasPrefix("event:") {
            currentEvent = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            return nil
        }

        if line.hasPrefix("data:") {
            currentData = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            // We have both event and data — dispatch immediately
            return tryDispatch()
        }

        // Empty line (in case it does come through)
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            return tryDispatch()
        }

        return nil
    }

    private func tryDispatch() -> SSEEvent? {
        guard let event = currentEvent else { return nil }
        // Need data field to be set (even if empty string for "done")
        guard let dataStr = currentData else { return nil }

        defer {
            currentEvent = nil
            currentData = nil
        }

        if event == "done" {
            return .done
        }

        guard let jsonData = dataStr.data(using: .utf8) else { return nil }

        if event == "chunk",
           let chunk = try? decoder.decode(ChatChunkResponse.self, from: jsonData) {
            return .chunk(chunk.text)
        }

        if event == "complete",
           let complete = try? decoder.decode(ChatCompleteResponse.self, from: jsonData) {
            return .complete(complete)
        }

        if event == "error" {
            struct ErrorPayload: Codable { let message: String }
            if let payload = try? decoder.decode(ErrorPayload.self, from: jsonData) {
                return .error(payload.message)
            }
            return .error("Unknown error")
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

    func sendMessage(_ message: String, image: String? = nil, token: String) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent("chat"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONEncoder().encode(ChatRequest(message: message, image: image))

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
