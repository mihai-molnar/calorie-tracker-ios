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

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
        if let savedToken = keychainService.load(key: Configuration.keychainTokenKey) {
            self.token = savedToken
            self.state = .loading
        }
    }

    func handleLoginSuccess(token: String) {
        self.token = token
        try? keychainService.save(key: Configuration.keychainTokenKey, value: token)
        self.state = .loading
    }

    func markOnboarded() {
        self.state = .onboarded
    }

    func markNeedsOnboarding() {
        self.state = .needsOnboarding
    }

    func logout() {
        let tokenToRevoke = token
        self.token = nil
        keychainService.delete(key: Configuration.keychainTokenKey)
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
