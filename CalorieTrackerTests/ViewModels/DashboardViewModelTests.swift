import XCTest
@testable import CalorieTracker

final class DashboardViewModelTests: XCTestCase {
    var viewModel: DashboardViewModel!

    override func setUp() {
        let keychain = KeychainService(service: "com.test.dashvm")
        let authManager = AuthManager(keychainService: keychain)
        authManager.handleLoginSuccess(token: "test-token")
        viewModel = DashboardViewModel(apiClient: APIClient(), authManager: authManager)
    }

    func testInitialState() {
        XCTAssertNil(viewModel.data)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testSevenDayAverage() {
        let history = [
            DailyLogEntry(date: "2026-03-17", weightKg: nil, totalCalories: 2000),
            DailyLogEntry(date: "2026-03-16", weightKg: nil, totalCalories: 1800),
            DailyLogEntry(date: "2026-03-15", weightKg: nil, totalCalories: 2200),
        ]
        let avg = viewModel.calculateSevenDayAverage(from: history)
        XCTAssertEqual(avg, 2000)
    }

    func testSevenDayAverageEmpty() {
        let avg = viewModel.calculateSevenDayAverage(from: [])
        XCTAssertEqual(avg, 0)
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
}
