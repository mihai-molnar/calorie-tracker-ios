import XCTest
@testable import CalorieTracker

final class DashboardViewModelTests: XCTestCase {
    var viewModel: DashboardViewModel!

    override func setUp() {
        let keychain = KeychainService(service: "com.test.dashvm")
        let authManager = AuthManager(keychainService: keychain)
        authManager.handleLoginSuccess(token: "test-token")
        viewModel = DashboardViewModel(apiClient: APIClient(authManager: authManager), authManager: authManager)
    }

    func testInitialState() {
        XCTAssertNil(viewModel.today)
        XCTAssertTrue(viewModel.allEntries.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isLoadingMore)
        XCTAssertFalse(viewModel.hasMore)
        XCTAssertEqual(viewModel.currentOffset, 0)
    }

    func testWeightEntries() {
        let history = [
            DailyLogEntry(date: "2026-03-17", weightKg: 89.0, totalCalories: 0),
            DailyLogEntry(date: "2026-03-16", weightKg: nil, totalCalories: 0),
            DailyLogEntry(date: "2026-03-15", weightKg: 89.5, totalCalories: 0),
        ]
        let weights = viewModel.weightEntries(from: history)
        XCTAssertEqual(weights.count, 2)
        XCTAssertEqual(weights[0].date, "2026-03-17")
    }

    func testMergeEntriesDeduplicatesByDate() {
        let existing = [
            DailyLogEntry(date: "2026-03-17", weightKg: nil, totalCalories: 1500),
            DailyLogEntry(date: "2026-03-16", weightKg: nil, totalCalories: 1800),
        ]
        let fresh = [
            DailyLogEntry(date: "2026-03-18", weightKg: nil, totalCalories: 1200),
            DailyLogEntry(date: "2026-03-17", weightKg: 89.0, totalCalories: 1600),
        ]
        let merged = viewModel.mergeEntries(existing: existing, fresh: fresh)
        XCTAssertEqual(merged.count, 3)
        // Fresh data wins for 2026-03-17
        XCTAssertEqual(merged[0].date, "2026-03-18")
        XCTAssertEqual(merged[1].date, "2026-03-17")
        XCTAssertEqual(merged[1].totalCalories, 1600)
        XCTAssertEqual(merged[2].date, "2026-03-16")
    }

    func testMergeEntriesPrependsNewDates() {
        let existing = [
            DailyLogEntry(date: "2026-03-16", weightKg: nil, totalCalories: 1800),
        ]
        let fresh = [
            DailyLogEntry(date: "2026-03-17", weightKg: nil, totalCalories: 1200),
        ]
        let merged = viewModel.mergeEntries(existing: existing, fresh: fresh)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].date, "2026-03-17")
        XCTAssertEqual(merged[1].date, "2026-03-16")
    }
}
