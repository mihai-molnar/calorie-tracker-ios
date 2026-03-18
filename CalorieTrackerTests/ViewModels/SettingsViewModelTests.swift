import XCTest
@testable import CalorieTracker

final class SettingsViewModelTests: XCTestCase {
    var viewModel: SettingsViewModel!
    var authManager: AuthManager!

    override func setUp() {
        let keychain = KeychainService(service: "com.test.settingsvm")
        authManager = AuthManager(keychainService: keychain)
        authManager.handleLoginSuccess(token: "test-token")
        viewModel = SettingsViewModel(apiClient: APIClient(), authManager: authManager)
    }

    func testInitialState() {
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.dailyCalorieTarget)
    }

    func testLogout() {
        viewModel.logout()
        XCTAssertEqual(authManager.state, .unauthenticated)
    }
}
