import XCTest
@testable import CalorieTracker

final class OnboardingViewModelTests: XCTestCase {
    var viewModel: OnboardingViewModel!

    override func setUp() {
        viewModel = OnboardingViewModel(
            apiClient: APIClient(),
            authManager: AuthManager(keychainService: KeychainService(service: "com.test.onboard"))
        )
    }

    func testInitialStep() {
        XCTAssertEqual(viewModel.currentStep, 0)
        XCTAssertEqual(viewModel.totalSteps, 8)
    }

    func testNextStep() {
        viewModel.gender = .male
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, 1)
    }

    func testPreviousStep() {
        viewModel.gender = .male
        viewModel.nextStep()
        viewModel.previousStep()
        XCTAssertEqual(viewModel.currentStep, 0)
    }

    func testPreviousStepAtZero() {
        viewModel.previousStep()
        XCTAssertEqual(viewModel.currentStep, 0)
    }

    func testCanAdvanceGenderStep() {
        viewModel.gender = .male
        XCTAssertTrue(viewModel.canAdvance)
    }

    func testCanAdvanceAgeStep() {
        viewModel.currentStep = 1
        viewModel.age = 25
        XCTAssertTrue(viewModel.canAdvance)
    }

    func testCannotAdvanceTargetWeightTooHigh() {
        viewModel.currentStep = 5
        viewModel.weightKg = 90
        viewModel.targetWeightKg = 95
        XCTAssertFalse(viewModel.canAdvance)
    }

    func testCanAdvanceTargetWeightValid() {
        viewModel.currentStep = 5
        viewModel.weightKg = 90
        viewModel.targetWeightKg = 80
        XCTAssertTrue(viewModel.canAdvance)
    }

    func testProgressFraction() {
        viewModel.currentStep = 4
        XCTAssertEqual(viewModel.progress, 4.0 / 8.0, accuracy: 0.01)
    }

    func testBuildOnboardingRequest() {
        viewModel.gender = .male
        viewModel.age = 30
        viewModel.heightCm = 180
        viewModel.weightKg = 90
        viewModel.activityLevel = .moderate
        viewModel.targetWeightKg = 80
        viewModel.apiKey = "sk-test"

        let request = viewModel.buildRequest()
        XCTAssertEqual(request.gender, "male")
        XCTAssertEqual(request.age, 30)
        XCTAssertEqual(request.heightCm, 180)
        XCTAssertEqual(request.weightKg, 90)
        XCTAssertEqual(request.activityLevel, "moderate")
        XCTAssertEqual(request.targetWeightKg, 80)
        XCTAssertEqual(request.openaiApiKey, "sk-test")
        XCTAssertFalse(request.timezone.isEmpty)
    }
}
