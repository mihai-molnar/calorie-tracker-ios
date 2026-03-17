import XCTest
@testable import CalorieTracker

final class ChatViewModelTests: XCTestCase {
    var viewModel: ChatViewModel!

    override func setUp() {
        let keychain = KeychainService(service: "com.test.chatvm")
        let authManager = AuthManager(keychainService: keychain)
        authManager.handleLoginSuccess(token: "test-token")
        viewModel = ChatViewModel(apiClient: APIClient(), sseClient: SSEClient(), authManager: authManager)
    }

    func testInitialState() {
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertEqual(viewModel.totalCalories, 0)
        XCTAssertEqual(viewModel.dailyCalorieTarget, 0)
        XCTAssertNil(viewModel.weightKg)
        XCTAssertFalse(viewModel.isSending)
        XCTAssertEqual(viewModel.messageText, "")
    }

    func testCanSend() {
        XCTAssertFalse(viewModel.canSend)
        viewModel.messageText = "I had eggs"
        XCTAssertTrue(viewModel.canSend)
    }

    func testCannotSendWhileSending() {
        viewModel.messageText = "test"
        viewModel.isSending = true
        XCTAssertFalse(viewModel.canSend)
    }

    func testCalorieProgress() {
        viewModel.totalCalories = 1050
        viewModel.dailyCalorieTarget = 2100
        XCTAssertEqual(viewModel.calorieProgress, 0.5, accuracy: 0.01)
    }

    func testCalorieProgressZeroTarget() {
        viewModel.totalCalories = 500
        viewModel.dailyCalorieTarget = 0
        XCTAssertEqual(viewModel.calorieProgress, 0)
    }
}
