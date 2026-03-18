import Foundation
import Observation

@Observable
final class SettingsViewModel {
    var apiKey = ""
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    var dailyCalorieTarget: Int?

    private let apiClient: APIClient
    private let authManager: AuthManager

    init(apiClient: APIClient? = nil, authManager: AuthManager) {
        self.apiClient = apiClient ?? APIClient(authManager: authManager)
        self.authManager = authManager
    }

    var canSaveApiKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    @MainActor
    func loadSettings() async {
        guard let token = authManager.token else { return }
        do {
            let response: DashboardResponse = try await apiClient.get(path: "/dashboard", token: token)
            dailyCalorieTarget = response.today.dailyCalorieTarget
        } catch {
            // Non-critical — just won't show calorie target
        }
    }

    @MainActor
    func saveApiKey() async {
        guard canSaveApiKey, let token = authManager.token else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        struct ApiKeyRequest: Codable {
            let openaiApiKey: String
            enum CodingKeys: String, CodingKey {
                case openaiApiKey = "openai_api_key"
            }
        }

        struct MessageResponse: Codable {
            let message: String
        }

        do {
            let _: MessageResponse = try await apiClient.patch(
                path: "/settings/api-key",
                body: ApiKeyRequest(openaiApiKey: apiKey),
                token: token
            )
            successMessage = "API key updated."
            apiKey = ""
        } catch let error as APIError where error.isUnauthorized {
            authManager.handleUnauthorized()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to update API key."
        }
    }

    func logout() {
        authManager.logout()
    }
}
