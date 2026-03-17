import Foundation

enum Configuration {
    static let apiBaseURL = URL(string: "http://89.167.66.135/api")!

    static let keychainService = Bundle.main.bundleIdentifier ?? "com.calorietracker"
    static let keychainTokenKey = "auth_token"
}
