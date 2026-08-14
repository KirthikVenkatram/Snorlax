# Snorlax Roadmap

Personal-use Flutter fitness tracker. Target: fully working on the author's own iPhone (no App Store distribution, no monetization).

## Status

- **Phase 1 — Foundation**: done. Auth, dashboard shell, onboarding, design system.
- **Phase 2 — Workouts**: done. Manual strength/general workout logging, exercise library, progress charts, Strava OAuth + webhook cardio sync. Strava live verification (OAuth flow, webhook delivery) is on hold — Strava now requires a paid developer subscription to register an API app, and the decision was made to defer that spend indefinitely rather than a technical blocker.
- **Phase 3 — Nutrition**: planned, not started. Manual meal/calorie logging + food database search for auto-fill macros.
- **Phase 4 — Habits**: planned, not started. Daily check-off habits with streaks, push reminders via Firebase Cloud Messaging.
- **Phase 5 — Personal-use polish**: planned, not started. App icon/splash screen, clean `flutter build ios --release`, Firebase Crashlytics.

## Explicitly out of scope

- Monetization (subscriptions, ads, IAP) — deferred indefinitely, not part of this roadmap.
- App Store / Google Play submission — app runs locally on the author's own device only.

## Process

Each phase gets its own design spec (`docs/superpowers/specs/`) and implementation plan (`docs/superpowers/plans/`), built via superpowers:subagent-driven-development with per-task review gates and a final whole-branch review — same process as Phases 1 and 2. Phase 2's final review caught real defects (unreachable UI, a security rules gap, a webhook duplication bug) that only surfaced because of those gates; later phases keep them.
