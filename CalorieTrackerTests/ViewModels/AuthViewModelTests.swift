import XCTest
@testable import CalorieTracker

final class AuthViewModelTests: XCTestCase {
    var viewModel: AuthViewModel!
    var authManager: AuthManager!

    override func setUp() {
        let keychain = KeychainService(service: "com.calorietracker.tests.authvm")
        authManager = AuthManager(keychainService: keychain)
        viewModel = AuthViewModel(apiClient: APIClient(), authManager: authManager)
    }

    func testInitialState() {
        XCTAssertEqual(viewModel.email, "")
        XCTAssertEqual(viewModel.password, "")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testValidationEmptyEmail() {
        XCTAssertFalse(viewModel.isValid)
    }

    func testValidationFilledFields() {
        viewModel.email = "test@test.com"
        viewModel.password = "password123"
        XCTAssertTrue(viewModel.isValid)
    }

    func testValidationShortPassword() {
        viewModel.email = "test@test.com"
        viewModel.password = "12345"
        XCTAssertFalse(viewModel.isValid)
    }
}
