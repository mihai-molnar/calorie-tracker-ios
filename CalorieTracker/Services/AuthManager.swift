import Foundation
import Observation

enum AuthState: Equatable {
    case unauthenticated
    case loading
    case needsOnboarding
    case onboarded
}

@Observable
final class AuthManager {
    var state: AuthState = .unauthenticated
    private(set) var token: String?
    private let keychainService: KeychainService
    private var isRefreshing = false

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
        if let savedToken = keychainService.load(key: Configuration.keychainTokenKey) {
            self.token = savedToken
            self.state = .loading
        }
    }

    func handleLoginSuccess(token: String, email: String? = nil, password: String? = nil) {
        self.token = token
        try? keychainService.save(key: Configuration.keychainTokenKey, value: token)
        if let email {
            try? keychainService.save(key: Configuration.keychainEmailKey, value: email)
        }
        if let password {
            try? keychainService.save(key: Configuration.keychainPasswordKey, value: password)
        }
        self.state = .loading
    }

    func markOnboarded() {
        self.state = .onboarded
    }

    func markNeedsOnboarding() {
        self.state = .needsOnboarding
    }

    /// Attempts to silently re-login using stored credentials.
    /// Returns the new token on success, nil on failure.
    func refreshToken() async -> String? {
        guard !isRefreshing,
              let email = keychainService.load(key: Configuration.keychainEmailKey),
              let password = keychainService.load(key: Configuration.keychainPasswordKey) else {
            return nil
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let request = AuthRequest(email: email, password: password)
            let response: AuthResponse = try await APIClient().post(path: "/auth/login", body: request)
            self.token = response.accessToken
            try? keychainService.save(key: Configuration.keychainTokenKey, value: response.accessToken)
            return response.accessToken
        } catch {
            return nil
        }
    }

    func logout() {
        let tokenToRevoke = token
        self.token = nil
        keychainService.delete(key: Configuration.keychainTokenKey)
        keychainService.delete(key: Configuration.keychainEmailKey)
        keychainService.delete(key: Configuration.keychainPasswordKey)
        self.state = .unauthenticated
        // Fire-and-forget backend logout
        if let tokenToRevoke {
            Task {
                struct MessageResponse: Codable { let message: String }
                let _: MessageResponse? = try? await APIClient().post(
                    path: "/auth/logout",
                    body: EmptyBody(),
                    token: tokenToRevoke
                )
            }
        }
    }

    func handleUnauthorized() {
        self.token = nil
        keychainService.delete(key: Configuration.keychainTokenKey)
        self.state = .unauthenticated
    }
}
