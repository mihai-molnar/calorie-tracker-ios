# Calorie Tracker iOS — Design Spec

## Overview

A native SwiftUI iOS client for the existing calorie tracker backend. The app provides conversational food and weight logging via LLM, an onboarding wizard, and a progress dashboard. All business logic and data persistence remain on the FastAPI backend — the iOS app is a thin client handling auth, API communication, and UI.

**Key constraint:** The backend (FastAPI + Supabase + OpenAI) is unchanged. The iOS app consumes the same REST + SSE API endpoints as the existing React web app.

## Target

Solo user (same as web app). iOS 17+ minimum deployment target — gives access to `@Observable`, modern SwiftUI navigation, and Swift Charts without backwards-compatibility shims.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (iOS 17+) |
| Charts | Swift Charts (built-in) |
| Networking | URLSession (REST + SSE) |
| Auth | Supabase JWT (email/password) |
| Secure Storage | Keychain (Security framework) |
| Dependencies | None — all Apple frameworks |

## Architecture

The app is a stateless client. No local database — all data lives on the server.

```
[SwiftUI App] --> [URLSession] --> [FastAPI Backend] --> [Supabase + OpenAI]
                                         |
                                    Same backend as
                                    the React web app
```

### Layers

- **Views:** SwiftUI screens and components
- **ViewModels:** `@Observable` classes that hold screen state and call services
- **Services:** Networking layer (API client, SSE client, Keychain wrapper)
- **Models:** Codable structs matching API request/response shapes

### State Management

SwiftUI's `@Observable` macro (iOS 17+). No third-party state management. An `AuthManager` observable object at the app root controls the auth state and determines which flow to show (auth, onboarding, or main tabs).

## Backend API Surface

All endpoints are on the existing FastAPI backend. The iOS app sends `Authorization: Bearer <token>` on all authenticated requests.

### Auth
- `POST /auth/register` — `{ email, password }` → `{ access_token, user_id }`
- `POST /auth/login` — `{ email, password }` → `{ access_token, user_id }`
- `POST /auth/logout` — no body → `{ message }`

### Onboarding
- `POST /onboarding` — profile data → `{ daily_calorie_target, message }`

### Chat
- `GET /chat/history` — → `{ messages, total_calories, weight_kg, daily_calorie_target }`
- `POST /chat` (SSE) — `{ message }` → streamed events:
  - `message` event data: `{"text": String, "data_applied": Bool, "total_calories": Int, "weight_kg": Float?}`
  - `done` event data: empty string

### Dashboard
- `GET /dashboard` — → `{ today: {...}, history: [...] }`
- `GET /daily-logs` — `?limit=30&offset=0` → list of daily log entries

### Food Entries
- `PATCH /food-entries/{id}` — `{ estimated_calories }` → `{ message, new_total_calories }`

## Authentication

### Email/Password

Standard email/password auth through the backend's Supabase wrapper endpoints. Token stored in Keychain after login.

### Token Storage

- JWT stored in iOS Keychain (encrypted at rest by the OS)
- Persists across app launches — user stays logged in
- Cleared on logout or app uninstall
- Keychain accessed via a thin wrapper around the Security framework

### Token Expiry & Silent Re-login

Supabase JWTs expire (typically 1 hour). On login/register, the user's email and password are stored in Keychain alongside the JWT. When a 401 is received, `APIClient` automatically attempts a silent re-login using the stored credentials and retries the request. Concurrent refresh attempts (e.g. multiple views resuming from background simultaneously) coalesce onto a single in-flight refresh `Task` to avoid race conditions. If re-login fails (e.g. password changed), the user is redirected to the login screen. Credentials are cleared on logout.

### Onboarding Status Check

On app launch with a valid token, the app calls `GET /dashboard`. If it succeeds, the user is onboarded — show the main tab view. If it fails (no profile), redirect to the onboarding wizard.

## Screens & Navigation

### Navigation Structure

```
App Root (AuthManager decides)
├── Auth Flow (not authenticated)
│   ├── Login
│   └── Register
├── Onboarding Flow (authenticated, not onboarded)
│   └── Onboarding Wizard (7 steps)
└── Main App (authenticated + onboarded)
    └── TabView
        ├── Chat (tab 1, default)
        ├── Dashboard (tab 2)
        └── Settings (tab 3)
```

### Auth Screens

**Login:**
- Email text field
- Password secure field
- "Sign In" button
- Link to Register screen

**Register:**
- Email text field
- Password secure field
- "Create Account" button
- Link to Login screen

### Onboarding Wizard

One screen per field with a progress bar at the top. Back/Next navigation. Each step validates before proceeding.

| Step | Field | Input Type |
|------|-------|-----------|
| 1 | Gender | Segmented control (Male / Female / Other) |
| 2 | Age | Number picker wheel |
| 3 | Height (cm) | Slider or picker |
| 4 | Current weight (kg) | Decimal text input with numeric keyboard |
| 5 | Activity level | List selection (5 options with descriptions) |
| 6 | Target weight (kg) | Decimal text input (validated < current weight) |
| 7 | Review | Shows calculated daily calorie target, option to override |

**Timezone:** Auto-detected from the device via `TimeZone.current.identifier` and sent silently with the onboarding payload. Not a wizard step.

On completion, calls `POST /onboarding` (including timezone) and transitions to main tab view.

### Chat Tab (Primary Screen)

**Stats bar at top:**
- Calories consumed / target (e.g., "1,240 / 2,100 kcal")
- Circular progress ring showing percentage
- Today's weight (if logged)

**Message list:**
- Scrollable list of chat bubbles
- User messages right-aligned, assistant messages left-aligned
- Auto-scrolls to bottom on new messages
- Pull to refresh loads history

**Typing indicator:**
- Animated dots shown while waiting for LLM response
- Full response displayed at once when complete (no word-by-word streaming to UI)

**Input bar:**
- Text field pinned to bottom (above keyboard when active)
- Send button (disabled when empty or while waiting for response)

**Data flow:**
1. On appear: `GET /chat/history` to load today's messages + stats. Cache `daily_calorie_target` from this response for use in stats bar updates.
2. On foreground resume (`scenePhase` → `.active`): re-fetch chat history to ensure data is fresh (e.g. after midnight rollover).
3. User sends message: `POST /chat` (SSE)
4. Show typing indicator (expect 5-15s latency for OpenAI response)
5. On `message` event: hide indicator, append assistant message, update stats bar using cached `daily_calorie_target`
6. On `done` event: mark request complete

### Dashboard Tab

**Today's summary card:**
- Calories consumed / remaining
- Today's weight (or "Not logged")
- Daily calorie target

**7-day average card:**
- Average daily calories over last 7 days

**Weight trend chart:**
- Swift Charts line chart
- Last 30 days of weight data
- Points for days with weigh-ins, connected by lines
- Y-axis auto-scaled to data range with padding (not starting from zero)

**Calorie bar chart:**
- Swift Charts bar chart
- Last 30 days of daily calorie totals
- Horizontal reference line at daily calorie target

Charts and cards in a vertical scrollable layout. Dashboard data is re-fetched when the app returns to the foreground (`scenePhase` → `.active`).

### Settings Tab

- **Daily calorie target:** display current value (read-only, set during onboarding)
- **Logout button:** clears Keychain token, returns to login screen

> **Note:** The OpenAI API key is managed server-side. Users do not provide or manage an API key.

## Dark Mode

Follows iOS system setting automatically. SwiftUI handles this by default — no in-app toggle for now. All custom colors defined as adaptive (light/dark variants in asset catalog or using SwiftUI's built-in semantic colors).

## Configuration

- **API base URL:** Defined as a constant in `Configuration.swift`. Points to the production backend at `http://89.167.66.135/api` (nginx proxies `/api/` to the FastAPI backend on port 8000). Same URL for all build configurations.
- **Keychain service name:** App bundle identifier used as the Keychain service key. Stores auth token, email, and password for silent token refresh.
- **Error response format:** Backend returns `{"detail": "..."}` for errors (FastAPI default). The `APIClient` parses this for user-facing error messages.

## Error Handling

- **Network errors:** Show inline alert or banner. Chat input stays enabled so the user can retry.
- **401 Unauthorized:** Attempt silent token refresh; only redirect to login if refresh fails.
- **Rate limit (429):** Show message telling the user to wait before sending again.
- **SSE connection failure:** Show error in chat, allow retry on next send.

### SSE Implementation Note

URLSession's `bytes.lines` skips empty lines, which is how standard SSE separates events. The `SSEParser` works around this by dispatching an event as soon as both the `event:` and `data:` fields are collected, rather than waiting for the empty line delimiter.

### App Transport Security

The app uses plain HTTP (no SSL). An `Info.plist` ATS exception is configured for `89.167.66.135` and `localhost` to allow insecure HTTP loads.

## File Structure

```
CalorieTracker/
  CalorieTrackerApp.swift          # App entry point, AuthManager injection
  Configuration.swift              # API base URL, Keychain keys, build config
  Info.plist
  Assets.xcassets/
  Models/
    User.swift                     # Auth response models
    Profile.swift                  # Onboarding request model
    ChatMessage.swift              # Chat message model
    DashboardData.swift            # Dashboard response models
    FoodEntry.swift                # Food entry model
    APIError.swift                 # Error types and response parsing
  Services/
    APIClient.swift                # URLSession REST wrapper (GET, POST, PATCH)
    SSEClient.swift                # URLSession SSE handling for chat
    KeychainService.swift          # Keychain read/write/delete wrapper
    AuthManager.swift              # Observable auth state (logged in, onboarding status)
  Views/
    Auth/
      LoginView.swift
      RegisterView.swift
    Onboarding/
      OnboardingContainerView.swift  # Progress bar + step navigation
      GenderStepView.swift
      AgeStepView.swift
      HeightStepView.swift
      WeightStepView.swift
      ActivityStepView.swift
      TargetWeightStepView.swift
      ReviewStepView.swift
    Chat/
      ChatView.swift               # Main chat screen
      ChatBubbleView.swift         # Single message bubble
      StatsBarView.swift           # Top stats bar with progress ring
      TypingIndicatorView.swift    # Animated dots
    Dashboard/
      DashboardView.swift          # Main dashboard screen
      SummaryCardView.swift        # Today's summary
      WeightChartView.swift        # Swift Charts line chart
      CalorieChartView.swift       # Swift Charts bar chart
    Settings/
      SettingsView.swift
    Components/
      ProgressRingView.swift       # Circular progress indicator
  ViewModels/
    AuthViewModel.swift            # Login/register logic
    OnboardingViewModel.swift      # Onboarding step state + submission
    ChatViewModel.swift            # Messages, sending, SSE handling
    DashboardViewModel.swift       # Dashboard data fetching
    SettingsViewModel.swift        # Logout
```

## Dependencies

Zero third-party dependencies. All Apple frameworks:

- **SwiftUI** — UI
- **Swift Charts** — dashboard charts
- **Security** — Keychain access
- **Foundation** — URLSession networking

## MVP Scope

**In scope:**
- Email/password auth
- Silent token refresh via stored credentials on 401
- Onboarding wizard (one field per screen)
- Conversational chat with LLM (full response display, no word-by-word streaming)
- Dashboard with weight + calorie charts (auto-scaled Y-axis)
- Settings (logout)
- Keychain token storage (token, email, password)
- Dark mode (system-following)
- Tab bar navigation (Chat, Dashboard, Settings)
- Foreground resume data refresh (chat + dashboard)

**Out of scope (future):**
- Sign in with Apple (requires backend `/auth/apple` endpoint)
- In-app dark mode toggle
- Push notifications
- Offline support / local caching
- Widget / Live Activity
- iPad layout optimization
- Haptic feedback
- Voice input
