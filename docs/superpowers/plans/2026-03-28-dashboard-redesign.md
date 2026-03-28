# Dashboard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the dashboard with horizontally scrollable paginated charts and cleaner date labels, removing the 7-day average card.

**Architecture:** Stateless SwiftUI client hitting a paginated `GET /dashboard` endpoint. Charts use `ScrollView(.horizontal)` wrapping Swift Charts with infinite scroll to load older pages. ViewModel accumulates entries across pages and deduplicates on refresh.

**Tech Stack:** SwiftUI, Swift Charts, URLSession, `@Observable` macro (iOS 17+)

**Spec:** `docs/superpowers/specs/2026-03-28-dashboard-redesign.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `CalorieTracker/Models/DashboardData.swift` | Modify | Add `hasMore` to response, add `parsedDate` to entry |
| `CalorieTracker/Services/APIClient.swift` | Modify | Add query parameter support to `get()` |
| `CalorieTracker/ViewModels/DashboardViewModel.swift` | Rewrite | Pagination state, `loadMore()`, `refreshLatest()`, dedup |
| `CalorieTracker/Views/Dashboard/DashboardView.swift` | Rewrite | Remove 7-day avg, wire pagination, `.onAppear` refresh |
| `CalorieTracker/Views/Dashboard/CalorieChartView.swift` | Rewrite | Horizontal scroll, date-based x-axis, infinite scroll trigger |
| `CalorieTracker/Views/Dashboard/WeightChartView.swift` | Rewrite | Horizontal scroll, date-based x-axis, infinite scroll trigger |
| `CalorieTrackerTests/Models/DashboardDataTests.swift` | Modify | Add `hasMore` decoding test, `parsedDate` test |
| `CalorieTrackerTests/ViewModels/DashboardViewModelTests.swift` | Rewrite | Remove 7-day avg tests, add dedup/merge tests |

---

### Task 1: Update Models — `DashboardResponse` and `DailyLogEntry`

**Files:**
- Modify: `CalorieTracker/Models/DashboardData.swift`
- Modify: `CalorieTrackerTests/Models/DashboardDataTests.swift`

- [ ] **Step 1: Write failing test for `hasMore` decoding**

In `DashboardDataTests.swift`, add a new test:

```swift
func testDecodeDashboardResponseWithHasMore() throws {
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
            {"date": "2026-03-16", "weight_kg": 89.5, "total_calories": 1800}
        ],
        "has_more": true
    }
    """
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let response = try decoder.decode(DashboardResponse.self, from: data)
    XCTAssertTrue(response.hasMore)
    XCTAssertEqual(response.history.count, 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/DashboardDataTests/testDecodeDashboardResponseWithHasMore 2>&1 | tail -20`

Expected: FAIL — `DashboardResponse` has no `hasMore` property.

- [ ] **Step 3: Add `hasMore` to `DashboardResponse` with backward-compatible default**

In `DashboardData.swift`, update `DashboardResponse` to decode `hasMore` with a default of `false` so it works even if the backend hasn't been updated yet (e.g., `checkOnboardingStatus` in `CalorieTrackerApp.swift` decodes this type):

```swift
struct DashboardResponse: Codable {
    let today: TodaySummary
    let history: [DailyLogEntry]
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case today, history, hasMore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        today = try container.decode(TodaySummary.self, forKey: .today)
        history = try container.decode([DailyLogEntry].self, forKey: .history)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
    }
}
```

- [ ] **Step 4: Verify existing test still passes without `has_more` in JSON**

The existing `testDecodeDashboardResponse` JSON doesn't include `has_more` — it should still decode successfully with `hasMore` defaulting to `false`. No change needed to the existing test fixture.

- [ ] **Step 5: Write test for `parsedDate`**

```swift
func testDailyLogEntryParsedDate() {
    let entry = DailyLogEntry(date: "2026-03-17", weightKg: nil, totalCalories: 1500)
    let parsed = entry.parsedDate
    XCTAssertNotNil(parsed)
    let components = Calendar.current.dateComponents([.year, .month, .day], from: parsed!)
    XCTAssertEqual(components.year, 2026)
    XCTAssertEqual(components.month, 3)
    XCTAssertEqual(components.day, 17)
}
```

- [ ] **Step 6: Add `parsedDate` computed property to `DailyLogEntry`**

In `DashboardData.swift`:

```swift
struct DailyLogEntry: Codable, Identifiable {
    var id: String { date }
    let date: String
    let weightKg: Double?
    let totalCalories: Int

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var parsedDate: Date? {
        Self.dateFormatter.date(from: date)
    }

    enum CodingKeys: String, CodingKey {
        case date, weightKg, totalCalories
    }
}
```

- [ ] **Step 7: Run all DashboardData tests**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/DashboardDataTests 2>&1 | tail -20`

Expected: All PASS.

- [ ] **Step 8: Verify full project builds (including CalorieTrackerApp.swift)**

`checkOnboardingStatus` in `CalorieTrackerApp.swift` decodes `DashboardResponse` — the backward-compatible default ensures it still works even without `has_more` in the response.

Run: `xcodebuild build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

Expected: BUILD SUCCEEDED.

- [ ] **Step 9: Commit**

```bash
git add CalorieTracker/Models/DashboardData.swift CalorieTrackerTests/Models/DashboardDataTests.swift
git commit -m "feat: add hasMore and parsedDate to dashboard models"
```

---

### Task 2: Add Query Parameter Support to APIClient

**Files:**
- Modify: `CalorieTracker/Services/APIClient.swift`

- [ ] **Step 1: Update `makeRequest` to accept query items**

In `APIClient.swift`, change `makeRequest`:

```swift
private func makeRequest(path: String, method: String, queryItems: [URLQueryItem]? = nil) -> URLRequest {
    var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
    components.queryItems = queryItems
    var request = URLRequest(url: components.url!)
    request.httpMethod = method
    return request
}
```

- [ ] **Step 2: Add `queryItems` parameter to `get()` method**

```swift
func get<T: Decodable>(path: String, token: String? = nil, queryItems: [URLQueryItem]? = nil) async throws -> T {
    var request = makeRequest(path: path, method: "GET", queryItems: queryItems)
    if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
    return try await performWithRetry(request, originalToken: token)
}
```

- [ ] **Step 3: Verify project builds**

Run: `xcodebuild build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

Expected: BUILD SUCCEEDED. The new `queryItems` parameter defaults to `nil`, so all existing callers are unaffected.

- [ ] **Step 4: Commit**

```bash
git add CalorieTracker/Services/APIClient.swift
git commit -m "feat: add query parameter support to APIClient.get()"
```

---

### Task 3: Rewrite DashboardViewModel with Pagination

**Files:**
- Rewrite: `CalorieTracker/ViewModels/DashboardViewModel.swift`
- Rewrite: `CalorieTrackerTests/ViewModels/DashboardViewModelTests.swift`

- [ ] **Step 1: Write failing tests for the new ViewModel**

Replace `DashboardViewModelTests.swift` with:

```swift
import XCTest
@testable import CalorieTracker

final class DashboardViewModelTests: XCTestCase {
    var viewModel: DashboardViewModel!

    override func setUp() {
        let keychain = KeychainService(service: "com.test.dashvm")
        let authManager = AuthManager(keychainService: keychain)
        authManager.handleLoginSuccess(token: "test-token")
        viewModel = DashboardViewModel(apiClient: APIClient(authManager: authManager), authManager: authManager)
    }

    func testInitialState() {
        XCTAssertNil(viewModel.today)
        XCTAssertTrue(viewModel.allEntries.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isLoadingMore)
        XCTAssertFalse(viewModel.hasMore)
        XCTAssertEqual(viewModel.currentOffset, 0)
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

    func testMergeEntriesDeduplicatesByDate() {
        let existing = [
            DailyLogEntry(date: "2026-03-17", weightKg: nil, totalCalories: 1500),
            DailyLogEntry(date: "2026-03-16", weightKg: nil, totalCalories: 1800),
        ]
        let fresh = [
            DailyLogEntry(date: "2026-03-18", weightKg: nil, totalCalories: 1200),
            DailyLogEntry(date: "2026-03-17", weightKg: 89.0, totalCalories: 1600),
        ]
        let merged = viewModel.mergeEntries(existing: existing, fresh: fresh)
        XCTAssertEqual(merged.count, 3)
        // Fresh data wins for 2026-03-17
        XCTAssertEqual(merged[0].date, "2026-03-18")
        XCTAssertEqual(merged[1].date, "2026-03-17")
        XCTAssertEqual(merged[1].totalCalories, 1600)
        XCTAssertEqual(merged[2].date, "2026-03-16")
    }

    func testMergeEntriesPrependsNewDates() {
        let existing = [
            DailyLogEntry(date: "2026-03-16", weightKg: nil, totalCalories: 1800),
        ]
        let fresh = [
            DailyLogEntry(date: "2026-03-17", weightKg: nil, totalCalories: 1200),
        ]
        let merged = viewModel.mergeEntries(existing: existing, fresh: fresh)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].date, "2026-03-17")
        XCTAssertEqual(merged[1].date, "2026-03-16")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/DashboardViewModelTests 2>&1 | tail -20`

Expected: FAIL — `today`, `allEntries`, `mergeEntries`, etc. don't exist yet.

- [ ] **Step 3: Rewrite `DashboardViewModel`**

Replace `DashboardViewModel.swift` with:

```swift
import Foundation
import Observation

@Observable
final class DashboardViewModel {
    var today: TodaySummary?
    var allEntries: [DailyLogEntry] = []
    var isLoading = false
    var isLoadingMore = false
    var hasMore = false
    var errorMessage: String?
    var currentOffset = 0

    private let pageSize = 30
    private let apiClient: APIClient
    private let authManager: AuthManager

    init(apiClient: APIClient? = nil, authManager: AuthManager) {
        self.apiClient = apiClient ?? APIClient(authManager: authManager)
        self.authManager = authManager
    }

    func weightEntries(from history: [DailyLogEntry]) -> [DailyLogEntry] {
        history.filter { $0.weightKg != nil }
    }

    func mergeEntries(existing: [DailyLogEntry], fresh: [DailyLogEntry]) -> [DailyLogEntry] {
        var dateToEntry: [String: DailyLogEntry] = [:]
        for entry in existing {
            dateToEntry[entry.date] = entry
        }
        // Fresh data wins
        for entry in fresh {
            dateToEntry[entry.date] = entry
        }
        return dateToEntry.values.sorted { $0.date > $1.date }
    }

    @MainActor
    func loadDashboard() async {
        guard let token = authManager.token else {
            authManager.handleUnauthorized()
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            currentOffset = 0
            let queryItems = [
                URLQueryItem(name: "offset", value: "\(currentOffset)"),
                URLQueryItem(name: "limit", value: "\(pageSize)"),
            ]
            let response: DashboardResponse = try await apiClient.get(
                path: "/dashboard", token: token, queryItems: queryItems
            )
            today = response.today
            allEntries = response.history
            hasMore = response.hasMore
            currentOffset = pageSize
        } catch let error as APIError where error.isUnauthorized {
            authManager.handleUnauthorized()
        } catch {
            errorMessage = "Failed to load dashboard."
        }
    }

    @MainActor
    func loadMore() async {
        guard hasMore, !isLoadingMore, let token = authManager.token else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let queryItems = [
                URLQueryItem(name: "offset", value: "\(currentOffset)"),
                URLQueryItem(name: "limit", value: "\(pageSize)"),
            ]
            let response: DashboardResponse = try await apiClient.get(
                path: "/dashboard", token: token, queryItems: queryItems
            )
            allEntries = mergeEntries(existing: allEntries, fresh: response.history)
            hasMore = response.hasMore
            currentOffset += pageSize
        } catch {
            // Silent failure for background loads
        }
    }

    @MainActor
    func refreshLatest() async {
        guard let token = authManager.token else { return }

        do {
            let queryItems = [
                URLQueryItem(name: "offset", value: "0"),
                URLQueryItem(name: "limit", value: "\(pageSize)"),
            ]
            let response: DashboardResponse = try await apiClient.get(
                path: "/dashboard", token: token, queryItems: queryItems
            )
            today = response.today
            allEntries = mergeEntries(existing: allEntries, fresh: response.history)
        } catch {
            // Silent failure for background refresh
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing CalorieTrackerTests/DashboardViewModelTests 2>&1 | tail -20`

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/ViewModels/DashboardViewModel.swift CalorieTrackerTests/ViewModels/DashboardViewModelTests.swift
git commit -m "feat: rewrite DashboardViewModel with pagination support"
```

---

### Task 4: Rewrite All Dashboard Views (Charts + DashboardView)

These are combined into a single task because the chart views' new signatures (`isLoadingMore`, `onLoadMore`) are incompatible with the old `DashboardView`. Committing them separately would break the build.

**Files:**
- Rewrite: `CalorieTracker/Views/Dashboard/CalorieChartView.swift`
- Rewrite: `CalorieTracker/Views/Dashboard/WeightChartView.swift`
- Rewrite: `CalorieTracker/Views/Dashboard/DashboardView.swift`

- [ ] **Step 1: Rewrite `CalorieChartView`**

Replace `CalorieChartView.swift` with:

```swift
import SwiftUI
import Charts

struct CalorieChartView: View {
    let entries: [DailyLogEntry]
    let dailyTarget: Int
    let isLoadingMore: Bool
    let onLoadMore: () -> Void

    private let pointWidth: CGFloat = 25

    private var chartWidth: CGFloat {
        CGFloat(entries.count) * pointWidth
    }

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
                scrollableChart
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var scrollableChart: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    if isLoadingMore {
                        ProgressView()
                            .frame(width: 40)
                    }

                    Chart {
                        ForEach(entries) { entry in
                            if let date = entry.parsedDate {
                                BarMark(
                                    x: .value("Date", date, unit: .day),
                                    y: .value("Calories", entry.totalCalories)
                                )
                                .foregroundStyle(entry.totalCalories > dailyTarget ? .red : .blue)
                            }
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
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 3)) { value in
                            if let date = value.as(Date.self) {
                                let day = Calendar.current.component(.day, from: date)
                                if day == 1 {
                                    AxisValueLabel {
                                        VStack(spacing: 2) {
                                            Text(date, format: .dateTime.month(.abbreviated))
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                            Text("\(day)")
                                                .font(.caption2)
                                        }
                                    }
                                } else {
                                    AxisValueLabel {
                                        Text("\(day)")
                                            .font(.caption2)
                                    }
                                }
                                AxisGridLine()
                                AxisTick()
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(width: max(chartWidth, 300), height: 200)
                    .id("calorieChart")
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .named("calorieScroll")).minX) { _, newValue in
                                if newValue > -100 {
                                    onLoadMore()
                                }
                            }
                    }
                )
            }
            .coordinateSpace(name: "calorieScroll")
            .frame(height: 200)
            .onAppear {
                proxy.scrollTo("calorieChart", anchor: .trailing)
            }
        }
    }
}
```

- [ ] **Step 2: Rewrite `WeightChartView`**

Replace `WeightChartView.swift` with:

```swift
import SwiftUI
import Charts

struct WeightChartView: View {
    let entries: [DailyLogEntry]
    let isLoadingMore: Bool
    let onLoadMore: () -> Void

    private let pointWidth: CGFloat = 25

    private var chartWidth: CGFloat {
        CGFloat(entries.count) * pointWidth
    }

    private var yDomain: ClosedRange<Double> {
        let weights = entries.compactMap(\.weightKg)
        guard let min = weights.min(), let max = weights.max() else {
            return 0...100
        }
        let padding = Swift.max((max - min) * 0.5, 1.0)
        return (min - padding)...(max + padding)
    }

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
                scrollableChart
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var scrollableChart: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    if isLoadingMore {
                        ProgressView()
                            .frame(width: 40)
                    }

                    Chart(entries) { entry in
                        if let weight = entry.weightKg, let date = entry.parsedDate {
                            LineMark(
                                x: .value("Date", date, unit: .day),
                                y: .value("Weight", weight)
                            )
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Date", date, unit: .day),
                                y: .value("Weight", weight)
                            )
                            .foregroundStyle(.blue)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 3)) { value in
                            if let date = value.as(Date.self) {
                                let day = Calendar.current.component(.day, from: date)
                                if day == 1 {
                                    AxisValueLabel {
                                        VStack(spacing: 2) {
                                            Text(date, format: .dateTime.month(.abbreviated))
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                            Text("\(day)")
                                                .font(.caption2)
                                        }
                                    }
                                } else {
                                    AxisValueLabel {
                                        Text("\(day)")
                                            .font(.caption2)
                                    }
                                }
                                AxisGridLine()
                                AxisTick()
                            }
                        }
                    }
                    .chartYScale(domain: yDomain)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(width: max(chartWidth, 300), height: 200)
                    .id("weightChart")
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .named("weightScroll")).minX) { _, newValue in
                                if newValue > -100 {
                                    onLoadMore()
                                }
                            }
                    }
                )
            }
            .coordinateSpace(name: "weightScroll")
            .frame(height: 200)
            .onAppear {
                proxy.scrollTo("weightChart", anchor: .trailing)
            }
        }
    }
}
```

- [ ] **Step 3: Rewrite `DashboardView`**

Replace `DashboardView.swift` with. Note: includes `.refreshable` for pull-to-refresh (resets to right edge and reloads from scratch per spec):

```swift
import SwiftUI

struct DashboardView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if vm.isLoading && vm.today == nil {
                        ProgressView()
                    } else if vm.today != nil {
                        ScrollView {
                            VStack(spacing: 16) {
                                SummaryCardView(today: vm.today!)

                                WeightChartView(
                                    entries: vm.weightEntries(from: vm.allEntries).reversed(),
                                    isLoadingMore: vm.isLoadingMore,
                                    onLoadMore: { Task { await vm.loadMore() } }
                                )

                                CalorieChartView(
                                    entries: vm.allEntries.reversed(),
                                    dailyTarget: vm.today!.dailyCalorieTarget,
                                    isLoadingMore: vm.isLoadingMore,
                                    onLoadMore: { Task { await vm.loadMore() } }
                                )
                            }
                            .padding()
                        }
                        .refreshable {
                            await vm.loadDashboard()
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
        .onAppear {
            if let vm = viewModel, vm.today != nil {
                Task { await vm.refreshLatest() }
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, let vm = viewModel, vm.today != nil {
                Task { await vm.refreshLatest() }
            }
        }
    }
}
```

- [ ] **Step 4: Build the project**

Run: `xcodebuild build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Run all tests**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20`

Expected: All PASS.

- [ ] **Step 6: Commit**

```bash
git add CalorieTracker/Views/Dashboard/CalorieChartView.swift CalorieTracker/Views/Dashboard/WeightChartView.swift CalorieTracker/Views/Dashboard/DashboardView.swift
git commit -m "feat: rewrite dashboard views with scrollable charts and pull-to-refresh"
```

---

### Task 5: Final Verification

- [ ] **Step 1: Full clean build**

Run: `xcodebuild clean build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Full test suite**

Run: `xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`

Expected: All tests PASS.

- [ ] **Step 3: Commit plan document**

```bash
git add docs/superpowers/plans/2026-03-28-dashboard-redesign.md
git commit -m "docs: add dashboard redesign implementation plan"
```
