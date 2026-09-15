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
- **Glass-UI design handoff (post-launch redesign)**: done. Full visual system replacement per `/Users/kirthikvenkatram/Downloads/design_handoff_glass_ui/README.md` — retinted tokens, real translucent `GlassCard` v2 (gradient surface + radial glow + hairline stroke + inner highlight, not an opaque box), `AmbientBackground` blooms, pill (`StadiumBorder`) buttons/chips, a 5-tab bottom bar (Home/Nutrition/Train/Coach/More) replacing the old push-only dashboard, motion (animated rings, tap-scale, staggered entrance), and Archivo/mono HUD typography. Plus the handoff's **new features**, reconciled against what actually exists (see `docs/superpowers/plans/2026-09-15-glass-handoff-new-features.md` — the handoff assumed a different app with no Coach/Adherence/Readiness/Goals/Meal Planning; those all stayed, nothing was removed):
  - **Recipe builder** (`users/{uid}/recipes`) and **Scan food** (barcode via `mobile_scanner` + a direct client-side Open Food Facts lookup, no Cloud Function needed) — both reachable from Log food's new Scan pill / Frequent Foods row.
  - **Active workout session**: a live-ticking timer + set-completion chips, real persistence through the existing `WorkoutRepository`, and a celebratory Session Complete screen. Reachable via "Quick start" on Workouts.
  - **Sleep**: manual check-in (`users/{uid}/sleep/{date}`) mirroring the Readiness feature's shape — no HealthKit/Health Connect sync (out of scope), but the doc shape is ready for one later.
  - **Streaks**: a real `StreakCalculator` (current/longest consecutive-day runs from actual `DailyAdherenceSummary` data, threshold 0.6 — not fabricated) plus a Streaks & Habits screen with real per-habit streaks and a 35-day grid.
  - **Trends**: weight/adherence charts and a stats list, all real computed values or omitted — never a fabricated delta.
  - **Home tab rebuilt** with real Training/Last-night tiles, a real habits-driven daily checklist (not a fake fixed list), and a real streak banner.
  All new/changed screens wired into routing and `MoreTab`. Full `flutter test` (298 tests) and `flutter analyze` pass with zero regressions. See `docs/superpowers/ISSUES.md`, "Glass handoff — new features" for judgment calls and deferred items (sleep/training-day insight line, live price-style barcode fallback wording, etc).

## Explicitly out of scope

- Monetization (subscriptions, ads, IAP) — deferred indefinitely, not part of this roadmap.
- App Store / Google Play submission — app runs locally on the author's own device only.

## Running this on your own phone (manual steps)

### 1. Backend deploy — done (2026-09-13)

`firebase deploy --only functions,firestore:rules` has been run against the `snorlax-d2f99` Firebase project (on the Blaze plan). `firestore.rules` is live, and all 8 Cloud Functions are deployed: `exchangeStravaToken`, `stravaWebhook`, `searchFood`, `parseFoodText`, `estimateNutrition`, `generateRecommendation`, `generateMealPlanRecommendation`, `handleCommand`. A container-image cleanup policy (`firebase functions:artifacts:setpolicy`, 1-day retention) is set in `us-central1` to avoid storage cost creep from build artifacts.

**Important — every external API secret is currently a placeholder.** `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`, `STRAVA_WEBHOOK_VERIFY_TOKEN`, `USDA_API_KEY`, `NUTRITIONIX_APP_ID`, `NUTRITIONIX_APP_KEY`, `GROQ_API_KEY`, and `NVIDIA_NIM_API_KEY` were all set to the literal string `placeholder-not-configured` in Secret Manager just to satisfy the deploy (Firebase validates that every secret referenced by any function has at least one version, even for functions you don't call). This means:
- `/coach` recommendations and the meal-plan-proposal path will call Groq/NVIDIA NIM and fail (both keys are placeholders) until real keys are set.
- Nutrition food search/parsing (`searchFood`, `parseFoodText`, `estimateNutrition`) will fail the same way until real USDA/Nutritionix/Groq/NIM keys are set.
- Strava sync remains intentionally paused (paid developer tier, deferred spend) — its placeholders don't need real values unless that decision changes.

To set a real key once you have one: `echo -n "<real-value>" | firebase functions:secrets:set SECRET_NAME --data-file -`, then redeploy the function(s) that use it (`firebase deploy --only functions:<name>`) so it picks up the new secret version.

Everything else in the app (workouts, habits, goals, body composition, readiness, settings, and manually-built meal plans) reads/writes Firestore directly and never touches these functions or secrets.

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
