# Dashboard Redesign

## Problem

The current dashboard has usability issues that will worsen as data grows:

- X-axis date labels are truncated ("2...") and unreadable
- All history is loaded in a single API call with no pagination
- 2+ months of daily data will create an unreadable wall of bars/points
- The 7-day average card adds clutter without much value

## Design

### Backend API Change

Add pagination to `GET /dashboard`:

- **Query params**: `offset` (default 0), `limit` (default 30) — both in days
- `offset` is the number of days to skip from today; `limit` is how many days to return
- `today` summary is always included regardless of offset/limit
- History remains sorted newest-first
- **New response field**: `hasMore: Bool` — indicates whether older data exists beyond the current page

### Dashboard Layout

Top to bottom:

1. **Summary card** — unchanged (today's calories consumed, remaining, weight)
2. **Weight Trend chart** — horizontally scrollable line chart
3. **Daily Calories chart** — horizontally scrollable bar chart

The 7-day average card is removed.

### Horizontally Scrollable Charts

Both charts share the same behavior:

**Viewport and scrolling:**

- `ScrollView(.horizontal)` wrapping a `Chart` with calculated width based on data point count (~25pt per day)
- Initial scroll position: right edge (most recent data visible first), using `ScrollViewReader` with anchor or iOS 17's `scrollPosition` modifier
- Scroll left to see older data
- Infinite scroll trigger: when the scroll position is within 100pt of the left edge, call `loadMore()`
- While loading more data, show a small `ProgressView` at the left edge of the chart

**X-axis labels:**

- `DailyLogEntry.date` (String, e.g., "2026-03-17") must be parsed to `Date` for label formatting. Add a computed `parsedDate: Date` property on `DailyLogEntry` for this.
- Day-of-month as the label: "1", "5", "15", "28"
- At the first day of each month, show the month name: "Mar", "Feb", etc.
- Labels shown every ~3-5 days to avoid clutter; month boundaries are always labeled

**Other details:**

- Chart height: 200pt each
- Y-axis on the leading edge, drawn outside the ScrollView (does not scroll)
- Calorie chart retains the orange dashed target line (RuleMark)

### Navigation and Refresh Behavior

- **Returning from another tab**: keep scroll position, silently refresh the most recent 30-day page in the background. Detect tab switch via `.onAppear` on `DashboardView`.
- **App returning from background**: same — refresh latest page, keep scroll position (already wired via `scenePhase`)
- **Pull-to-refresh**: reset to right edge (most recent) and reload from scratch, clearing any older pages loaded via infinite scroll

### Pagination and Data Management (ViewModel)

**State:**

- `allEntries: [DailyLogEntry]` — accumulated across pages
- `currentOffset: Int` — starts at 0, increments by 30 per fetch
- `hasMore: Bool` — from API response
- `isLoadingMore: Bool` — prevents duplicate fetches during infinite scroll

**Properties (kept from current design):**

- `today: TodaySummary?` — always updated from the latest API response (needed by SummaryCardView and CalorieChartView for the target line)
- The existing `data: DashboardResponse?` property is replaced by the above `today` + `allEntries` split

**Methods:**

- `loadDashboard()` — initial load: clears all history, resets offset to 0, fetches first page
- `loadMore()` — called when user scrolls near the left edge: increments offset, appends older entries. No-op if `!hasMore` or `isLoadingMore`. Failures are silent (no error banner for background loads).
- `refreshLatest()` — called on tab switch / foreground: fetches offset=0&limit=30, deduplicates by `date` (keeping the freshest version), and merges into `allEntries` without touching entries beyond the first 30. Failures are silent.

**Deduplication:** Entries are deduped by `date` when merging. When `refreshLatest()` returns new data, build a dictionary keyed by date from the new page, then walk `allEntries` replacing any matching dates. If the new page contains dates not in the existing array (e.g., a new day), prepend them.

**Error handling:**

- `loadDashboard()` — shows error state with retry button (same as current)
- `loadMore()` and `refreshLatest()` — silent failures, no user-facing error (these are background operations)

## Scope of Changes

### Backend

- Add `offset` and `limit` query params to `GET /dashboard`
- Add `hasMore: Bool` to the dashboard response

### iOS — Models

- Add `hasMore` field to `DashboardResponse`
- Add computed `parsedDate: Date` property to `DailyLogEntry`

### iOS — Services (APIClient)

- Add `queryItems` parameter to `APIClient.get()` method (currently has no query parameter support)
- Update `makeRequest` to use `URLComponents` for building URLs with query items

### iOS — ViewModel (DashboardViewModel)

- Replace `data: DashboardResponse?` with `today: TodaySummary?` and `allEntries: [DailyLogEntry]`
- Remove `calculateSevenDayAverage`
- Add `currentOffset`, `hasMore`, `isLoadingMore` state
- Add `loadMore()` and `refreshLatest()` methods
- Dedup logic when merging pages
- `weightEntries(from:)` remains as a filtering helper

### iOS — Views

- `DashboardView`: remove 7-day average card, pass accumulated entries to charts, wire up `refreshLatest()` on `.onAppear` and foreground return
- `CalorieChartView` and `WeightChartView`: rewrite to use horizontal `ScrollView` wrapping the `Chart`, calculated width per data point, initial scroll position at right edge, x-axis with day-of-month labels and month name at boundaries, y-axis drawn outside the scroll area
- Add infinite scroll trigger (detect near-left-edge scroll position, call `loadMore()`)

### iOS — Tests

- Update `DashboardViewModelTests`: remove 7-day average tests, add tests for `loadMore()` dedup and `refreshLatest()` merge logic
- Update `DashboardDataTests`: add `hasMore` field to test fixtures

### Removed

- 7-day average card and `calculateSevenDayAverage` method
