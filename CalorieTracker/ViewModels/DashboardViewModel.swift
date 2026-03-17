import Foundation
import Observation

@Observable
final class DashboardViewModel {
    var data: DashboardResponse?
    var isLoading = false
    var errorMessage: String?

    private let apiClient: APIClient
    private let authManager: AuthManager

    init(apiClient: APIClient = APIClient(), authManager: AuthManager) {
        self.apiClient = apiClient
        self.authManager = authManager
    }

    func calculateSevenDayAverage(from history: [DailyLogEntry]) -> Int {
        let recent = Array(history.prefix(7))
        guard !recent.isEmpty else { return 0 }
        let total = recent.reduce(0) { $0 + $1.totalCalories }
        return total / recent.count
    }

    func weightEntries(from history: [DailyLogEntry]) -> [DailyLogEntry] {
        history.filter { $0.weightKg != nil }
    }

    @MainActor
    func loadDashboard() async {
        guard let token = authManager.token else {
            authManager.handleUnauthorized()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            data = try await apiClient.get(path: "/dashboard", token: token)
        } catch let error as APIError where error.isUnauthorized {
            authManager.handleUnauthorized()
        } catch {
            errorMessage = "Failed to load dashboard."
        }
    }
}
