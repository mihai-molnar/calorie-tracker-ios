import Foundation

enum Configuration {
    #if DEBUG
    static let apiBaseURL = URL(string: "http://localhost:8000")!
    #else
    static let apiBaseURL = URL(string: "http://89.167.66.135/api")!
    #endif

    static let keychainService = Bundle.main.bundleIdentifier ?? "com.calorietracker"
    static let keychainTokenKey = "auth_token"
}
