# Remove BYOK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace per-user OpenAI API keys with a single server-managed key, removing all BYOK infrastructure across backend, iOS, and web frontend.

**Architecture:** The backend switches from decrypting per-user keys at request time to reading a single `OPENAI_API_KEY` from the environment. All client-side API key collection UI and related backend endpoints are removed. The `user_api_keys` table is dropped.

**Tech Stack:** FastAPI (Python), SwiftUI (iOS 17+), React (TypeScript), Supabase (PostgreSQL)

**Spec:** `docs/superpowers/specs/2026-03-18-remove-byok-design.md`

**Repositories:**
- Backend + Web: `/Users/mihai/AI/calorie-tracker`
- iOS: `/Users/mihai/AI/calorie-tracker-ios`

---

### Task 1: Backend — Update config and environment

**Files:**
- Modify: `/Users/mihai/AI/calorie-tracker/backend/app/config.py`
- Modify: `/Users/mihai/AI/calorie-tracker/backend/.env.example`

- [ ] **Step 1: Update `config.py` — replace `encryption_key` with `openai_api_key`**

```python
class Settings(BaseSettings):
    supabase_url: str
    supabase_service_key: str
    supabase_jwt_secret: str
    openai_api_key: str
    frontend_url: str = "http://localhost:5173"

    class Config:
        env_file = ".env"
```

- [ ] **Step 2: Update `.env.example` — replace `ENCRYPTION_KEY` with `OPENAI_API_KEY`**

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key
SUPABASE_JWT_SECRET=your-jwt-secret
OPENAI_API_KEY=sk-your-key-here
FRONTEND_URL=http://localhost:5173
```

- [ ] **Step 3: Update `.env` on the server — add `OPENAI_API_KEY`, remove `ENCRYPTION_KEY`**

This is a manual step. Add the actual OpenAI API key to the production `.env` file.

- [ ] **Step 4: Commit**

```bash
git add backend/app/config.py .env.example
git commit -m "refactor: replace encryption_key with openai_api_key in config"
```

---

### Task 2: Backend — Remove settings router and clean up crypto imports

> **Important:** Tasks 2-4 remove all crypto imports before deleting the crypto module. Do not run backend tests until Task 4 is complete.

**Files:**
- Delete: `/Users/mihai/AI/calorie-tracker/backend/app/routers/settings.py`
- Modify: `/Users/mihai/AI/calorie-tracker/backend/app/main.py`
- Modify: `/Users/mihai/AI/calorie-tracker/backend/app/routers/onboarding.py`
- Modify: `/Users/mihai/AI/calorie-tracker/backend/app/routers/chat.py`

- [ ] **Step 1: Delete `settings.py` router**

```bash
rm backend/app/routers/settings.py
```

- [ ] **Step 2: Remove settings router from `main.py`**

Change line 16 from:
```python
from app.routers import auth, onboarding, chat, dashboard, food_entries, settings as settings_router
```
to:
```python
from app.routers import auth, onboarding, chat, dashboard, food_entries
```

Remove line 23:
```python
app.include_router(settings_router.router)
```

- [ ] **Step 3: Remove crypto import from `onboarding.py`**

Remove line 10:
```python
from app.services.crypto import encrypt_api_key
```

- [ ] **Step 4: Remove crypto import from `chat.py`**

Remove line 13:
```python
from app.services.crypto import decrypt_api_key
```

Add this import (needed in Task 4):
```python
from app.config import settings
```

- [ ] **Step 5: Commit**

```bash
git add -u backend/app/routers/settings.py backend/app/main.py backend/app/routers/onboarding.py backend/app/routers/chat.py
git commit -m "refactor: remove settings router and all crypto imports"
```

---

### Task 3: Backend — Delete crypto infrastructure

**Files:**
- Delete: `/Users/mihai/AI/calorie-tracker/backend/app/services/crypto.py`
- Delete: `/Users/mihai/AI/calorie-tracker/backend/app/tests/test_crypto.py`
- Modify: `/Users/mihai/AI/calorie-tracker/backend/requirements.txt`

- [ ] **Step 1: Delete `crypto.py`**

```bash
rm backend/app/services/crypto.py
```

- [ ] **Step 2: Delete `test_crypto.py`**

```bash
rm backend/app/tests/test_crypto.py
```

- [ ] **Step 3: Remove `cryptography` from `requirements.txt`**

Remove this line:
```
cryptography==44.0.0
```

- [ ] **Step 4: Commit**

```bash
git add -u backend/app/services/crypto.py backend/app/tests/test_crypto.py backend/requirements.txt
git commit -m "chore: remove crypto service and cryptography dependency"
```

---

### Task 4: Backend — Update onboarding endpoint

**Files:**
- Modify: `/Users/mihai/AI/calorie-tracker/backend/app/routers/onboarding.py`

- [ ] **Step 1: Remove `openai_api_key` from `OnboardingRequest` model**

Remove line 24:
```python
    openai_api_key: str
```

- [ ] **Step 2: Remove API key storage logic from the endpoint**

Remove lines 83-86:
```python
    encrypted = encrypt_api_key(body.openai_api_key)
    supabase.table("user_api_keys").upsert({
        "user_id": user_id, "provider": "openai", "encrypted_key": encrypted,
    }).execute()
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/routers/onboarding.py
git commit -m "refactor: remove API key from onboarding request"
```

---

### Task 5: Backend — Update chat endpoint to use server key

**Files:**
- Modify: `/Users/mihai/AI/calorie-tracker/backend/app/routers/chat.py`

- [ ] **Step 1: Replace per-user key lookup with server key**

Remove lines 184-191:
```python
    api_key_row = (
        supabase.table("user_api_keys").select("encrypted_key")
        .eq("user_id", user_id).single().execute()
    )
    if not api_key_row.data:
        raise HTTPException(status_code=400, detail="No API key configured")

    api_key = decrypt_api_key(api_key_row.data["encrypted_key"])
```

- [ ] **Step 2: Update OpenAI client instantiation**

Change line 231:
```python
    client = OpenAI(api_key=api_key)
```
to:
```python
    client = OpenAI(api_key=settings.openai_api_key)
```

- [ ] **Step 3: Verify backend starts and tests pass**

> **Note:** `OPENAI_API_KEY` must be set in `.env` (or environment) before running, since `config.py` requires it at import time.

```bash
cd /Users/mihai/AI/calorie-tracker/backend
python -m pytest app/tests/ -v
```

Expected: All remaining tests pass (crypto tests are gone).

- [ ] **Step 4: Commit**

```bash
git add backend/app/routers/chat.py
git commit -m "refactor: use server-side OpenAI API key in chat endpoint"
```

---

### Task 6: Backend — Database migration to drop `user_api_keys` table

**Files:**
- Create: `/Users/mihai/AI/calorie-tracker/supabase/migrations/20260318000001_drop_user_api_keys.sql`

- [ ] **Step 1: Create migration file**

```sql
-- Remove per-user API key storage (BYOK feature removed)
-- User data in user_profiles, daily_logs, food_entries, chat_messages is unaffected.
drop table if exists public.user_api_keys;
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/20260318000001_drop_user_api_keys.sql
git commit -m "migration: drop user_api_keys table"
```

---

### Task 7: iOS — Remove API key from data model

**Files:**
- Modify: `/Users/mihai/AI/calorie-tracker-ios/CalorieTracker/Models/Profile.swift`

- [ ] **Step 1: Remove `openaiApiKey` from `OnboardingRequest`**

Remove line 12:
```swift
    let openaiApiKey: String
```

Remove from `CodingKeys` enum (line 21):
```swift
        case openaiApiKey = "openai_api_key"
```

Final `OnboardingRequest`:
```swift
struct OnboardingRequest: Codable {
    let age: Int
    let gender: String
    let heightCm: Double
    let weightKg: Double
    let activityLevel: String
    let targetWeightKg: Double
    let dailyCalorieTarget: Int?
    let timezone: String

    enum CodingKeys: String, CodingKey {
        case age, gender, timezone
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case activityLevel = "activity_level"
        case targetWeightKg = "target_weight_kg"
        case dailyCalorieTarget = "daily_calorie_target"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add CalorieTracker/Models/Profile.swift
git commit -m "refactor: remove openaiApiKey from OnboardingRequest model"
```

---

### Task 8: iOS — Update OnboardingViewModel

**Files:**
- Modify: `/Users/mihai/AI/calorie-tracker-ios/CalorieTracker/ViewModels/OnboardingViewModel.swift`

- [ ] **Step 1: Change `totalSteps` from 8 to 7**

```swift
    let totalSteps = 7
```

- [ ] **Step 2: Remove `apiKey` property**

Remove line 17:
```swift
    var apiKey: String = ""
```

- [ ] **Step 3: Remove `case 7` from `canAdvance`**

Remove line 43:
```swift
        case 7: return !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
```

- [ ] **Step 4: Remove `openaiApiKey` from `buildRequest()`**

Update `buildRequest()` to:
```swift
    func buildRequest() -> OnboardingRequest {
        OnboardingRequest(
            age: age,
            gender: gender.rawValue,
            heightCm: heightCm,
            weightKg: weightKg,
            activityLevel: activityLevel.rawValue,
            targetWeightKg: targetWeightKg,
            dailyCalorieTarget: calorieTargetOverride,
            timezone: TimeZone.current.identifier
        )
    }
```

- [ ] **Step 5: Commit**

```bash
git add CalorieTracker/ViewModels/OnboardingViewModel.swift
git commit -m "refactor: remove API key step from onboarding view model"
```

---

### Task 9: iOS — Remove APIKeyStepView and update container

**Files:**
- Delete: `/Users/mihai/AI/calorie-tracker-ios/CalorieTracker/Views/Onboarding/APIKeyStepView.swift`
- Modify: `/Users/mihai/AI/calorie-tracker-ios/CalorieTracker/Views/Onboarding/OnboardingContainerView.swift`

- [ ] **Step 1: Delete `APIKeyStepView.swift` and remove from Xcode project**

```bash
rm CalorieTracker/Views/Onboarding/APIKeyStepView.swift
```

The Xcode project file (`CalorieTracker.xcodeproj/project.pbxproj`) contains references to this file that must also be removed — specifically the `PBXBuildFile`, `PBXFileReference`, `PBXGroup` children entry, and `Sources` build phase entry for `APIKeyStepView.swift`. Remove all lines referencing `APIKeyStepView` from `project.pbxproj`.

- [ ] **Step 2: Remove `case 7` from `OnboardingContainerView.swift`**

Remove line 34:
```swift
                case 7: APIKeyStepView(viewModel: viewModel)
```

The `case 6: ReviewStepView(...)` now becomes the last step before `default:`.

- [ ] **Step 3: Commit**

```bash
git add -u CalorieTracker/Views/Onboarding/
git add CalorieTracker/Views/Onboarding/OnboardingContainerView.swift
git commit -m "refactor: remove APIKeyStepView from onboarding flow"
```

---

### Task 10: iOS — Simplify SettingsViewModel

**Files:**
- Modify: `/Users/mihai/AI/calorie-tracker-ios/CalorieTracker/ViewModels/SettingsViewModel.swift`

- [ ] **Step 1: Remove all API key related properties and methods**

Remove:
- `var apiKey = ""` (line 6)
- `var successMessage: String?` (line 9) — only used for API key feedback
- `var canSaveApiKey` computed property (lines 20-22)
- `saveApiKey()` method (lines 35-69)

Final file:
```swift
import Foundation
import Observation

@Observable
final class SettingsViewModel {
    var isLoading = false
    var errorMessage: String?
    var dailyCalorieTarget: Int?

    private let apiClient: APIClient
    private let authManager: AuthManager

    init(apiClient: APIClient? = nil, authManager: AuthManager) {
        self.apiClient = apiClient ?? APIClient(authManager: authManager)
        self.authManager = authManager
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

    func logout() {
        authManager.logout()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add CalorieTracker/ViewModels/SettingsViewModel.swift
git commit -m "refactor: remove API key management from SettingsViewModel"
```

---

### Task 11: iOS — Simplify SettingsView

**Files:**
- Modify: `/Users/mihai/AI/calorie-tracker-ios/CalorieTracker/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Remove the "OpenAI API Key" section**

Remove the entire `Section("OpenAI API Key")` block (lines 12-42). Keep the calorie target section and logout button.

Updated Form content:
```swift
                    Form {
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
```

- [ ] **Step 2: Commit**

```bash
git add CalorieTracker/Views/Settings/SettingsView.swift
git commit -m "refactor: remove API key section from settings UI"
```

---

### Task 12: iOS — Update tests

**Files:**
- Modify: `/Users/mihai/AI/calorie-tracker-ios/CalorieTrackerTests/ViewModels/OnboardingViewModelTests.swift`
- Modify: `/Users/mihai/AI/calorie-tracker-ios/CalorieTrackerTests/ViewModels/SettingsViewModelTests.swift`

- [ ] **Step 1: Update `OnboardingViewModelTests.swift`**

Update `testInitialStep`:
```swift
    func testInitialStep() {
        XCTAssertEqual(viewModel.currentStep, 0)
        XCTAssertEqual(viewModel.totalSteps, 7)
    }
```

Update `testProgressFraction`:
```swift
    func testProgressFraction() {
        viewModel.currentStep = 4
        XCTAssertEqual(viewModel.progress, 4.0 / 7.0, accuracy: 0.01)
    }
```

Update `testBuildOnboardingRequest` — remove `apiKey` setup and assertion:
```swift
    func testBuildOnboardingRequest() {
        viewModel.gender = .male
        viewModel.age = 30
        viewModel.heightCm = 180
        viewModel.weightKg = 90
        viewModel.activityLevel = .moderate
        viewModel.targetWeightKg = 80

        let request = viewModel.buildRequest()
        XCTAssertEqual(request.gender, "male")
        XCTAssertEqual(request.age, 30)
        XCTAssertEqual(request.heightCm, 180)
        XCTAssertEqual(request.weightKg, 90)
        XCTAssertEqual(request.activityLevel, "moderate")
        XCTAssertEqual(request.targetWeightKg, 80)
        XCTAssertFalse(request.timezone.isEmpty)
    }
```

- [ ] **Step 2: Update `SettingsViewModelTests.swift`**

Remove `apiKey` from `testInitialState`:
```swift
    func testInitialState() {
        XCTAssertFalse(viewModel.isLoading)
    }
```

Remove the entire `testCanSaveApiKey` test method (lines 21-24).

- [ ] **Step 3: Build and run tests**

```bash
xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add CalorieTrackerTests/
git commit -m "test: update tests to reflect BYOK removal"
```

---

### Task 13: Web Frontend — Remove API key from onboarding

**Files:**
- Modify: `/Users/mihai/AI/calorie-tracker/frontend/src/pages/Onboarding.tsx`

- [ ] **Step 1: Remove `apikey` from `Step` type (line 13)**

```typescript
type Step = "gender" | "age" | "height" | "weight" | "activity" | "target" | "review";
```

- [ ] **Step 2: Remove `apiKey` state variable (line 29)**

Delete:
```typescript
  const [apiKey, setApiKey] = useState("");
```

- [ ] **Step 3: Remove `openai_api_key` from `handleSubmit` payload (line 65)**

Delete:
```typescript
        openai_api_key: apiKey,
```

- [ ] **Step 4: Update `steps` navigation map (lines 79-88)**

Change `review.next` from `"apikey"` to `null`, and remove the `apikey` entry:
```typescript
  const steps: Record<Step, { title: string; next: Step | null; prev: Step | null }> = {
    gender: { title: "What's your gender?", next: "age", prev: null },
    age: { title: "How old are you?", next: "height", prev: "gender" },
    height: { title: "What's your height?", next: "weight", prev: "age" },
    weight: { title: "What's your current weight?", next: "activity", prev: "height" },
    activity: { title: "What's your activity level?", next: "target", prev: "weight" },
    target: { title: "What's your target weight?", next: "review", prev: "activity" },
    review: { title: "Your daily calorie target", next: null, prev: "target" },
  };
```

- [ ] **Step 5: Remove `apikey` case from `canProceed` (line 110)**

Delete:
```typescript
      case "apikey": return apiKey.startsWith("sk-");
```

- [ ] **Step 6: Remove `apikey` JSX block (lines 206-216)**

Delete the entire block:
```tsx
          {step === "apikey" && (
            <div className="space-y-3">
              <input type="password" placeholder="sk-..." value={apiKey}
                onChange={(e) => setApiKey(e.target.value)}
                className="..." />
              <p className="text-xs text-gray-500 dark:text-gray-400">
                Your API key is encrypted and stored securely...
              </p>
            </div>
          )}
```

- [ ] **Step 7: Commit**

```bash
git add frontend/src/pages/Onboarding.tsx
git commit -m "refactor: remove API key step from web onboarding"
```

---

### Task 14: Web Frontend — Remove API key from settings

**Files:**
- Modify: `/Users/mihai/AI/calorie-tracker/frontend/src/pages/Settings.tsx`

- [ ] **Step 1: Remove API key state and handler**

Remove:
- `const [apiKey, setApiKey] = useState("");` (line 5)
- `const [saving, setSaving] = useState(false);` (line 7)
- `const [message, setMessage] = useState("");` (line 8)
- The entire `handleSaveApiKey` function (lines 21-31)

- [ ] **Step 2: Remove API key UI elements**

Remove the message banner (lines 37-39) and the entire API key card (lines 41-57).

Final file:
```tsx
import { useState, useEffect } from "react";
import { apiFetch } from "../lib/api";

export function Settings() {
  const [calorieTarget, setCalorieTarget] = useState("");

  useEffect(() => {
    async function loadProfile() {
      const res = await apiFetch("/dashboard");
      if (res.ok) {
        const data = await res.json();
        setCalorieTarget(String(data.today.daily_calorie_target));
      }
    }
    loadProfile();
  }, []);

  return (
    <div className="max-w-2xl mx-auto px-4 py-6 space-y-6">
      <h1 className="text-xl font-bold text-gray-900 dark:text-gray-100">Settings</h1>

      <div className="bg-white dark:bg-gray-900 rounded-xl p-4 shadow-sm border border-gray-100 dark:border-gray-800">
        <h2 className="font-medium text-gray-900 dark:text-gray-100">Daily Calorie Target</h2>
        <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Current target: {calorieTarget} kcal</p>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add frontend/src/pages/Settings.tsx
git commit -m "refactor: remove API key section from web settings"
```

---

### Task 15: Final verification

- [ ] **Step 1: Run backend tests**

```bash
cd /Users/mihai/AI/calorie-tracker/backend
python -m pytest app/tests/ -v
```

Expected: All tests pass, no import errors.

- [ ] **Step 2: Start backend and verify it loads**

```bash
cd /Users/mihai/AI/calorie-tracker/backend
OPENAI_API_KEY=sk-test uvicorn app.main:app --port 8000
```

Expected: Server starts without errors. Verify `/health` returns `{"status": "ok"}`.

- [ ] **Step 3: Build iOS app**

```bash
cd /Users/mihai/AI/calorie-tracker-ios
xcodebuild build -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: Build succeeds with no errors.

- [ ] **Step 4: Run iOS tests**

```bash
xcodebuild test -scheme CalorieTracker -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: All tests pass.

- [ ] **Step 5: Verify web frontend builds**

```bash
cd /Users/mihai/AI/calorie-tracker/frontend
npm run build
```

Expected: Build succeeds with no TypeScript errors.
