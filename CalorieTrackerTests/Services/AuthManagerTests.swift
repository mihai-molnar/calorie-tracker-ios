import XCTest
@testable import CalorieTracker

final class AuthManagerTests: XCTestCase {
    var authManager: AuthManager!
    var keychain: KeychainService!

    override func setUp() {
        keychain = KeychainService(service: "com.calorietracker.tests.auth")
        authManager = AuthManager(keychainService: keychain)
    }

    override func tearDown() {
        keychain.delete(key: Configuration.keychainTokenKey)
    }

    func testInitialStateNoToken() {
        XCTAssertEqual(authManager.state, .unauthenticated)
        XCTAssertNil(authManager.token)
    }

    func testInitialStateWithToken() throws {
        try keychain.save(key: Configuration.keychainTokenKey, value: "saved-token")
        let manager = AuthManager(keychainService: keychain)
        XCTAssertEqual(manager.state, .loading)
        XCTAssertEqual(manager.token, "saved-token")
    }

    func testLoginSavesToken() throws {
        authManager.handleLoginSuccess(token: "new-token")
        XCTAssertEqual(authManager.token, "new-token")
        XCTAssertEqual(keychain.load(key: Configuration.keychainTokenKey), "new-token")
    }

    func testLogoutClearsToken() throws {
        authManager.handleLoginSuccess(token: "to-clear")
        authManager.logout()
        XCTAssertNil(authManager.token)
        XCTAssertNil(keychain.load(key: Configuration.keychainTokenKey))
        XCTAssertEqual(authManager.state, .unauthenticated)
    }

    func testHandleUnauthorizedClearsToken() throws {
        authManager.handleLoginSuccess(token: "expired")
        authManager.handleUnauthorized()
        XCTAssertNil(authManager.token)
        XCTAssertEqual(authManager.state, .unauthenticated)
    }

    func testOnboardingCompleted() {
        authManager.handleLoginSuccess(token: "tok")
        authManager.markOnboarded()
        XCTAssertEqual(authManager.state, .onboarded)
    }

    func testNeedsOnboarding() {
        authManager.handleLoginSuccess(token: "tok")
        authManager.markNeedsOnboarding()
        XCTAssertEqual(authManager.state, .needsOnboarding)
    }
}
