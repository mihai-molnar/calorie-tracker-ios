import Foundation
import Observation

@Observable
final class OnboardingViewModel {
    var currentStep = 0
    let totalSteps = 8

    // Step data
    var gender: Gender = .male
    var age: Int = 25
    var heightCm: Double = 170
    var weightKg: Double = 80
    var activityLevel: ActivityLevel = .moderate
    var targetWeightKg: Double = 75
    var calorieTargetOverride: Int?
    var apiKey: String = ""

    var isLoading = false
    var errorMessage: String?

    private let apiClient: APIClient
    private let authManager: AuthManager

    init(apiClient: APIClient = APIClient(), authManager: AuthManager) {
        self.apiClient = apiClient
        self.authManager = authManager
    }

    var progress: Double {
        Double(currentStep) / Double(totalSteps)
    }

    var canAdvance: Bool {
        switch currentStep {
        case 0: return true // gender always has a selection
        case 1: return age > 0 && age < 150
        case 2: return heightCm > 50 && heightCm < 300
        case 3: return weightKg > 20 && weightKg < 500
        case 4: return true // activity always has a selection
        case 5: return targetWeightKg > 20 && targetWeightKg < weightKg
        case 6: return true // review step
        case 7: return !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
        default: return false
        }
    }

    func nextStep() {
        guard currentStep < totalSteps - 1 else { return }
        currentStep += 1
    }

    func previousStep() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }

    func buildRequest() -> OnboardingRequest {
        OnboardingRequest(
            age: age,
            gender: gender.rawValue,
            heightCm: heightCm,
            weightKg: weightKg,
            activityLevel: activityLevel.rawValue,
            targetWeightKg: targetWeightKg,
            dailyCalorieTarget: calorieTargetOverride,
            timezone: TimeZone.current.identifier,
            openaiApiKey: apiKey
        )
    }

    @MainActor
    func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let token = authManager.token else {
            authManager.handleUnauthorized()
            return
        }

        do {
            let _: OnboardingResponse = try await apiClient.post(
                path: "/onboarding",
                body: buildRequest(),
                token: token
            )
            authManager.markOnboarded()
        } catch let error as APIError where error.isUnauthorized {
            authManager.handleUnauthorized()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Something went wrong."
        }
    }
}
