import Foundation
import UIKit
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
    var dataApplied = false
    var selectedImage: UIImage?

    private let apiClient: APIClient
    private let sseClient: SSEClient
    private let authManager: AuthManager

    init(apiClient: APIClient? = nil, sseClient: SSEClient = SSEClient(), authManager: AuthManager) {
        self.apiClient = apiClient ?? APIClient(authManager: authManager)
        self.sseClient = sseClient
        self.authManager = authManager
    }

    var canSend: Bool {
        let hasText = !messageText.trimmingCharacters(in: .whitespaces).isEmpty
        let hasImage = selectedImage != nil
        return (hasText || hasImage) && !isSending
    }

    var calorieProgress: Double {
        guard dailyCalorieTarget > 0 else { return 0 }
        return min(Double(totalCalories) / Double(dailyCalorieTarget), 1.0)
    }

    func base64EncodedImage() -> String? {
        guard let image = selectedImage else { return nil }

        // Resize to max 1024px on longest side
        let maxDimension: CGFloat = 1024
        let size = image.size
        let scale: CGFloat
        if size.width > maxDimension || size.height > maxDimension {
            scale = maxDimension / max(size.width, size.height)
        } else {
            scale = 1.0
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }

        // Compress to JPEG at 0.5 quality
        guard let data = resized.jpegData(compressionQuality: 0.5) else { return nil }
        return data.base64EncodedString()
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
        let imageBase64 = base64EncodedImage()
        messageText = ""
        selectedImage = nil
        isSending = true
        errorMessage = nil

        // Add user message immediately
        let displayContent = imageBase64 != nil ? "[Photo] \(text)" : text
        let userMessage = ChatMessage(role: "user", content: displayContent)
        messages.append(userMessage)

        do {
            try await streamChat(text, image: imageBase64, token: token)
        } catch let error as APIError where error.isUnauthorized {
            if let newToken = await authManager.refreshToken() {
                do {
                    try await streamChat(text, image: imageBase64, token: newToken)
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
    private func streamChat(_ text: String, image: String? = nil, token: String) async throws {
        var inProgressIndex: Int?
        for try await event in sseClient.sendMessage(text, image: image, token: token) {
            switch event {
            case .chunk(let delta):
                if let idx = inProgressIndex {
                    messages[idx].content += delta
                } else {
                    messages.append(ChatMessage(role: "assistant", content: delta))
                    inProgressIndex = messages.count - 1
                }
            case .complete(let response):
                let caloriesChanged = totalCalories != response.totalCalories
                totalCalories = response.totalCalories
                if let weight = response.weightKg {
                    weightKg = weight
                }
                if caloriesChanged {
                    dataApplied = true
                }
            case .error(let message):
                errorMessage = message
            case .done:
                break
            }
        }
    }
}
