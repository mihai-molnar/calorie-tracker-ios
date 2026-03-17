# Calorie Tracker iOS Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native SwiftUI iOS client that connects to the existing calorie tracker FastAPI backend for conversational food/weight logging, onboarding, and progress tracking.

**Architecture:** Thin client with MVVM pattern — Views observe @Observable ViewModels that call Services (APIClient, SSEClient, KeychainService). AuthManager at the app root controls navigation flow (auth → onboarding → main tabs). Zero local persistence; all data on the server.

**Tech Stack:** Swift 5.9 / SwiftUI (iOS 17+) / Swift Charts / URLSession (REST + SSE) / Keychain (Security framework) / XCTest

**Spec:** `docs/superpowers/specs/2026-03-17-calorie-tracker-ios-design.md`

---

## File Structure

```
CalorieTracker/
  CalorieTrackerApp.swift              # App entry point, AuthManager injection
  Configuration.swift                  # API base URL, Keychain keys
  Models/
    User.swift                         # AuthResponse, AuthRequest
    Profile.swift                      # OnboardingRequest, OnboardingResponse
    ChatMessage.swift                  # ChatMessage, ChatHistoryResponse, ChatSSEResponse
    DashboardData.swift                # DashboardResponse, TodaySummary, DailyLogEntry
    FoodEntry.swift                    # FoodEntryUpdateRequest, FoodEntryUpdateResponse
    APIError.swift                     # APIError struct (parses {"detail": "..."})
  Services/
    KeychainService.swift              # Save/load/delete tokens from Keychain
    APIClient.swift                    # URLSession REST wrapper (GET, POST, PATCH) with auth header
    SSEClient.swift                    # URLSession-based SSE parser for POST /chat
    AuthManager.swift                  # @Observable auth state, onboarding check, logout
  Views/
    Auth/
      LoginView.swift                  # Email/password login form
      RegisterView.swift               # Email/password registration form
    Onboarding/
      OnboardingContainerView.swift    # Progress bar + step navigation
      GenderStepView.swift             # Segmented control
      AgeStepView.swift                # Number picker
      HeightStepView.swift             # Slider or picker
      WeightStepView.swift             # Decimal input
      ActivityStepView.swift           # List selection
      TargetWeightStepView.swift       # Decimal input with validation
      ReviewStepView.swift             # Calorie target display + override
      APIKeyStepView.swift             # Text field + paste
    Chat/
      ChatView.swift                   # Main chat screen (stats + messages + input)
      ChatBubbleView.swift             # Single message bubble
      StatsBarView.swift               # Top stats bar with progress ring
      TypingIndicatorView.swift        # Animated dots
    Dashboard/
      DashboardView.swift              # Scrollable dashboard layout
      SummaryCardView.swift            # Today's summary card
      WeightChartView.swift            # Swift Charts line chart
      CalorieChartView.swift           # Swift Charts bar chart
    Settings/
      SettingsView.swift               # API key, calorie target, logout
    Components/
      ProgressRingView.swift           # Circular progress indicator (reused in chat + dashboard)
  ViewModels/
    AuthViewModel.swift                # Login/register logic, calls APIClient + AuthManager
    OnboardingViewModel.swift          # Step state, validation, submission
    ChatViewModel.swift                # Messages, send via SSE, stats state
    DashboardViewModel.swift           # Fetch dashboard data
    SettingsViewModel.swift            # Update API key, trigger logout

CalorieTrackerTests/
  Models/
    UserTests.swift                    # AuthResponse/AuthRequest Codable tests
    ChatMessageTests.swift             # ChatMessage/SSE response Codable tests
    DashboardDataTests.swift           # Dashboard response Codable tests
    APIErrorTests.swift                # Error parsing tests
  Services/
    KeychainServiceTests.swift         # Keychain save/load/delete tests
    APIClientTests.swift               # URLProtocol-mocked REST tests
    SSEClientTests.swift               # SSE line parsing tests
    AuthManagerTests.swift             # Auth state transitions tests
  ViewModels/
    AuthViewModelTests.swift           # Login/register flow tests
    OnboardingViewModelTests.swift     # Step validation + submission tests
    ChatViewModelTests.swift           # Message handling + SSE integration tests
    DashboardViewModelTests.swift      # Data fetch + formatting tests
    SettingsViewModelTests.swift       # API key update + logout tests
```

---

## Chunk 1: Project Setup, Configuration, Models, and Core Services

### Task 1: Create Xcode Project

**Files:**
- Create: Xcode project `CalorieTracker.xcodeproj` at `/Users/mihai/AI/calorie-tracker-ios/`

- [ ] **Step 1: Create the Xcode project from command line**

Open Xcode and create a new project (or run from CLI):
- Template: iOS → App
- Product Name: `CalorieTracker`
- Team: None (personal development)
- Organization Identifier: `com.calorietracker`
- Interface: SwiftUI
- Language: Swift
- Minimum Deployment: iOS 17.0
- Include Tests: Yes (Unit Tests only)

Save to `/Users/mihai/AI/calorie-tracker-ios/`

If Xcode CLI is available, this equivalent command works:

```bash
cd /Users/mihai/AI/calorie-tracker-ios
# Remove placeholder files Xcode creates — we'll write our own
# Keep CalorieTrackerApp.swift, Assets.xcassets, Info.plist
```

- [ ] **Step 2: Create directory structure**

```bash
cd /Users/mihai/AI/calorie-tracker-ios/CalorieTracker
mkdir -p Models Services Views/Auth Views/Onboarding Views/Chat Views/Dashboard Views/Settings Views/Components ViewModels
cd /Users/mihai/AI/calorie-tracker-ios/CalorieTrackerTests
mkdir -p Models Services ViewModels
```

- [ ] **Step 3: Commit**

```bash
cd /Users/mihai/AI/calorie-tracker-ios
git add -A
git commit -m "chore: initialize Xcode project with directory structure"
```

---

### Task 2: Configuration

**Files:**
- Create: `CalorieTracker/Configuration.swift`

- [ ] **Step 1: Write Configuration**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add CalorieTracker/Configuration.swift
git commit -m "feat: add Configuration with API base URL and Keychain constants"
```

---

### Task 3: API Error Model

**Files:**
- Create: `CalorieTracker/Models/APIError.swift`
- Create: `CalorieTrackerTests/Models/APIErrorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CalorieTracker

final class APIErrorTests: XCTestCase {
    func testDecodeDetailError() throws {
        let json = #"{"detail": "Invalid credentials"}"#
        let data = json.data(using: .utf8)!
        let error = try JSONDecoder().decode(APIErrorResponse.self, from: data)
        XCTAssertEqual(error.detail, "Invalid credentials")
    }

    func testAPIErrorLocalizedDescription() {
        let error = APIError.serverError(message: "Not found")
        XCTAssertEqual(error.localizedDescription, "Not found")
    }

    func testAPIErrorUnauthorized() {
        let error = APIError.unauthorized
        XCTAssertTrue(error.isUnauthorized)
    }

    func testAPIErrorNetwork() {
        let error = APIError.networkError(URLError(.notConnectedToInternet))
        XCTAssertFalse(error.isUnauthorized)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/APIErrorTests 2>&1 | tail -20`
Expected: FAIL — types not defined

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

struct APIErrorResponse: Codable {
    let detail: String
}

enum APIError: LocalizedError {
    case networkError(URLError)
    case unauthorized
    case serverError(message: String)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return error.localizedDescription
        case .unauthorized:
            return "Session expired. Please log in again."
        case .serverError(let message):
            return message
        case .decodingError:
            return "Unexpected response from server."
        case .unknown:
            return "Something went wrong."
        }
    }

    var isUnauthorized: Bool {
        if case .unauthorized = self { return true }
        return false
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/APIErrorTests 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/Models/APIError.swift CalorieTrackerTests/Models/APIErrorTests.swift
git commit -m "feat: add APIError model with error parsing"
```

---

### Task 4: Auth Models

**Files:**
- Create: `CalorieTracker/Models/User.swift`
- Create: `CalorieTrackerTests/Models/UserTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CalorieTracker

final class UserTests: XCTestCase {
    func testDecodeAuthResponse() throws {
        let json = #"{"access_token": "eyJhbGciOiJ...", "user_id": "abc-123"}"#
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)
        XCTAssertEqual(response.accessToken, "eyJhbGciOiJ...")
        XCTAssertEqual(response.userId, "abc-123")
    }

    func testEncodeAuthRequest() throws {
        let request = AuthRequest(email: "test@example.com", password: "pass123")
        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: String]
        XCTAssertEqual(dict["email"], "test@example.com")
        XCTAssertEqual(dict["password"], "pass123")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/UserTests 2>&1 | tail -20`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

struct AuthRequest: Codable {
    let email: String
    let password: String
}

struct AuthResponse: Codable {
    let accessToken: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case userId = "user_id"
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/UserTests 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/Models/User.swift CalorieTrackerTests/Models/UserTests.swift
git commit -m "feat: add Auth request/response models"
```

---

### Task 5: Chat Models

**Files:**
- Create: `CalorieTracker/Models/ChatMessage.swift`
- Create: `CalorieTrackerTests/Models/ChatMessageTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CalorieTracker

final class ChatMessageTests: XCTestCase {
    func testDecodeChatHistoryResponse() throws {
        let json = """
        {
            "messages": [
                {"role": "user", "content": "I had 3 eggs"},
                {"role": "assistant", "content": "That's about 210 kcal."}
            ],
            "total_calories": 210,
            "weight_kg": 89.2,
            "daily_calorie_target": 2100
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ChatHistoryResponse.self, from: data)
        XCTAssertEqual(response.messages.count, 2)
        XCTAssertEqual(response.messages[0].role, "user")
        XCTAssertEqual(response.totalCalories, 210)
        XCTAssertEqual(response.weightKg, 89.2)
        XCTAssertEqual(response.dailyCalorieTarget, 2100)
    }

    func testDecodeChatSSEResponse() throws {
        let json = """
        {"text": "Got it!", "data_applied": true, "total_calories": 350, "weight_kg": null}
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ChatSSEResponse.self, from: data)
        XCTAssertEqual(response.text, "Got it!")
        XCTAssertTrue(response.dataApplied)
        XCTAssertEqual(response.totalCalories, 350)
        XCTAssertNil(response.weightKg)
    }

    func testChatMessageIdentifiable() {
        let msg = ChatMessage(id: UUID(), role: "user", content: "Hello")
        XCTAssertEqual(msg.role, "user")
        XCTAssertEqual(msg.content, "Hello")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/ChatMessageTests 2>&1 | tail -20`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let role: String
    let content: String

    init(id: UUID = UUID(), role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }

    enum CodingKeys: String, CodingKey {
        case role, content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.role = try container.decode(String.self, forKey: .role)
        self.content = try container.decode(String.self, forKey: .content)
    }
}

struct ChatHistoryResponse: Codable {
    let messages: [ChatMessage]
    let totalCalories: Int
    let weightKg: Double?
    let dailyCalorieTarget: Int
}

struct ChatSSEResponse: Codable {
    let text: String
    let dataApplied: Bool
    let totalCalories: Int
    let weightKg: Double?
}

struct ChatRequest: Codable {
    let message: String
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/ChatMessageTests 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/Models/ChatMessage.swift CalorieTrackerTests/Models/ChatMessageTests.swift
git commit -m "feat: add Chat message and SSE response models"
```

---

### Task 6: Dashboard & Food Entry Models

**Files:**
- Create: `CalorieTracker/Models/DashboardData.swift`
- Create: `CalorieTracker/Models/FoodEntry.swift`
- Create: `CalorieTrackerTests/Models/DashboardDataTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CalorieTracker

final class DashboardDataTests: XCTestCase {
    func testDecodeDashboardResponse() throws {
        let json = """
        {
            "today": {
                "date": "2026-03-17",
                "weight_kg": 89.0,
                "total_calories": 1200,
                "daily_calorie_target": 2100,
                "calories_remaining": 900
            },
            "history": [
                {"date": "2026-03-16", "weight_kg": 89.5, "total_calories": 1800},
                {"date": "2026-03-15", "weight_kg": null, "total_calories": 2200}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(DashboardResponse.self, from: data)
        XCTAssertEqual(response.today.date, "2026-03-17")
        XCTAssertEqual(response.today.totalCalories, 1200)
        XCTAssertEqual(response.today.caloriesRemaining, 900)
        XCTAssertEqual(response.history.count, 2)
        XCTAssertNil(response.history[1].weightKg)
    }

    func testDecodeFoodEntryUpdateResponse() throws {
        let json = #"{"message": "Updated", "new_total_calories": 500}"#
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(FoodEntryUpdateResponse.self, from: data)
        XCTAssertEqual(response.newTotalCalories, 500)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/DashboardDataTests 2>&1 | tail -20`
Expected: FAIL

- [ ] **Step 3: Write DashboardData.swift**

```swift
import Foundation

struct DashboardResponse: Codable {
    let today: TodaySummary
    let history: [DailyLogEntry]
}

struct TodaySummary: Codable {
    let date: String
    let weightKg: Double?
    let totalCalories: Int
    let dailyCalorieTarget: Int
    let caloriesRemaining: Int
}

struct DailyLogEntry: Codable, Identifiable {
    var id: String { date }
    let date: String
    let weightKg: Double?
    let totalCalories: Int

    enum CodingKeys: String, CodingKey {
        case date, weightKg, totalCalories
    }
}
```

- [ ] **Step 4: Write FoodEntry.swift**

```swift
import Foundation

struct FoodEntryUpdateRequest: Codable {
    let estimatedCalories: Int

    enum CodingKeys: String, CodingKey {
        case estimatedCalories = "estimated_calories"
    }
}

struct FoodEntryUpdateResponse: Codable {
    let message: String
    let newTotalCalories: Int
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/DashboardDataTests 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add CalorieTracker/Models/DashboardData.swift CalorieTracker/Models/FoodEntry.swift CalorieTrackerTests/Models/DashboardDataTests.swift
git commit -m "feat: add Dashboard and FoodEntry models"
```

---

### Task 7: Onboarding Profile Model

**Files:**
- Create: `CalorieTracker/Models/Profile.swift`

- [ ] **Step 1: Write Profile model**

```swift
import Foundation

struct OnboardingRequest: Codable {
    let age: Int
    let gender: String
    let heightCm: Double
    let weightKg: Double
    let activityLevel: String
    let targetWeightKg: Double
    let dailyCalorieTarget: Int?
    let timezone: String
    let openaiApiKey: String

    enum CodingKeys: String, CodingKey {
        case age, gender, timezone
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case activityLevel = "activity_level"
        case targetWeightKg = "target_weight_kg"
        case dailyCalorieTarget = "daily_calorie_target"
        case openaiApiKey = "openai_api_key"
    }
}

struct OnboardingResponse: Codable {
    let dailyCalorieTarget: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case dailyCalorieTarget = "daily_calorie_target"
        case message
    }
}

enum Gender: String, CaseIterable {
    case male, female, other
}

enum ActivityLevel: String, CaseIterable {
    case sedentary, light, moderate, active
    case veryActive = "very_active"

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly Active"
        case .moderate: return "Moderately Active"
        case .active: return "Active"
        case .veryActive: return "Very Active"
        }
    }

    var description: String {
        switch self {
        case .sedentary: return "Little or no exercise"
        case .light: return "Light exercise 1-3 days/week"
        case .moderate: return "Moderate exercise 3-5 days/week"
        case .active: return "Hard exercise 6-7 days/week"
        case .veryActive: return "Very hard exercise, physical job"
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add CalorieTracker/Models/Profile.swift
git commit -m "feat: add Onboarding profile models and enums"
```

---

### Task 8: Keychain Service

**Files:**
- Create: `CalorieTracker/Services/KeychainService.swift`
- Create: `CalorieTrackerTests/Services/KeychainServiceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CalorieTracker

final class KeychainServiceTests: XCTestCase {
    let service = KeychainService(service: "com.calorietracker.tests")

    override func tearDown() {
        service.delete(key: "test_token")
        super.tearDown()
    }

    func testSaveAndLoad() throws {
        try service.save(key: "test_token", value: "my-jwt-token")
        let loaded = service.load(key: "test_token")
        XCTAssertEqual(loaded, "my-jwt-token")
    }

    func testLoadMissing() {
        let loaded = service.load(key: "nonexistent")
        XCTAssertNil(loaded)
    }

    func testDelete() throws {
        try service.save(key: "test_token", value: "to-be-deleted")
        service.delete(key: "test_token")
        XCTAssertNil(service.load(key: "test_token"))
    }

    func testOverwrite() throws {
        try service.save(key: "test_token", value: "first")
        try service.save(key: "test_token", value: "second")
        XCTAssertEqual(service.load(key: "test_token"), "second")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/KeychainServiceTests 2>&1 | tail -20`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import Security

final class KeychainService {
    private let service: String

    init(service: String = Configuration.keychainService) {
        self.service = service
    }

    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed with status: \(status)"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/KeychainServiceTests 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/Services/KeychainService.swift CalorieTrackerTests/Services/KeychainServiceTests.swift
git commit -m "feat: add KeychainService for secure token storage"
```

---

### Task 9: API Client

**Files:**
- Create: `CalorieTracker/Services/APIClient.swift`
- Create: `CalorieTrackerTests/Services/APIClientTests.swift`

- [ ] **Step 1: Write the failing test**

Uses URLProtocol subclass to mock network responses.

```swift
import XCTest
@testable import CalorieTracker

// MARK: - Mock URLProtocol

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            XCTFail("No request handler set")
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Tests

final class APIClientTests: XCTestCase {
    var apiClient: APIClient!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        apiClient = APIClient(baseURL: URL(string: "http://test.local")!, session: session)
    }

    func testGetRequestWithAuth() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"messages":[],"total_calories":0,"weight_kg":null,"daily_calorie_target":2100}"#.data(using: .utf8)!
            return (response, data)
        }

        let response: ChatHistoryResponse = try await apiClient.get(path: "/chat/history", token: "test-token")
        XCTAssertEqual(response.dailyCalorieTarget, 2100)
    }

    func testPostRequest() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: String]
            XCTAssertEqual(body["email"], "test@test.com")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"access_token":"tok","user_id":"uid"}"#.data(using: .utf8)!
            return (response, data)
        }

        let body = AuthRequest(email: "test@test.com", password: "pass")
        let response: AuthResponse = try await apiClient.post(path: "/auth/login", body: body)
        XCTAssertEqual(response.accessToken, "tok")
    }

    func testUnauthorizedThrows() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let data = #"{"detail":"Invalid token"}"#.data(using: .utf8)!
            return (response, data)
        }

        do {
            let _: ChatHistoryResponse = try await apiClient.get(path: "/chat/history", token: "bad")
            XCTFail("Should have thrown")
        } catch let error as APIError {
            XCTAssertTrue(error.isUnauthorized)
        }
    }

    func testServerErrorThrows() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            let data = #"{"detail":"Bad request"}"#.data(using: .utf8)!
            return (response, data)
        }

        do {
            let _: AuthResponse = try await apiClient.post(path: "/auth/login", body: AuthRequest(email: "", password: ""))
            XCTFail("Should have thrown")
        } catch let error as APIError {
            XCTAssertEqual(error.localizedDescription, "Bad request")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/APIClientTests 2>&1 | tail -20`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

struct EmptyBody: Codable {}

final class APIClient {
    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL = Configuration.apiBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func get<T: Decodable>(path: String, token: String? = nil) async throws -> T {
        var request = makeRequest(path: path, method: "GET")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try await perform(request)
    }

    func post<T: Decodable>(path: String, body: some Encodable, token: String? = nil) async throws -> T {
        var request = makeRequest(path: path, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try await perform(request)
    }

    func patch<T: Decodable>(path: String, body: some Encodable, token: String? = nil) async throws -> T {
        var request = makeRequest(path: path, method: "PATCH")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try await perform(request)
    }

    private func makeRequest(path: String, method: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        if http.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(message: errorResponse.detail)
            }
            throw APIError.serverError(message: "Request failed with status \(http.statusCode)")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/APIClientTests 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/Services/APIClient.swift CalorieTrackerTests/Services/APIClientTests.swift
git commit -m "feat: add APIClient with GET/POST/PATCH and error handling"
```

---

### Task 10: SSE Client

**Files:**
- Create: `CalorieTracker/Services/SSEClient.swift`
- Create: `CalorieTrackerTests/Services/SSEClientTests.swift`

- [ ] **Step 1: Write the failing test**

Test the SSE line parser logic (not the URLSession streaming, which requires integration tests).

```swift
import XCTest
@testable import CalorieTracker

final class SSEClientTests: XCTestCase {
    func testParseMessageEvent() throws {
        let parser = SSEParser()
        let lines = [
            "event: message",
            #"data: {"text":"Hello!","data_applied":false,"total_calories":100,"weight_kg":null}"#,
            ""
        ]
        var events: [SSEEvent] = []
        for line in lines {
            if let event = parser.feed(line: line) {
                events.append(event)
            }
        }
        XCTAssertEqual(events.count, 1)
        if case .message(let response) = events[0] {
            XCTAssertEqual(response.text, "Hello!")
            XCTAssertFalse(response.dataApplied)
            XCTAssertEqual(response.totalCalories, 100)
            XCTAssertNil(response.weightKg)
        } else {
            XCTFail("Expected message event")
        }
    }

    func testParseDoneEvent() {
        let parser = SSEParser()
        let lines = ["event: done", "data: ", ""]
        var events: [SSEEvent] = []
        for line in lines {
            if let event = parser.feed(line: line) {
                events.append(event)
            }
        }
        XCTAssertEqual(events.count, 1)
        if case .done = events[0] {
            // pass
        } else {
            XCTFail("Expected done event")
        }
    }

    func testParseMultipleEvents() {
        let parser = SSEParser()
        let lines = [
            "event: message",
            #"data: {"text":"Hi","data_applied":true,"total_calories":200,"weight_kg":89.0}"#,
            "",
            "event: done",
            "data: ",
            ""
        ]
        var events: [SSEEvent] = []
        for line in lines {
            if let event = parser.feed(line: line) {
                events.append(event)
            }
        }
        XCTAssertEqual(events.count, 2)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/SSEClientTests 2>&1 | tail -20`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

enum SSEEvent {
    case message(ChatSSEResponse)
    case done
}

final class SSEParser {
    private var currentEvent: String?
    private var currentData: String?
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func feed(line: String) -> SSEEvent? {
        if line.hasPrefix("event: ") {
            currentEvent = String(line.dropFirst(7))
            return nil
        }

        if line.hasPrefix("data: ") {
            currentData = String(line.dropFirst(6))
            return nil
        }

        // Empty line = event dispatch
        if line.isEmpty {
            defer {
                currentEvent = nil
                currentData = nil
            }

            guard let event = currentEvent else { return nil }

            if event == "done" {
                return .done
            }

            if event == "message", let data = currentData?.data(using: .utf8),
               let response = try? decoder.decode(ChatSSEResponse.self, from: data) {
                return .message(response)
            }

            return nil
        }

        return nil
    }
}

final class SSEClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = Configuration.apiBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func sendMessage(_ message: String, token: String) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent("chat"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONEncoder().encode(ChatRequest(message: message))

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw APIError.unknown
                    }

                    if http.statusCode == 401 {
                        throw APIError.unauthorized
                    }

                    guard (200...299).contains(http.statusCode) else {
                        throw APIError.serverError(message: "Chat request failed with status \(http.statusCode)")
                    }

                    let parser = SSEParser()
                    for try await line in bytes.lines {
                        if let event = parser.feed(line: line) {
                            continuation.yield(event)
                            if case .done = event {
                                break
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/SSEClientTests 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/Services/SSEClient.swift CalorieTrackerTests/Services/SSEClientTests.swift
git commit -m "feat: add SSEClient with line parser for chat streaming"
```

---

### Task 11: AuthManager

**Files:**
- Create: `CalorieTracker/Services/AuthManager.swift`
- Create: `CalorieTrackerTests/Services/AuthManagerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/AuthManagerTests 2>&1 | tail -20`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/AuthManagerTests 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/Services/AuthManager.swift CalorieTrackerTests/Services/AuthManagerTests.swift
git commit -m "feat: add AuthManager with auth state machine and Keychain persistence"
```

---

## Chunk 2: Auth Views, App Root, and Navigation

### Task 12: Auth ViewModel

**Files:**
- Create: `CalorieTracker/ViewModels/AuthViewModel.swift`
- Create: `CalorieTrackerTests/ViewModels/AuthViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CalorieTracker

final class AuthViewModelTests: XCTestCase {
    var viewModel: AuthViewModel!
    var authManager: AuthManager!

    override func setUp() {
        let keychain = KeychainService(service: "com.calorietracker.tests.authvm")
        authManager = AuthManager(keychainService: keychain)
    }

    func testInitialState() {
        viewModel = AuthViewModel(apiClient: APIClient(), authManager: authManager)
        XCTAssertEqual(viewModel.email, "")
        XCTAssertEqual(viewModel.password, "")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testValidationEmptyEmail() {
        viewModel = AuthViewModel(apiClient: APIClient(), authManager: authManager)
        XCTAssertFalse(viewModel.isValid)
    }

    func testValidationFilledFields() {
        viewModel = AuthViewModel(apiClient: APIClient(), authManager: authManager)
        viewModel.email = "test@test.com"
        viewModel.password = "password123"
        XCTAssertTrue(viewModel.isValid)
    }

    func testValidationShortPassword() {
        viewModel = AuthViewModel(apiClient: APIClient(), authManager: authManager)
        viewModel.email = "test@test.com"
        viewModel.password = "12345"
        XCTAssertFalse(viewModel.isValid)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/AuthViewModelTests 2>&1 | tail -20`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```swift
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
            authManager.handleLoginSuccess(token: response.accessToken)
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
            authManager.handleLoginSuccess(token: response.accessToken)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Something went wrong."
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/AuthViewModelTests 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/ViewModels/AuthViewModel.swift CalorieTrackerTests/ViewModels/AuthViewModelTests.swift
git commit -m "feat: add AuthViewModel with login/register and validation"
```

---

### Task 13: Login View

**Files:**
- Create: `CalorieTracker/Views/Auth/LoginView.swift`

- [ ] **Step 1: Write LoginView**

```swift
import SwiftUI

struct LoginView: View {
    @State private var viewModel: AuthViewModel
    var onNavigateToRegister: () -> Void

    init(authManager: AuthManager, onNavigateToRegister: @escaping () -> Void) {
        self._viewModel = State(initialValue: AuthViewModel(authManager: authManager))
        self.onNavigateToRegister = onNavigateToRegister
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("CalTracker")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Track your calories with AI")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Button {
                Task { await viewModel.login() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isValid || viewModel.isLoading)
            .padding(.horizontal)

            Button("Don't have an account? Sign Up") {
                onNavigateToRegister()
            }
            .font(.footnote)

            Spacer()
        }
        .padding()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add CalorieTracker/Views/Auth/LoginView.swift
git commit -m "feat: add LoginView with email/password form"
```

---

### Task 14: Register View

**Files:**
- Create: `CalorieTracker/Views/Auth/RegisterView.swift`

- [ ] **Step 1: Write RegisterView**

```swift
import SwiftUI

struct RegisterView: View {
    @State private var viewModel: AuthViewModel
    var onNavigateToLogin: () -> Void

    init(authManager: AuthManager, onNavigateToLogin: @escaping () -> Void) {
        self._viewModel = State(initialValue: AuthViewModel(authManager: authManager))
        self.onNavigateToLogin = onNavigateToLogin
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Start tracking your calories")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.newPassword)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Button {
                Task { await viewModel.register() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create Account")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isValid || viewModel.isLoading)
            .padding(.horizontal)

            Button("Already have an account? Sign In") {
                onNavigateToLogin()
            }
            .font(.footnote)

            Spacer()
        }
        .padding()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add CalorieTracker/Views/Auth/RegisterView.swift
git commit -m "feat: add RegisterView with email/password form"
```

---

### Task 15: App Root and Navigation

**Files:**
- Create: `CalorieTracker/CalorieTrackerApp.swift` (overwrite Xcode default)

- [ ] **Step 1: Write app entry point with auth routing**

```swift
import SwiftUI

@main
struct CalorieTrackerApp: App {
    @State private var authManager = AuthManager()
    @State private var showingRegister = false

    var body: some Scene {
        WindowGroup {
            Group {
                switch authManager.state {
                case .unauthenticated:
                    NavigationStack {
                        if showingRegister {
                            RegisterView(authManager: authManager) {
                                showingRegister = false
                            }
                        } else {
                            LoginView(authManager: authManager) {
                                showingRegister = true
                            }
                        }
                    }

                case .loading:
                    ProgressView("Loading...")
                        .task { await checkOnboardingStatus() }

                case .needsOnboarding:
                    Text("Onboarding placeholder")

                case .onboarded:
                    TabView {
                        Tab("Chat", systemImage: "message") {
                            Text("Chat placeholder")
                        }
                        Tab("Dashboard", systemImage: "chart.bar") {
                            Text("Dashboard placeholder")
                        }
                        Tab("Settings", systemImage: "gear") {
                            Text("Settings placeholder")
                        }
                    }
                }
            }
            .environment(authManager)
        }
    }

    private func checkOnboardingStatus() async {
        guard let token = authManager.token else {
            authManager.logout()
            return
        }
        do {
            let _: DashboardResponse = try await APIClient().get(path: "/dashboard", token: token)
            authManager.markOnboarded()
        } catch let error as APIError where error.isUnauthorized {
            authManager.handleUnauthorized()
        } catch {
            // Dashboard failed (likely no profile) — needs onboarding
            authManager.markNeedsOnboarding()
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add CalorieTracker/CalorieTrackerApp.swift
git commit -m "feat: add app root with auth/onboarding/main navigation routing"
```

---

## Chunk 3: Onboarding Flow

### Task 16: Onboarding ViewModel

**Files:**
- Create: `CalorieTracker/ViewModels/OnboardingViewModel.swift`
- Create: `CalorieTrackerTests/ViewModels/OnboardingViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/OnboardingViewModelTests 2>&1 | tail -20`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/OnboardingViewModelTests 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/ViewModels/OnboardingViewModel.swift CalorieTrackerTests/ViewModels/OnboardingViewModelTests.swift
git commit -m "feat: add OnboardingViewModel with step navigation and validation"
```

---

### Task 17: Onboarding Step Views

**Files:**
- Create: `CalorieTracker/Views/Onboarding/GenderStepView.swift`
- Create: `CalorieTracker/Views/Onboarding/AgeStepView.swift`
- Create: `CalorieTracker/Views/Onboarding/HeightStepView.swift`
- Create: `CalorieTracker/Views/Onboarding/WeightStepView.swift`
- Create: `CalorieTracker/Views/Onboarding/ActivityStepView.swift`
- Create: `CalorieTracker/Views/Onboarding/TargetWeightStepView.swift`
- Create: `CalorieTracker/Views/Onboarding/ReviewStepView.swift`
- Create: `CalorieTracker/Views/Onboarding/APIKeyStepView.swift`

- [ ] **Step 1: Write GenderStepView**

```swift
import SwiftUI

struct GenderStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("What's your gender?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Used to calculate your daily calorie target")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Gender", selection: $viewModel.gender) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    Text(gender.rawValue.capitalized).tag(gender)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }
}
```

- [ ] **Step 2: Write AgeStepView**

```swift
import SwiftUI

struct AgeStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("How old are you?")
                .font(.title2)
                .fontWeight(.semibold)

            Picker("Age", selection: $viewModel.age) {
                ForEach(10...100, id: \.self) { age in
                    Text("\(age) years").tag(age)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
        }
    }
}
```

- [ ] **Step 3: Write HeightStepView**

```swift
import SwiftUI

struct HeightStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("What's your height?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("\(Int(viewModel.heightCm)) cm")
                .font(.system(size: 48, weight: .bold, design: .rounded))

            Slider(value: $viewModel.heightCm, in: 100...250, step: 1)
                .padding(.horizontal)
        }
    }
}
```

- [ ] **Step 4: Write WeightStepView**

```swift
import SwiftUI

struct WeightStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var weightText = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("What's your current weight?")
                .font(.title2)
                .fontWeight(.semibold)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("80", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(width: 120)
                    .onChange(of: weightText) { _, newValue in
                        if let val = Double(newValue) {
                            viewModel.weightKg = val
                        }
                    }
                Text("kg")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            weightText = viewModel.weightKg.formatted(.number.precision(.fractionLength(0...1)))
        }
    }
}
```

- [ ] **Step 5: Write ActivityStepView**

```swift
import SwiftUI

struct ActivityStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Activity Level")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Button {
                        viewModel.activityLevel = level
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.displayName)
                                    .font(.headline)
                                Text(level.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.activityLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewModel.activityLevel == level ? Color.blue.opacity(0.1) : Color(.systemGray6))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}
```

- [ ] **Step 6: Write TargetWeightStepView**

```swift
import SwiftUI

struct TargetWeightStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var targetText = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("What's your target weight?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Must be less than your current weight (\(viewModel.weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("75", text: $targetText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(width: 120)
                    .onChange(of: targetText) { _, newValue in
                        if let val = Double(newValue) {
                            viewModel.targetWeightKg = val
                        }
                    }
                Text("kg")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            if viewModel.targetWeightKg >= viewModel.weightKg && !targetText.isEmpty {
                Text("Target weight must be less than current weight")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onAppear {
            targetText = viewModel.targetWeightKg.formatted(.number.precision(.fractionLength(0...1)))
        }
    }
}
```

- [ ] **Step 7: Write ReviewStepView**

```swift
import SwiftUI

struct ReviewStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var overrideText = ""
    @State private var isOverriding = false

    private var calculatedTarget: Int {
        // Mifflin-St Jeor simplified estimate (same formula as backend)
        let bmr: Double
        switch viewModel.gender {
        case .male:
            bmr = 10 * viewModel.weightKg + 6.25 * viewModel.heightCm - 5 * Double(viewModel.age) + 5
        case .female:
            bmr = 10 * viewModel.weightKg + 6.25 * viewModel.heightCm - 5 * Double(viewModel.age) - 161
        case .other:
            let male = 10 * viewModel.weightKg + 6.25 * viewModel.heightCm - 5 * Double(viewModel.age) + 5
            let female = 10 * viewModel.weightKg + 6.25 * viewModel.heightCm - 5 * Double(viewModel.age) - 161
            bmr = (male + female) / 2
        }

        let multiplier: Double
        switch viewModel.activityLevel {
        case .sedentary: multiplier = 1.2
        case .light: multiplier = 1.375
        case .moderate: multiplier = 1.55
        case .active: multiplier = 1.725
        case .veryActive: multiplier = 1.9
        }

        let tdee = bmr * multiplier
        let target = max(1200, Int(tdee - 500))
        return target
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Your Daily Target")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                Text("\(viewModel.calorieTargetOverride ?? calculatedTarget)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                Text("kcal / day")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                HStack {
                    Text("Gender")
                    Spacer()
                    Text(viewModel.gender.rawValue.capitalized)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Age")
                    Spacer()
                    Text("\(viewModel.age)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Height")
                    Spacer()
                    Text("\(Int(viewModel.heightCm)) cm")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Weight")
                    Spacer()
                    Text("\(viewModel.weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Target")
                    Spacer()
                    Text("\(viewModel.targetWeightKg.formatted(.number.precision(.fractionLength(0...1)))) kg")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Activity")
                    Spacer()
                    Text(viewModel.activityLevel.displayName)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            .padding(.horizontal)

            if isOverriding {
                HStack {
                    TextField("Custom target", text: $overrideText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: overrideText) { _, newValue in
                            viewModel.calorieTargetOverride = Int(newValue)
                        }
                    Button("Reset") {
                        isOverriding = false
                        viewModel.calorieTargetOverride = nil
                        overrideText = ""
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
            } else {
                Button("Adjust target manually") {
                    isOverriding = true
                    overrideText = "\(calculatedTarget)"
                }
                .font(.footnote)
            }
        }
    }
}
```

- [ ] **Step 8: Write APIKeyStepView**

```swift
import SwiftUI

struct APIKeyStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("OpenAI API Key")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your key is encrypted and stored securely on the server. It's used to power the AI chat.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack {
                SecureField("sk-...", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    if let clip = UIPasteboard.general.string {
                        viewModel.apiKey = clip
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
            }
            .padding(.horizontal)
        }
    }
}
```

- [ ] **Step 9: Commit**

```bash
git add CalorieTracker/Views/Onboarding/
git commit -m "feat: add all onboarding step views"
```

---

### Task 18: Onboarding Container

**Files:**
- Create: `CalorieTracker/Views/Onboarding/OnboardingContainerView.swift`

- [ ] **Step 1: Write OnboardingContainerView**

```swift
import SwiftUI

struct OnboardingContainerView: View {
    @State var viewModel: OnboardingViewModel

    init(authManager: AuthManager) {
        self._viewModel = State(initialValue: OnboardingViewModel(authManager: authManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: viewModel.progress)
                .padding(.horizontal)
                .padding(.top, 8)

            Text("Step \(viewModel.currentStep + 1) of \(viewModel.totalSteps)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()

            // Current step content
            Group {
                switch viewModel.currentStep {
                case 0: GenderStepView(viewModel: viewModel)
                case 1: AgeStepView(viewModel: viewModel)
                case 2: HeightStepView(viewModel: viewModel)
                case 3: WeightStepView(viewModel: viewModel)
                case 4: ActivityStepView(viewModel: viewModel)
                case 5: TargetWeightStepView(viewModel: viewModel)
                case 6: ReviewStepView(viewModel: viewModel)
                case 7: APIKeyStepView(viewModel: viewModel)
                default: EmptyView()
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.currentStep)

            Spacer()

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Navigation buttons
            HStack(spacing: 16) {
                if viewModel.currentStep > 0 {
                    Button("Back") {
                        viewModel.previousStep()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if viewModel.currentStep == viewModel.totalSteps - 1 {
                    Button {
                        Task { await viewModel.submit() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Get Started")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canAdvance || viewModel.isLoading)
                } else {
                    Button("Next") {
                        viewModel.nextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canAdvance)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }
}
```

- [ ] **Step 2: Wire into CalorieTrackerApp.swift**

Replace the onboarding placeholder in `CalorieTrackerApp.swift`:

```swift
// Replace:
//     case .needsOnboarding:
//         Text("Onboarding placeholder")
// With:
                case .needsOnboarding:
                    OnboardingContainerView(authManager: authManager)
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add CalorieTracker/Views/Onboarding/OnboardingContainerView.swift CalorieTracker/CalorieTrackerApp.swift
git commit -m "feat: add OnboardingContainerView with step navigation and wire into app"
```

---

## Chunk 4: Chat Screen

### Task 19: Chat ViewModel

**Files:**
- Create: `CalorieTracker/ViewModels/ChatViewModel.swift`
- Create: `CalorieTrackerTests/ViewModels/ChatViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/ChatViewModelTests 2>&1 | tail -20`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import Observation

@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var messageText = ""
    var isSending = false
    var isLoadingHistory = false
    var errorMessage: String?
    var totalCalories = 0
    var dailyCalorieTarget = 0
    var weightKg: Double?

    private let apiClient: APIClient
    private let sseClient: SSEClient
    private let authManager: AuthManager

    init(apiClient: APIClient = APIClient(), sseClient: SSEClient = SSEClient(), authManager: AuthManager) {
        self.apiClient = apiClient
        self.sseClient = sseClient
        self.authManager = authManager
    }

    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
    }

    var calorieProgress: Double {
        guard dailyCalorieTarget > 0 else { return 0 }
        return min(Double(totalCalories) / Double(dailyCalorieTarget), 1.0)
    }

    @MainActor
    func loadHistory() async {
        guard let token = authManager.token else {
            authManager.handleUnauthorized()
            return
        }

        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            let response: ChatHistoryResponse = try await apiClient.get(path: "/chat/history", token: token)
            messages = response.messages
            totalCalories = response.totalCalories
            weightKg = response.weightKg
            dailyCalorieTarget = response.dailyCalorieTarget
        } catch let error as APIError where error.isUnauthorized {
            authManager.handleUnauthorized()
        } catch {
            errorMessage = "Failed to load chat history."
        }
    }

    @MainActor
    func send() async {
        guard canSend, let token = authManager.token else { return }

        let text = messageText.trimmingCharacters(in: .whitespaces)
        messageText = ""
        isSending = true
        errorMessage = nil

        // Add user message immediately
        let userMessage = ChatMessage(role: "user", content: text)
        messages.append(userMessage)

        do {
            for try await event in sseClient.sendMessage(text, token: token) {
                switch event {
                case .message(let response):
                    let assistantMessage = ChatMessage(role: "assistant", content: response.text)
                    messages.append(assistantMessage)
                    totalCalories = response.totalCalories
                    if let weight = response.weightKg {
                        weightKg = weight
                    }
                case .done:
                    break
                }
            }
        } catch let error as APIError where error.isUnauthorized {
            authManager.handleUnauthorized()
        } catch {
            errorMessage = "Failed to send message. Try again."
        }

        isSending = false
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/ChatViewModelTests 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/ViewModels/ChatViewModel.swift CalorieTrackerTests/ViewModels/ChatViewModelTests.swift
git commit -m "feat: add ChatViewModel with history loading and SSE message sending"
```

---

### Task 20: Chat UI Components

**Files:**
- Create: `CalorieTracker/Views/Components/ProgressRingView.swift`
- Create: `CalorieTracker/Views/Chat/StatsBarView.swift`
- Create: `CalorieTracker/Views/Chat/ChatBubbleView.swift`
- Create: `CalorieTracker/Views/Chat/TypingIndicatorView.swift`

- [ ] **Step 1: Write ProgressRingView**

```swift
import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat

    init(progress: Double, lineWidth: CGFloat = 8, size: CGFloat = 50) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    progress > 1.0 ? Color.red : Color.blue,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .frame(width: size, height: size)
    }
}
```

- [ ] **Step 2: Write StatsBarView**

```swift
import SwiftUI

struct StatsBarView: View {
    let totalCalories: Int
    let dailyCalorieTarget: Int
    let weightKg: Double?
    let progress: Double

    var body: some View {
        HStack(spacing: 16) {
            ProgressRingView(progress: progress, lineWidth: 6, size: 44)
                .overlay {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .semibold))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(totalCalories) / \(dailyCalorieTarget) kcal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(max(0, dailyCalorieTarget - totalCalories)) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let weight = weightKg {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(weight.formatted(.number.precision(.fractionLength(1))))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}
```

- [ ] **Step 3: Write ChatBubbleView**

```swift
import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}
```

- [ ] **Step 4: Write TypingIndicatorView**

```swift
import SwiftUI

struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color(.systemGray3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .onAppear { animating = true }
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/Views/Components/ProgressRingView.swift CalorieTracker/Views/Chat/StatsBarView.swift CalorieTracker/Views/Chat/ChatBubbleView.swift CalorieTracker/Views/Chat/TypingIndicatorView.swift
git commit -m "feat: add chat UI components (ProgressRing, StatsBar, ChatBubble, TypingIndicator)"
```

---

### Task 21: Chat View

**Files:**
- Create: `CalorieTracker/Views/Chat/ChatView.swift`
- Modify: `CalorieTracker/CalorieTrackerApp.swift` — replace Chat placeholder

- [ ] **Step 1: Write ChatView**

```swift
import SwiftUI

struct ChatView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel: ChatViewModel?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let vm = viewModel {
                // Stats bar
                StatsBarView(
                    totalCalories: vm.totalCalories,
                    dailyCalorieTarget: vm.dailyCalorieTarget,
                    weightKg: vm.weightKg,
                    progress: vm.calorieProgress
                )
                Divider()

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(vm.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }

                            if vm.isSending {
                                TypingIndicatorView()
                                    .id("typing")
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .refreshable { await vm.loadHistory() }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: vm.messages.count) {
                        withAnimation {
                            proxy.scrollTo(vm.messages.last?.id ?? "typing", anchor: .bottom)
                        }
                    }
                    .onChange(of: vm.isSending) {
                        if vm.isSending {
                            withAnimation {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                }

                // Error message
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }

                Divider()

                // Input bar
                HStack(spacing: 12) {
                    TextField("What did you eat?", text: Binding(
                        get: { vm.messageText },
                        set: { vm.messageText = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onSubmit {
                        if vm.canSend {
                            Task { await vm.send() }
                        }
                    }

                    Button {
                        Task { await vm.send() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(!vm.canSend)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            } else {
                ProgressView()
            }
        }
        .task {
            let vm = ChatViewModel(authManager: authManager)
            self.viewModel = vm
            await vm.loadHistory()
        }
    }
}
```

- [ ] **Step 2: Wire ChatView into CalorieTrackerApp.swift**

Replace the Chat placeholder tab:

```swift
// Replace:
//     Tab("Chat", systemImage: "message") {
//         Text("Chat placeholder")
//     }
// With:
                        Tab("Chat", systemImage: "message") {
                            ChatView()
                        }
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add CalorieTracker/Views/Chat/ChatView.swift CalorieTracker/CalorieTrackerApp.swift
git commit -m "feat: add ChatView with message list, stats bar, and input"
```

---

## Chunk 5: Dashboard, Settings, and Final Wiring

### Task 22: Dashboard ViewModel

**Files:**
- Create: `CalorieTracker/ViewModels/DashboardViewModel.swift`
- Create: `CalorieTrackerTests/ViewModels/DashboardViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CalorieTracker

final class DashboardViewModelTests: XCTestCase {
    var viewModel: DashboardViewModel!

    override func setUp() {
        let keychain = KeychainService(service: "com.test.dashvm")
        let authManager = AuthManager(keychainService: keychain)
        authManager.handleLoginSuccess(token: "test-token")
        viewModel = DashboardViewModel(apiClient: APIClient(), authManager: authManager)
    }

    func testInitialState() {
        XCTAssertNil(viewModel.data)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testSevenDayAverage() {
        let history = [
            DailyLogEntry(date: "2026-03-17", weightKg: nil, totalCalories: 2000),
            DailyLogEntry(date: "2026-03-16", weightKg: nil, totalCalories: 1800),
            DailyLogEntry(date: "2026-03-15", weightKg: nil, totalCalories: 2200),
        ]
        let avg = viewModel.calculateSevenDayAverage(from: history)
        XCTAssertEqual(avg, 2000)
    }

    func testSevenDayAverageEmpty() {
        let avg = viewModel.calculateSevenDayAverage(from: [])
        XCTAssertEqual(avg, 0)
    }

    func testWeightEntries() {
        let history = [
            DailyLogEntry(date: "2026-03-17", weightKg: 89.0, totalCalories: 0),
            DailyLogEntry(date: "2026-03-16", weightKg: nil, totalCalories: 0),
            DailyLogEntry(date: "2026-03-15", weightKg: 89.5, totalCalories: 0),
        ]
        let weights = viewModel.weightEntries(from: history)
        XCTAssertEqual(weights.count, 2)
        XCTAssertEqual(weights[0].date, "2026-03-17")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/DashboardViewModelTests 2>&1 | tail -20`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import Observation

@Observable
final class DashboardViewModel {
    var data: DashboardResponse?
    var isLoading = false
    var errorMessage: String?

    private let apiClient: APIClient
    private let authManager: AuthManager

    init(apiClient: APIClient = APIClient(), authManager: AuthManager) {
        self.apiClient = apiClient
        self.authManager = authManager
    }

    func calculateSevenDayAverage(from history: [DailyLogEntry]) -> Int {
        let recent = Array(history.prefix(7))
        guard !recent.isEmpty else { return 0 }
        let total = recent.reduce(0) { $0 + $1.totalCalories }
        return total / recent.count
    }

    func weightEntries(from history: [DailyLogEntry]) -> [DailyLogEntry] {
        history.filter { $0.weightKg != nil }
    }

    @MainActor
    func loadDashboard() async {
        guard let token = authManager.token else {
            authManager.handleUnauthorized()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            data = try await apiClient.get(path: "/dashboard", token: token)
        } catch let error as APIError where error.isUnauthorized {
            authManager.handleUnauthorized()
        } catch {
            errorMessage = "Failed to load dashboard."
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/DashboardViewModelTests 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/ViewModels/DashboardViewModel.swift CalorieTrackerTests/ViewModels/DashboardViewModelTests.swift
git commit -m "feat: add DashboardViewModel with data loading and calculations"
```

---

### Task 23: Dashboard UI Components

**Files:**
- Create: `CalorieTracker/Views/Dashboard/SummaryCardView.swift`
- Create: `CalorieTracker/Views/Dashboard/WeightChartView.swift`
- Create: `CalorieTracker/Views/Dashboard/CalorieChartView.swift`

- [ ] **Step 1: Write SummaryCardView**

```swift
import SwiftUI

struct SummaryCardView: View {
    let today: TodaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(today.totalCalories)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("consumed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(today.caloriesRemaining)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(today.caloriesRemaining >= 0 ? .green : .red)
                    Text("remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let weight = today.weightKg {
                        Text(weight.formatted(.number.precision(.fractionLength(1))))
                            .font(.title)
                            .fontWeight(.bold)
                        Text("kg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("--")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("no weigh-in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}
```

- [ ] **Step 2: Write WeightChartView**

```swift
import SwiftUI
import Charts

struct WeightChartView: View {
    let entries: [DailyLogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight Trend")
                .font(.headline)

            if entries.isEmpty {
                Text("No weight data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(entries) { entry in
                    if let weight = entry.weightKg {
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", weight)
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", weight)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}
```

- [ ] **Step 3: Write CalorieChartView**

```swift
import SwiftUI
import Charts

struct CalorieChartView: View {
    let entries: [DailyLogEntry]
    let dailyTarget: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Calories")
                .font(.headline)

            if entries.isEmpty {
                Text("No calorie data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(entries) { entry in
                        BarMark(
                            x: .value("Date", entry.date),
                            y: .value("Calories", entry.totalCalories)
                        )
                        .foregroundStyle(entry.totalCalories > dailyTarget ? .red : .blue)
                    }

                    RuleMark(y: .value("Target", dailyTarget))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Target")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add CalorieTracker/Views/Dashboard/
git commit -m "feat: add dashboard UI components (SummaryCard, WeightChart, CalorieChart)"
```

---

### Task 24: Dashboard View

**Files:**
- Create: `CalorieTracker/Views/Dashboard/DashboardView.swift`
- Modify: `CalorieTracker/CalorieTrackerApp.swift` — replace Dashboard placeholder

- [ ] **Step 1: Write DashboardView**

```swift
import SwiftUI

struct DashboardView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if vm.isLoading && vm.data == nil {
                        ProgressView()
                    } else if let data = vm.data {
                        ScrollView {
                            VStack(spacing: 16) {
                                SummaryCardView(today: data.today)

                                // 7-day average
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("7-Day Average")
                                            .font(.headline)
                                        Text("\(vm.calculateSevenDayAverage(from: data.history)) kcal")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))

                                WeightChartView(entries: vm.weightEntries(from: data.history))

                                CalorieChartView(
                                    entries: Array(data.history.prefix(30)),
                                    dailyTarget: data.today.dailyCalorieTarget
                                )
                            }
                            .padding()
                        }
                    } else if let error = vm.errorMessage {
                        ContentUnavailableView {
                            Label("Error", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(error)
                        } actions: {
                            Button("Retry") {
                                Task { await vm.loadDashboard() }
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Dashboard")
        }
        .task {
            let vm = DashboardViewModel(authManager: authManager)
            self.viewModel = vm
            await vm.loadDashboard()
        }
    }
}
```

- [ ] **Step 2: Wire DashboardView into CalorieTrackerApp.swift**

Replace the Dashboard placeholder tab:

```swift
// Replace:
//     Tab("Dashboard", systemImage: "chart.bar") {
//         Text("Dashboard placeholder")
//     }
// With:
                        Tab("Dashboard", systemImage: "chart.bar") {
                            DashboardView()
                        }
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add CalorieTracker/Views/Dashboard/DashboardView.swift CalorieTracker/CalorieTrackerApp.swift
git commit -m "feat: add DashboardView with summary, charts, and 7-day average"
```

---

### Task 25: Settings ViewModel

**Files:**
- Create: `CalorieTracker/ViewModels/SettingsViewModel.swift`
- Create: `CalorieTrackerTests/ViewModels/SettingsViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CalorieTracker

final class SettingsViewModelTests: XCTestCase {
    var viewModel: SettingsViewModel!
    var authManager: AuthManager!

    override func setUp() {
        let keychain = KeychainService(service: "com.test.settingsvm")
        authManager = AuthManager(keychainService: keychain)
        authManager.handleLoginSuccess(token: "test-token")
        viewModel = SettingsViewModel(apiClient: APIClient(), authManager: authManager)
    }

    func testInitialState() {
        XCTAssertEqual(viewModel.apiKey, "")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.successMessage)
    }

    func testCanSaveApiKey() {
        XCTAssertFalse(viewModel.canSaveApiKey)
        viewModel.apiKey = "sk-new-key"
        XCTAssertTrue(viewModel.canSaveApiKey)
    }

    func testLogout() {
        viewModel.logout()
        XCTAssertEqual(authManager.state, .unauthenticated)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/SettingsViewModelTests 2>&1 | tail -20`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import Observation

@Observable
final class SettingsViewModel {
    var apiKey = ""
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    var dailyCalorieTarget: Int?

    private let apiClient: APIClient
    private let authManager: AuthManager

    init(apiClient: APIClient = APIClient(), authManager: AuthManager) {
        self.apiClient = apiClient
        self.authManager = authManager
    }

    var canSaveApiKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    @MainActor
    func loadSettings() async {
        guard let token = authManager.token else { return }
        do {
            let response: DashboardResponse = try await apiClient.get(path: "/dashboard", token: token)
            dailyCalorieTarget = response.today.dailyCalorieTarget
        } catch {
            // Non-critical — just won't show calorie target
        }
    }

    @MainActor
    func saveApiKey() async {
        guard canSaveApiKey, let token = authManager.token else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        struct ApiKeyRequest: Codable {
            let openaiApiKey: String
            enum CodingKeys: String, CodingKey {
                case openaiApiKey = "openai_api_key"
            }
        }

        struct MessageResponse: Codable {
            let message: String
        }

        do {
            let _: MessageResponse = try await apiClient.patch(
                path: "/settings/api-key",
                body: ApiKeyRequest(openaiApiKey: apiKey),
                token: token
            )
            successMessage = "API key updated."
            apiKey = ""
        } catch let error as APIError where error.isUnauthorized {
            authManager.handleUnauthorized()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to update API key."
        }
    }

    func logout() {
        authManager.logout()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/SettingsViewModelTests 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/ViewModels/SettingsViewModel.swift CalorieTrackerTests/ViewModels/SettingsViewModelTests.swift
git commit -m "feat: add SettingsViewModel with API key update and logout"
```

---

### Task 26: Settings View

**Files:**
- Create: `CalorieTracker/Views/Settings/SettingsView.swift`
- Modify: `CalorieTracker/CalorieTrackerApp.swift` — replace Settings placeholder

- [ ] **Step 1: Write SettingsView**

```swift
import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    Form {
                        Section("OpenAI API Key") {
                            SecureField("New API key", text: Binding(
                                get: { vm.apiKey },
                                set: { vm.apiKey = $0 }
                            ))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                            Button {
                                Task { await vm.saveApiKey() }
                            } label: {
                                if vm.isLoading {
                                    ProgressView()
                                } else {
                                    Text("Update Key")
                                }
                            }
                            .disabled(!vm.canSaveApiKey)

                            if let success = vm.successMessage {
                                Text(success)
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }

                            if let error = vm.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }

                        if let target = vm.dailyCalorieTarget {
                            Section("Daily Calorie Target") {
                                Text("\(target) kcal")
                            }
                        }

                        Section {
                            Button("Log Out", role: .destructive) {
                                vm.logout()
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Settings")
        }
        .task {
            let vm = SettingsViewModel(authManager: authManager)
            self.viewModel = vm
            await vm.loadSettings()
        }
    }
}
```

- [ ] **Step 2: Wire SettingsView into CalorieTrackerApp.swift**

Replace the Settings placeholder tab:

```swift
// Replace:
//     Tab("Settings", systemImage: "gear") {
//         Text("Settings placeholder")
//     }
// With:
                        Tab("Settings", systemImage: "gear") {
                            SettingsView()
                        }
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run all tests**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/Views/Settings/SettingsView.swift CalorieTracker/CalorieTrackerApp.swift
git commit -m "feat: add SettingsView and complete all tab wiring"
```

---

### Task 27: Final Cleanup and Verify

- [ ] **Step 1: Remove Xcode-generated ContentView.swift if it exists**

```bash
rm -f CalorieTracker/ContentView.swift
```

- [ ] **Step 2: Full build + test**

Run: `xcodebuild build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove Xcode boilerplate, final cleanup"
```
