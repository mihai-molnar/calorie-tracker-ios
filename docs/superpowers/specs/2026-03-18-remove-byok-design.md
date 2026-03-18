# Remove BYOK — Use Server-Side OpenAI API Key

**Date:** 2026-03-18
**Scope:** Backend (FastAPI), iOS app (SwiftUI), Web frontend (React)

## Motivation

The current BYOK (Bring Your Own API Key) model requires users to obtain and configure their own OpenAI API key. This creates significant onboarding friction — users must create an OpenAI account, set up billing, generate a key, and paste it in. Switching to a server-managed API key removes this friction, enabling a simpler subscription-based business model where the developer absorbs API costs.

## Approach

Single `OPENAI_API_KEY` environment variable on the backend, used for all users. Full removal of per-user API key infrastructure — no fallback, no optional override.

## Backend Changes

Repository: `/Users/mihai/AI/calorie-tracker`

### Config (`backend/app/config.py`)

- Add `openai_api_key: str` field to `Settings` (reads `OPENAI_API_KEY` from `.env`)
- Remove `encryption_key: str` field

### Chat endpoint (`backend/app/routers/chat.py`)

- Replace per-user key lookup (`supabase.table("user_api_keys")...`) and `decrypt_api_key()` call with `settings.openai_api_key`
- Use `OpenAI(api_key=settings.openai_api_key)` directly
- Keep existing 30 messages/minute rate limit unchanged

### Onboarding endpoint (`backend/app/routers/onboarding.py`)

- Remove `openai_api_key: str` field from `OnboardingRequest` model
- Remove the `user_api_keys` upsert logic (encrypt + insert)

### Settings endpoint (`backend/app/routers/settings.py`)

- Remove the `PATCH /api-key` endpoint entirely
- Remove `UpdateApiKeyRequest` model
- If no other endpoints remain in the settings router, remove the router and its registration in `main.py`

### Crypto service (`backend/app/services/crypto.py`)

- Delete the file entirely

### Tests (`backend/app/tests/test_crypto.py`)

- Delete the file (imports from `crypto.py`, will fail without it)

### Dependencies (`backend/requirements.txt`)

- Remove `cryptography==44.0.0`

### Database migration

- New migration file: `DROP TABLE public.user_api_keys;`

### Environment

- Add `OPENAI_API_KEY=sk-...` to `.env`
- Remove `ENCRYPTION_KEY` from `.env`
- Update `.env.example`: replace `ENCRYPTION_KEY=your-fernet-key-base64` with `OPENAI_API_KEY=sk-your-key-here`

## iOS App Changes

Repository: `/Users/mihai/AI/calorie-tracker-ios`

### Onboarding

- Delete `CalorieTracker/Views/Onboarding/APIKeyStepView.swift`
- Update `OnboardingContainerView.swift`: remove `case 7: APIKeyStepView(...)` from the step switch
- Update `OnboardingViewModel`:
  - Remove `apiKey` property
  - Update `totalSteps` from 8 to 7
  - Remove `case 7` from `canAdvance` validation switch
  - Update `buildRequest()` to stop passing `openaiApiKey`
- Remove `openaiApiKey` field from `OnboardingRequest` in `CalorieTracker/Models/Profile.swift`

### Settings

- Remove "OpenAI API Key" section from `CalorieTracker/Views/Settings/SettingsView.swift` (SecureField, update button, success/error state)
- Remove `apiKey`, `apiKeySaved`, `apiKeyError`, `saveApiKey()`, `canSaveApiKey` from `CalorieTracker/ViewModels/SettingsViewModel.swift`

### Tests

- Update `CalorieTrackerTests/ViewModels/OnboardingViewModelTests.swift`: fix `totalSteps` assertion (8 → 7), remove `apiKey` and `openaiApiKey` references
- Update `CalorieTrackerTests/ViewModels/SettingsViewModelTests.swift`: remove `apiKey` and `canSaveApiKey` test cases

### No other iOS changes

Chat, dashboard, and auth flows are unaffected — they never sent the API key in requests.

## Web Frontend Changes

Repository: `/Users/mihai/AI/calorie-tracker` (frontend directory)

### Onboarding (`frontend/src/pages/Onboarding.tsx`)

- Remove the API key step: `Step` type union entry, `steps` navigation map entry, `apikey` case in `canProceed`, `apiKey` state variable, and the `{step === "apikey" && ...}` JSX block
- Remove `openai_api_key` from the onboarding form submission payload

### Settings (`frontend/src/pages/Settings.tsx`)

- Remove the API key update section (form, state, API call to `PATCH /settings/api-key`)

## Deployment

Simultaneous deploy across all three codebases (single developer, sole user). No backwards compatibility shim needed.

Order:
1. Set `OPENAI_API_KEY` environment variable on server
2. Deploy backend (run migration, deploy code)
3. Deploy web frontend
4. Release iOS app update

## What's Preserved

- All user data (profiles, food entries, daily logs, chat history)
- Authentication flow (unchanged)
- Chat functionality (unchanged, just uses server key instead of per-user key)
- Rate limiting (30 messages/minute per user)

## What's Removed

| Asset | Location |
|-------|----------|
| `crypto.py` | Backend — delete file |
| `cryptography` dependency | Backend — remove from requirements.txt |
| `encryption_key` config | Backend — remove from Settings, .env |
| `user_api_keys` table | Database — drop via migration |
| `PATCH /settings/api-key` endpoint | Backend — remove |
| `openai_api_key` in onboarding request | Backend, iOS, web — remove from models |
| `APIKeyStepView.swift` | iOS — delete file |
| API key section in settings UI | iOS + web — remove |
| `ENCRYPTION_KEY` env var | Server — remove |
| `test_crypto.py` | Backend — delete file |
| API key references in iOS tests | iOS — update test files |
