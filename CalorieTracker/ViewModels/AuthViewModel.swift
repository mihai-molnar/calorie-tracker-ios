import Foundation
import Observation

@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    private let apiClient: APIClient
    private let authManager: AuthManager

    init(apiClient: APIClient = APIClient(), authManager: AuthManager) {
        self.apiClient = apiClient
        self.authManager = authManager
    }

    var isValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@") &&
        password.count >= 6
    }

    @MainActor
    func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let request = AuthRequest(email: email, password: password)
            let response: AuthResponse = try await apiClient.post(path: "/auth/login", body: request)
            authManager.handleLoginSuccess(token: response.accessToken, email: email, password: password)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Something went wrong."
        }
    }

    @MainActor
    func register() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let request = AuthRequest(email: email, password: password)
            let response: AuthResponse = try await apiClient.post(path: "/auth/register", body: request)
            authManager.handleLoginSuccess(token: response.accessToken, email: email, password: password)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Something went wrong."
        }
    }
}
