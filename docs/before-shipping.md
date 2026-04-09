# Before Shipping to App Store

## Required

- [ ] **HTTPS** — Set up SSL on the VPS with Let's Encrypt + nginx. Remove ATS exceptions from Info.plist and update `Configuration.swift` to use `https://`.
- [ ] **Supabase Pro** — Upgrade to Pro plan ($25/month). Free tier pauses the database after 1 week of inactivity.
- [ ] **Apple Developer Account** — Enroll in Apple Developer Program ($99/year) if not already.
- [ ] **App Store assets** — App icon (1024x1024), screenshots, description, privacy policy URL.
- [ ] **Privacy policy** — Required by App Store. Must disclose: data collected (email, weight, food logs, photos sent but not stored), third-party services (Supabase, OpenAI).

## Trial / Subscription

- [ ] **StoreKit subscription + trial** — Configure a free trial as an introductory offer on an auto-renewing subscription in App Store Connect. Apple enforces one trial per Apple ID / family group — users can't bypass it by creating new app accounts.
- [ ] **Check trial eligibility in-app** — Use `Product.SubscriptionInfo.isEligibleForIntroOffer(for:)` before showing the trial CTA. If ineligible, show "Subscribe" at full price.
- [ ] **App Store Server Notifications** — Set up server-to-server notifications from Apple to the backend. On subscription events, store the `originalTransactionId` on the user row and enforce uniqueness — this prevents one paid subscription from unlocking multiple app accounts.
- [ ] **Do NOT use device fingerprinting** — Apple rejects apps that fingerprint devices to block signups (guideline 5.1.1). Rely on StoreKit eligibility instead.

## Recommended

- [ ] **Multiple uvicorn workers** — Add `--workers 2` (or more) to `deploy/calorie-tracker.service`. Less urgent now that the chat endpoint is fully async (AsyncOpenAI + streaming), but Supabase client calls are still synchronous and briefly block the event loop. 2 workers gives headroom under load. Note: the in-memory rate limiter will become per-worker — move to Redis if that matters.
- [ ] **Error monitoring** — Add Sentry or similar to backend to catch production errors.
- [ ] **Database backups** — Supabase Pro includes daily backups, but verify they're enabled.

## Nice to Have (Post-Launch)

- [ ] **Custom domain** — Point a domain at the VPS instead of bare IP. Looks more professional, easier SSL renewal.
- [ ] **Rate limiting with Redis** — Current in-memory rate limiting breaks with multiple workers. Use Redis if abuse becomes a problem.
- [ ] **App Store review notes** — Prepare a test account for Apple's review team.
