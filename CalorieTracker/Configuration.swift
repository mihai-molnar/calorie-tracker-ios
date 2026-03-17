import Foundation

enum Configuration {
    #if DEBUG
    static let apiBaseURL = URL(string: "http://localhost:8000")!
    #else
    static let apiBaseURL = URL(string: "https://your-production-url.com")!
    #endif

    static let keychainService = Bundle.main.bundleIdentifier ?? "com.calorietracker"
    static let keychainTokenKey = "auth_token"
}
