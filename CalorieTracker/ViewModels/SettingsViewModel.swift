import Foundation
import Observation

@Observable
final class SettingsViewModel {
    var isLoading = false
    var errorMessage: String?
    var dailyCalorieTarget: Int?

    private let apiClient: APIClient
    private let authManager: AuthManager

    init(apiClient: APIClient? = nil, authManager: AuthManager) {
        self.apiClient = apiClient ?? APIClient(authManager: authManager)
        self.authManager = authManager
    }

    @MainActor
    func loadSettings() async {
        guard let token = authManager.token else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response: DashboardResponse = try await apiClient.get(path: "/dashboard", token: token)
            dailyCalorieTarget = response.today.dailyCalorieTarget
        } catch {
            // Non-critical — just won't show calorie target
        }
    }

    func logout() {
        authManager.logout()
    }
}
