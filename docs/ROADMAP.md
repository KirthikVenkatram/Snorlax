# Snorlax Roadmap

Personal-use Flutter fitness tracker. Target: fully working on the author's own iPhone (no App Store distribution, no monetization).

## Status

- **Phase 1 — Foundation**: done. Auth, dashboard shell, onboarding, design system.
- **Phase 2 — Workouts**: done. Manual strength/general workout logging, exercise library, progress charts, Strava OAuth + webhook cardio sync. Strava live verification (OAuth flow, webhook delivery) is on hold — Strava now requires a paid developer subscription to register an API app, and the decision was made to defer that spend indefinitely rather than a technical blocker.
- **Phase 3 — Nutrition**: implemented. Food logging, daily calorie/macro goals, custom foods, multi-source food search, natural-language logging, and entry editing.
- **Phase 4 — Body Composition + Goals**: implemented. Historical measurements, deterministic body-composition estimates, trends, and hierarchical goals.
- **Phase 5 — Habits + Adherence**: implemented. User-managed habits with daily completions and neutral exclusions, deterministic daily/weekly adherence summaries across nutrition/training/habits/recovery with configurable weights, and supportive (non-punitive) copy.
- **Phase 6 — Readiness + Recovery**: implemented. Daily self-reported readiness check-ins, a deterministic non-medical green/yellow/red result with hard safety overrides (pain/injury, extreme sleep deprivation + high soreness), and the readiness score now wired into the adherence recovery component.
- **Phase 7 — AI Coach**: implemented, not deployed. Versioned `CoachContext`, an `AiProvider` seam over the existing Groq/NIM client, schema-validated structured recommendations, a pure/independently-tested `validateCommand` safety layer, an approval-gated `handleCommand` that re-validates from scratch before any write, and auditable `coachEvents`. "Not deployed" because the new Cloud Functions (`generateRecommendation`, `handleCommand`) and updated `firestore.rules` need a manual `firebase deploy` the user must run — no deploy was executed as part of this work.
- **Phase 8 — Budget-Aware Meal Planning**: implemented, not deployed. Budget settings, price snapshots (manual working now; a live-provider interface exists but is intentionally a stubbed "unavailable" implementation, no real Blinkit/Zepto integration), reusable meal templates, and cost/nutrition-aware meal plans, all behind a pure/independently-tested `MealPlanCalculator` (cost per meal, daily/weekly/monthly projection, protein-per-currency-unit). Closes the Phase 7 `generateMealPlanProposal` stub: a new `generateMealPlanRecommendation` Cloud Function builds a real budget/template-grounded prompt, and a `ProposedMealPlanChange` command type is validated by `coach/validateCommand.ts` (budget-ceiling check, unknown-template rejection, sanity bounds on servings/item count) and applied only through the existing `handleCommand` approve/reject flow — the AI never calculates or persists cost directly. "Not deployed" for the same reason as Phase 7: the new/changed Cloud Functions (`generateMealPlanRecommendation`, extended `handleCommand`/`validateCommand`) and updated `firestore.rules` need a manual `firebase deploy` the user must run — no deploy was executed as part of this work.
- **Consolidated review fix pass (Phases 5-8)**: done. Phases 5-8 were
  fast-tracked without per-task review gates; a full-diff code review
  afterward found 6 real correctness bugs (budget-ceiling fallback gap in
  `validateMealPlanChange`, historical adherence scoring using today's
  habit list, no not-found handling in `handleCommand`'s apply path,
  collision-prone habit id generation, and the AI meal-plan-proposal
  feature being unreachable from both the app and the general
  recommendation prompt). All 6 are fixed with regression tests; see
  `docs/superpowers/ISSUES.md`, "Consolidated review fix pass" for details.
  Full `flutter test`/`flutter analyze` and functions `jest`/`tsc --noEmit`
  suites pass with zero regressions. Phases 5-8 are ready for Phase 9.
- **Phase 9 — Personal-use polish**: done. A `/settings` screen (adherence-weight view/edit UI wired to the real `AdherenceRepository`, profile email + sign-out wired to `AuthRepository.signOut`, app version via `package_info_plus`, and a consolidated non-medical-advice disclaimer), a settings entry point on the dashboard app bar, an original on-theme app icon and matching splash screen (generated programmatically, verified to differ from Flutter's stock defaults by file hash/size on both Android and iOS), and `firebase_crashlytics` wired into `main.dart` (guarded so a Crashlytics init failure can never block app startup). `flutter build apk --release` and `flutter build ios --release --no-codesign` both succeed; full `flutter test` (227 tests) and `flutter analyze` pass with zero regressions across all 8 prior phases. See `docs/superpowers/ISSUES.md`, "Phase 9" for judgment calls and deferred items.

## Explicitly out of scope

- Monetization (subscriptions, ads, IAP) — deferred indefinitely, not part of this roadmap.
- App Store / Google Play submission — app runs locally on the author's own device only.

## Running this on your own phone (manual steps)

Everything through Phase 9 is implemented and compiles cleanly in release mode, but two things were deliberately left as manual steps for the author, since they require credentials/hardware this environment doesn't have access to: deploying the backend, and code-signing an install onto a physical iPhone.

### 1. Deploy the Phases 7-8 backend

The AI coach (`/coach`) and its meal-plan-proposal path only work against a live backend. From the repo root, with the Firebase CLI authenticated to the right project:

```
firebase deploy --only functions,firestore:rules
```

This deploys the `generateRecommendation`, `handleCommand`, and `generateMealPlanRecommendation` Cloud Functions, plus the `firestore.rules` changes from Phases 5-8 (adherence weights, coach recommendations/events, budget/meal-planning collections). Everything else in the app (nutrition, workouts, habits, goals, body composition, readiness, settings) reads/writes Firestore directly and does not require a Functions deploy — only `/coach` and the "ask coach to propose a plan" button on `/meal-planning` need it.

### 2. Build and install onto your iPhone via Xcode

1. Open the iOS project in Xcode, **not** the plain `.xcodeproj`:
   ```
   open ios/Runner.xcworkspace
   ```
2. In the Xcode project navigator, select the **Runner** target, then the **Signing & Capabilities** tab.
3. Under **Team**, pick your personal Apple ID team (add one first via Xcode → Settings → Accounts if you haven't signed in with your Apple ID before). Leave **Automatically manage signing** checked — Xcode will provision a free personal development certificate for you.
4. Plug your iPhone into your Mac via USB (or pair it wirelessly: Window → Devices and Simulators → check "Connect via network" once paired by cable the first time).
5. On the iPhone, if this is its first time being used for development, go to **Settings → Privacy & Security → Developer Mode** and enable it (requires a restart).
6. In Xcode's device/scheme selector (top toolbar), choose your physical iPhone as the run destination, and set the build scheme to **Release** (Product → Scheme → Edit Scheme → Run → Build Configuration → Release).
7. Press Run (▶). Xcode will build, sign, and install the app on your phone. The first launch will be blocked by iOS until you trust the developer certificate: on the phone, go to **Settings → General → VPN & Device Management**, tap your Apple ID under "Developer App", and tap **Trust**.
8. Alternatively, once your device is paired and trusted, you can skip Xcode entirely for subsequent installs and use:
   ```
   flutter run --release -d <device-id>
   ```
   (find `<device-id>` via `flutter devices`).

Free personal-team signing certificates expire after 7 days, so you'll need to re-run step 6/7 (or `flutter run --release`) weekly to keep the app installed and working, unless you enroll in the paid Apple Developer Program for a year-long certificate.

## Process

Each phase gets its own design spec (`docs/superpowers/specs/`) and implementation plan (`docs/superpowers/plans/`), built via superpowers:subagent-driven-development with per-task review gates and a final whole-branch review — same process as Phases 1 and 2. Phase 2's final review caught real defects (unreachable UI, a security rules gap, a webhook duplication bug) that only surfaced because of those gates; later phases keep them.
