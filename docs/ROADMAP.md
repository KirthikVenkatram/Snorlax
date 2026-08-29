# Snorlax Roadmap

Personal-use Flutter fitness tracker. Target: fully working on the author's own iPhone (no App Store distribution, no monetization).

## Status

- **Phase 1 — Foundation**: done. Auth, dashboard shell, onboarding, design system.
- **Phase 2 — Workouts**: done. Manual strength/general workout logging, exercise library, progress charts, Strava OAuth + webhook cardio sync. Strava live verification (OAuth flow, webhook delivery) is on hold — Strava now requires a paid developer subscription to register an API app, and the decision was made to defer that spend indefinitely rather than a technical blocker.
- **Phase 3 — Nutrition**: implemented. Food logging, daily calorie/macro goals, custom foods, multi-source food search, natural-language logging, and entry editing.
- **Phase 4 — Body Composition + Goals**: implemented. Historical measurements, deterministic body-composition estimates, trends, and hierarchical goals.
- **Phase 5 — Habits + Adherence**: planned. Habits, checklists, supportive adherence trends, and configurable component weights.
- **Phase 6 — Readiness + Recovery**: planned. Lightweight deterministic readiness inputs and non-medical training guidance.
- **Phase 7 — AI Coach**: planned. Versioned context, structured recommendations, deterministic validation, user approval, and auditable events.
- **Phase 8 — Budget-Aware Meal Planning**: planned. Budgets, manual/live price snapshots, reusable meal templates, and cost-aware plans.
- **Phase 9 — Personal-use polish**: planned. Dashboard integration, profile/settings, app icon/splash screen, release build, and Crashlytics.

## Explicitly out of scope

- Monetization (subscriptions, ads, IAP) — deferred indefinitely, not part of this roadmap.
- App Store / Google Play submission — app runs locally on the author's own device only.

## Process

Each phase gets its own design spec (`docs/superpowers/specs/`) and implementation plan (`docs/superpowers/plans/`), built via superpowers:subagent-driven-development with per-task review gates and a final whole-branch review — same process as Phases 1 and 2. Phase 2's final review caught real defects (unreachable UI, a security rules gap, a webhook duplication bug) that only surfaced because of those gates; later phases keep them.
