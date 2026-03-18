import Foundation
import Observation

@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var messageText = ""
    var isSending = false
    var isLoadingHistory = false
    var errorMessage: String?
    var totalCalories = 0
    var dailyCalorieTarget = 0
    var weightKg: Double?

    private let apiClient: APIClient
    private let sseClient: SSEClient
    private let authManager: AuthManager

    init(apiClient: APIClient? = nil, sseClient: SSEClient = SSEClient(), authManager: AuthManager) {
        self.apiClient = apiClient ?? APIClient(authManager: authManager)
        self.sseClient = sseClient
        self.authManager = authManager
    }

    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
    }

    var calorieProgress: Double {
        guard dailyCalorieTarget > 0 else { return 0 }
        return min(Double(totalCalories) / Double(dailyCalorieTarget), 1.0)
    }

    @MainActor
    func loadHistory() async {
        guard let token = authManager.token else {
            authManager.handleUnauthorized()
            return
        }

        isLoadingHistory = true
        errorMessage = nil
        defer { isLoadingHistory = false }

        do {
            let response: ChatHistoryResponse = try await apiClient.get(path: "/chat/history", token: token)
            messages = response.messages
            totalCalories = response.totalCalories
            weightKg = response.weightKg
            dailyCalorieTarget = response.dailyCalorieTarget
        } catch let error as APIError where error.isUnauthorized {
            authManager.handleUnauthorized()
        } catch {
            errorMessage = "Failed to load chat history."
        }
    }

    @MainActor
    func send() async {
        guard canSend, let token = authManager.token else { return }

        let text = messageText.trimmingCharacters(in: .whitespaces)
        messageText = ""
        isSending = true
        errorMessage = nil

        // Add user message immediately
        let userMessage = ChatMessage(role: "user", content: text)
        messages.append(userMessage)

        do {
            try await streamChat(text, token: token)
        } catch let error as APIError where error.isUnauthorized {
            // Try silent re-login and retry once
            if let newToken = await authManager.refreshToken() {
                do {
                    try await streamChat(text, token: newToken)
                } catch {
                    authManager.handleUnauthorized()
                }
            } else {
                authManager.handleUnauthorized()
            }
        } catch {
            errorMessage = "Failed to send message. Try again."
        }

        isSending = false
    }

    @MainActor
    private func streamChat(_ text: String, token: String) async throws {
        for try await event in sseClient.sendMessage(text, token: token) {
            switch event {
            case .message(let response):
                let assistantMessage = ChatMessage(role: "assistant", content: response.text)
                messages.append(assistantMessage)
                totalCalories = response.totalCalories
                if let weight = response.weightKg {
                    weightKg = weight
                }
            case .done:
                break
            }
        }
    }
}
