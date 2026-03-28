import Foundation
import Observation

@Observable
final class DashboardViewModel {
    var today: TodaySummary?
    var allEntries: [DailyLogEntry] = []
    var isLoading = false
    var isLoadingMore = false
    var hasMore = false
    var errorMessage: String?
    var currentOffset = 0

    private let pageSize = 30
    private let apiClient: APIClient
    private let authManager: AuthManager

    init(apiClient: APIClient? = nil, authManager: AuthManager) {
        self.apiClient = apiClient ?? APIClient(authManager: authManager)
        self.authManager = authManager
    }

    func weightEntries(from history: [DailyLogEntry]) -> [DailyLogEntry] {
        history.filter { $0.weightKg != nil }
    }

    func mergeEntries(existing: [DailyLogEntry], fresh: [DailyLogEntry]) -> [DailyLogEntry] {
        var dateToEntry: [String: DailyLogEntry] = [:]
        for entry in existing {
            dateToEntry[entry.date] = entry
        }
        // Fresh data wins
        for entry in fresh {
            dateToEntry[entry.date] = entry
        }
        return dateToEntry.values.sorted { $0.date > $1.date }
    }

    @MainActor
    func loadDashboard() async {
        guard let token = authManager.token else {
            authManager.handleUnauthorized()
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            currentOffset = 0
            let queryItems = [
                URLQueryItem(name: "offset", value: "\(currentOffset)"),
                URLQueryItem(name: "limit", value: "\(pageSize)"),
            ]
            let response: DashboardResponse = try await apiClient.get(
                path: "/dashboard", token: token, queryItems: queryItems
            )
            today = response.today
            allEntries = response.history
            hasMore = response.hasMore
            currentOffset = pageSize
        } catch let error as APIError where error.isUnauthorized {
            authManager.handleUnauthorized()
        } catch {
            errorMessage = "Failed to load dashboard."
        }
    }

    @MainActor
    func loadMore() async {
        guard hasMore, !isLoadingMore, let token = authManager.token else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let queryItems = [
                URLQueryItem(name: "offset", value: "\(currentOffset)"),
                URLQueryItem(name: "limit", value: "\(pageSize)"),
            ]
            let response: DashboardResponse = try await apiClient.get(
                path: "/dashboard", token: token, queryItems: queryItems
            )
            allEntries = mergeEntries(existing: allEntries, fresh: response.history)
            hasMore = response.hasMore
            currentOffset += pageSize
        } catch {
            // Silent failure for background loads
        }
    }

    @MainActor
    func refreshLatest() async {
        guard let token = authManager.token else { return }

        do {
            let queryItems = [
                URLQueryItem(name: "offset", value: "0"),
                URLQueryItem(name: "limit", value: "\(pageSize)"),
            ]
            let response: DashboardResponse = try await apiClient.get(
                path: "/dashboard", token: token, queryItems: queryItems
            )
            today = response.today
            allEntries = mergeEntries(existing: allEntries, fresh: response.history)
        } catch {
            // Silent failure for background refresh
        }
    }
}
