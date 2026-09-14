# Fast-track issues log (Phases 5-8)

Running list of bugs, gaps, and shortcuts taken while building Phases 5-8 at
speed (no per-task review gate). Everything here gets triaged and fixed in one
consolidated review pass before Phase 9 polish.

Each entry: phase, what's wrong/deferred, why, suggested fix.

---

## Post-audit wiring

1. **`AiProvider.summarizeProgress` (declared and unit-tested in Phase 7,
   `functions/src/ai/aiProvider.ts`) was dead code — no Cloud Function
   handler ever called it.** An over-engineering audit flagged this seam
   as unreachable. Fixed by adding `functions/src/coach/summarizeProgress.ts`,
   a new `summarizeProgress` callable exported from `functions/src/index.ts`,
   plus `CoachService.summarizeProgress()` and a "Summarize my progress"
   button on `CoachRecommendationsScreen` that shows the returned text in a
   dialog.
   Design call: unlike `generateRecommendation`/`generateMealPlanRecommendation`,
   this handler builds the `CoachContext`, asks the AI provider for a short
   natural-language progress summary, and returns `{ summary }` directly to
   the caller — it does **not** write to `coachRecommendations` or go
   through `validateCommand`/`handleCommand`. Reasoning: it's read-only and
   advisory, never proposes a command, and never touches protected data, so
   there is nothing to approve/reject and no audit-worthy mutation to
   record; forcing it through the recommendation/approval machinery built
   for command proposals would add a persistence layer, a status field, and
   review-flow UI with no purpose behind them. Tests:
   `functions/src/coach/summarizeProgress.test.ts` (handler unit tests
   against the fake `CoachFirestore` and a mocked `AiProvider`),
   `test/features/coach/data/coach_service_test.dart` ("summarizeProgress
   calls the summarizeProgress callable..."), and
   `test/features/coach/presentation/coach_recommendations_screen_test.dart`
   ("tapping \"Summarize my progress\"...").
   Deployment: like every other Phase 7/8 Cloud Function, this is not live
   until the user runs `firebase deploy --only functions` (or the combined
   `functions,firestore:rules` command already noted elsewhere in this
   file) — no deploy was run as part of this fix, per this project's
   established pattern for backend changes.

---

## Consolidated review fix pass (before Phase 9)

A code-review pass ran against the full `Phase 5-8` diff and found 6 real
correctness bugs (as opposed to the judgment calls/gaps already logged
below). All 6 are fixed, each with a regression test that would have caught
the original bug:

1. **`validateMealPlanChange`'s budget-ceiling check had no fallback when
   the period-matching limit was null.** A `daily` proposal only ever
   checked `budgetSettings.dailyLimit`, so a user with only `weeklyLimit`/
   `monthlyLimit` configured got zero enforcement on daily proposals. Fixed
   via a new `effectiveBudgetCeiling` helper in
   `functions/src/coach/validateCommand.ts` that derives a fallback ceiling
   from the next-broader configured limit (`weeklyLimit/7` or
   `monthlyLimit/30` for `daily`; `dailyLimit*7` or `monthlyLimit/4.33` for
   `weekly`) instead of skipping the check. Test:
   `validateCommand.test.ts`, "falls back to monthlyLimit/30 for a daily
   proposal when dailyLimit is not set".

2. **`AdherenceRepository._habitsComponent` scored historical days against
   today's full habit list**, so creating a habit today retroactively
   lowered past days' scores. Fixed by filtering to habits whose
   `createdAt` is on or before the day being scored, in
   `lib/features/adherence/data/adherence_repository.dart`. (`Habit` has no
   `archivedAt`, so archived-habit history isn't reconstructed — only the
   `createdAt` floor is enforced.) Test:
   `adherence_repository_test.dart`, "a habit created today does not
   retroactively affect the habits component score for a past day".

3. **`handleCommand.ts`'s `applyCommand` update path had no
   existence/not-found handling**, so a goal/habit/meal-plan deleted
   between recommendation generation and approval would throw past the
   audit-write, surfacing as an opaque 500 with no `coachEvents` record.
   Fixed by wrapping the `applyCommand` call in `handleCommandHandler` in a
   try/catch that writes a `coachEvents` record with a new `'failed'`
   outcome and sets the recommendation to `'rejected'` instead of letting
   the exception propagate. `fakeCoachFirestoreForTests.ts` gained an
   opt-in `strictUpdate` option so a test can mirror the real Admin SDK's
   NOT_FOUND-on-missing-doc behavior. Test: `handleCommand.test.ts`,
   "gracefully fails with a coachEvents audit record...".

4. **New habit ids in `HabitsScreen` were generated from
   `DateTime.now().microsecondsSinceEpoch`**, millisecond-resolution on
   Flutter Web, so two rapid Save taps could collide and silently overwrite
   each other via `.set()`. Fixed by adding `HabitRepository.newHabitId`
   (Firestore's own auto-ID via `collection.doc().id`, matching the
   `collection.doc()`-then-`.set()` convention used elsewhere, e.g.
   `NutritionRepository.logFood`/`WorkoutRepository`) and disabling the
   Save button while a create is in flight. Test: `habits_screen_test.dart`,
   "two rapid Save-button taps do not create two habits that collide on
   id".

5 & 6. **The Phase 8 AI meal-plan-proposal feature was unreachable from the
   app, and unreachable from the general recommendation flow too.**
   `CoachService` never called the `generateMealPlanRecommendation`
   callable (item 5), and separately `generateRecommendation.ts`'s
   `buildPrompt` only listed 4 of 5 valid `proposedCommand` types, omitting
   `mealPlanChange` (item 6). Fixed by adding
   `CoachService.generateMealPlanRecommendation()` and an "Ask coach to
   propose a plan" button on `MealPlanningScreen` that calls it and
   navigates to `/coach` to review the result, and by adding
   `mealPlanChange` to `buildPrompt`'s type list. Tests:
   `coach_service_test.dart` ("generateMealPlanRecommendation calls..."),
   `meal_planning_screen_test.dart` (new file — button wiring end to end
   against a mocked callable), and `generateRecommendation.test.ts`
   ("tells the model mealPlanChange is a valid proposedCommand type").

Four other findings from the same review pass were judged accepted
tradeoffs, not bugs, and were left as-is (see their existing entries below
for the full reasoning): the N+1 full-collection reads and sequential
awaits in `adherence_repository.dart` (Phase 5 area, performance-only); the
`GoalRepository`/`validateCommand.ts` one-active-primary-goal asymmetry
(Phase 7 item 6); and the 3x-duplicated `coachEvents` audit-record
construction in `handleCommand.ts` (style/DRY, not extracted — the new
try/catch block in fix #3 above added a 4th near-duplicate site, but
refactoring all of them was judged out of scope for this pass per the
original triage).

---

## Phase 5 — Habits + Adherence

1. **CLOSED in Phase 6.** Recovery component is always excluded (neutral), not scored.
   `AdherenceRepository.computeAndCacheDaily` hardcodes
   `AdherenceComponent.recovery` to `ComponentInput.excluded()` for every
   day, since Phase 6 (Readiness + Recovery) hasn't landed the underlying
   data yet. This means the weighted average currently only ever spans
   nutrition/training/habits with their weights renormalized — recovery's
   15% weight has no effect until Phase 6 supplies real readiness scores.
   Why: the plan explicitly allows a stub/neutral recovery component and
   asked for this coupling point to be logged rather than blocking.
   Suggested fix: once Phase 6 lands a readiness/recovery score, wire it
   into `_trainingComponent`'s sibling `_recoveryComponent` in
   `lib/features/adherence/data/adherence_repository.dart` and re-verify
   the weighted-average tests in
   `test/features/adherence/data/adherence_repository_test.dart`.

2. **No server-side enforcement that clients can't write derived
   adherence summaries directly.** `adherenceDaily/{date}` and
   `adherenceWeekly/{weekId}` are owner-writable in `firestore.rules`
   (same as every other user-owned collection), even though they're
   *derived* data computed by `AdherenceRepository` — a malicious or
   buggy client could write a fabricated summary directly instead of
   going through the calculator. Why: enforcing this properly needs a
   Cloud Function (callable, using the Admin SDK, with rules that deny
   direct client writes) and standing that up was judged too slow for
   this fast-track pass — the plan explicitly permits deferring this if
   it requires a new Function. Suggested fix: add a callable Function
   (mirroring the Strava webhook's Admin-SDK pattern already used for
   `users/{uid}/meta/stravaConnection`) that runs the same
   `AdherenceCalculator` logic server-side and writes the summary, then
   flip `adherenceDaily`/`adherenceWeekly` rules in `firestore.rules` to
   `allow read: if isOwner(uid); allow write: if false;`.

3. **Training component is binary (workout logged today = 1.0, else
   0.0), with no concept of a scheduled rest day.** A day the user
   intentionally didn't plan to train currently scores 0 for training
   unless they separately mark a habit-level exclusion (which doesn't
   affect the training component at all — habits and training are scored
   independently). Why: there's no existing "training schedule/plan"
   model in the app to compare against, and building one was out of
   scope for this phase. Suggested fix: either let a
   `ComponentInput.excluded()` be passed for training when the user marks
   a whole day as planned rest (would need a UI affordance + a place to
   store day-level exclusions, not just per-habit ones), or defer to a
   future training-plan feature that defines expected training days.

4. **Nutrition component's scoring formula (`1 - |logged - goal| /
   goal`, clamped to [0, 1]) is a fast, deterministic choice, not spec'd
   exactly.** It penalizes both under- and over-eating symmetrically
   relative to the calorie goal, which may not match how a user actually
   wants adherence scored (e.g. surplus days during a bulk should
   arguably score well, not poorly, if under a *lower* bound instead of
   near a fixed target). Suggested fix: revisit alongside nutrition goal
   types (cut/maintain/bulk) if/when adherence scoring gets a dedicated
   review pass.

5. **Adherence weights are stored at `users/{uid}/meta/adherenceWeights`,
   reusing the existing `meta` subcollection** (already used for
   `stravaConnection` and covered by the generic
   `meta/{metaDoc} != 'stravaConnection'` rule) rather than a new
   top-level collection, since it's a single per-user settings document
   and fits the existing convention. No fix needed — noting the choice
   for anyone auditing collection layout later.

---

## Phase 6 — Readiness + Recovery

1. **Item #1 above is now closed.** `AdherenceRepository._recoveryComponent`
   reads the day's `ReadinessEntry` (via `ReadinessRepository.getByDate`)
   and scores the recovery component from `ReadinessResult.score` when a
   check-in exists for that date, falling back to
   `ComponentInput.excluded()` (not a score of 0) when there's no
   check-in. `AdherenceRepository` now takes an optional
   `readinessRepository` constructor param (defaulting to a real
   `ReadinessRepository(firestore: firestore)` when not supplied, so
   existing call sites that don't pass one still work). Covered by new
   tests in `test/features/adherence/data/adherence_repository_test.dart`
   ("scores recovery from the day's readiness check-in" and "excludes
   recovery (not zero) when no readiness check-in exists").

2. **Readiness score feeding adherence does not distinguish "genuinely
   good recovery" from "a hard safety override fired."** `ReadinessResult.
   score` is the raw composite score computed *before* the hard safety
   override check, even when the override forces `level = red` (e.g. pain/
   injury with an otherwise-good composite score). This is intentional —
   the override is about the *level* (a training-intensity signal), not
   about retroactively fabricating a bad wellness score for a day that
   otherwise looks fine — but it means the adherence recovery component
   can show a decent score on a day the user reported pain/injury. Since
   adherence is a supportive, non-punitive signal (not a safety layer)
   this was judged acceptable, but flagging it in case a future reviewer
   wants recovery-component scoring to also zero out on override days.

3. **Readiness scoring weights (six equally-weighted components blended
   into one composite, with fixed 0.70/0.45 green/yellow/red thresholds)
   are a fast, deterministic choice, not spec'd exactly** — same category
   of judgment call as the Phase 5 nutrition-scoring formula (see item #4
   above). No per-user tuning of these weights/thresholds was built (unlike
   `AdherenceWeights`, which is configurable). Suggested fix: revisit
   alongside adherence scoring in the consolidated review pass if the
   fixed thresholds feel wrong in practice.

4. **No trend/history view for readiness** — only a single day's check-in
   is shown in `ReadinessCheckInScreen`; there's no charted history the
   way body composition has trends. Out of scope for this fast-track pass
   per the plan (daily check-in form + result display only); could reuse
   the existing `ProgressChart` widget in a later polish pass.

5. **`readiness/{date}` Firestore rule is a redundant explicit block**
   (already covered by the generic `/{collection}/{document=**}` owner
   rule), added purely for auditability/documentation, same pattern as the
   Phase 5 habits/adherence rule blocks. No fix needed.

---

## Phase 7 — AI Coach Infrastructure

1. **Deployment is a manual step left for the user.** This phase adds two
   new Cloud Functions (`generateRecommendation`, `handleCommand`) and
   updates `firestore.rules` (see item 2 below). Per the fast-track
   constraint, no `firebase deploy` was run — the code is written and
   tested (unit-level; no emulator was used either) but not live. The user
   needs to run `firebase deploy --only functions,firestore:rules` (or the
   equivalent) before the `/coach` screen will work against a real backend.

2. **`coachRecommendations`/`coachEvents` Firestore rules had to explicitly
   carve themselves out of the existing broad owner wildcard**, not just
   add a redundant explicit block the way Phase 5/6 additions did — the
   wildcard grants owner write on every non-`meta` collection, which would
   otherwise re-grant the client write access these two collections must
   never have. Rules now read `collection != 'meta' && collection !=
   'coachRecommendations' && collection != 'coachEvents'`. Worth
   double-checking in the consolidated review pass that no future
   phase's data accidentally lands in a collection name that shadows one
   of these two.

3. **`generateMealPlanProposal` on `AiProvider` is a stub** (routes through
   the real provider so the seam is real, not hardcoded, but there is no
   Phase-8 meal-plan data model to validate its output against yet). This
   phase does not build Phase 8 — flagging the coupling point so whoever
   builds Phase 8's meal planning knows this seam already exists in
   `functions/src/ai/aiProvider.ts` and just needs a real schema/handler
   wired up to it.

4. **`workoutChange` proposals have no structured write target.** Workouts
   has no coach-proposable schema (Phase 7's plan didn't extend it), so
   `ProposedWorkoutChange` is free-text-only (`description: string`) and
   `handleCommand`'s `applyCommand` treats it as advisory-only — approving
   one still writes a `coachEvents` audit record (outcome `applied`) but
   performs no Firestore mutation. This means "applied" doesn't uniformly
   mean "a protected document changed" for this one command type; flagging
   in case a future reviewer wants a distinct outcome value (e.g.
   `acknowledged`) for advisory-only applies.

5. **Readiness hard-safety-red interaction with `workoutChange` is a
   judgment call, not a hard reject.** `validateCommand`'s
   `validateWorkoutChange` always returns `requireApproval` for every
   workout proposal (never `allow`), and does so unconditionally whether
   or not readiness is red — the readiness-red/safety-override check is
   folded into the same `requireApproval` result with a different `reason`
   string rather than a `reject`, because a free-text proposal might
   legitimately be "take a rest day" (safe) with no structured field to
   distinguish that from "do your heaviest session" (unsafe). This is
   conservative (never auto-allows) but doesn't hard-block a user from
   approving a strenuous-sounding proposal on a red day if they choose to.
   Revisit if/when workouts gets a structured intensity field the
   validator could reason about directly.

6. **`validateCommand`'s goal-change one-active-primary-goal check rejects
   rather than auto-archives**, unlike `GoalRepository.updateGoal`/
   `createGoal` on the Flutter client, which atomically archives the other
   active primary goal in the same batch. The coach command layer
   deliberately does *not* get to make that second silent write on the
   AI's behalf — a proposal that would create two active primaries is
   rejected outright, and the user (or a follow-up recommendation) has to
   resolve the conflict explicitly. This is an intentional asymmetry
   between the client's own goal editing flow and the AI-originated
   command path, not a bug — noting it so a future reviewer doesn't "fix"
   it into matching the client behavior without re-reading this reasoning.

7. **No functions-side integration test exercises the real
   `firebase-admin` Firestore adapter (`coach/adminFirestore.ts`)** — all
   `coach/` unit tests use the in-memory `CoachFirestore` fake in
   `fakeCoachFirestoreForTests.ts`, consistent with how the rest of
   `functions/` is tested (no emulator harness exists in this repo yet).
   `adminFirestore.ts` itself is a thin, un-branching adapter (`db.doc`/
   `db.collection` pass-throughs), so the risk is low, but it is the one
   piece of Phase 7 code with zero automated coverage. Consider an
   emulator-backed smoke test in the consolidated review pass if a real
   deploy surfaces path-construction issues.

8. **Nutrition target safety floor (`MIN_SAFE_DAILY_CALORIES = 1200`) and
   the "large change" approval threshold (300 kcal) in
   `coach/validateCommand.ts` are fast, reasonable-looking constants, not
   derived from the app's own nutrition goal calculator** (`core/
   calculations/nutrition_goal_calculator.dart`) or any per-user minimum.
   Same category of judgment call as the Phase 5/6 fixed-weight scoring
   choices already logged above — revisit alongside those in the
   consolidated review pass if a per-user floor feels more correct.

9. **No chat UI, per the plan** — `/coach` is a recommendations list/detail
   screen with accept/reject plus a toggled audit-log view, not a
   conversational interface. This was explicit scope for Phase 7, not a
   shortcut.

---

## Phase 8 — Budget-Aware Meal Planning

1. **Deployment is a manual step left for the user.** This phase adds one
   new Cloud Function (`generateMealPlanRecommendation`), extends
   `handleCommand`/`validateCommand` with a `mealPlanChange` case, and adds
   four new `firestore.rules` blocks (`budgetSettings`, `priceSnapshots`,
   `mealTemplates`, `mealPlans`). Per the fast-track constraint, no
   `firebase deploy` was run. The user needs to run
   `firebase deploy --only functions,firestore:rules` before
   `generateMealPlanRecommendation` and the updated command validation are
   live against a real backend; the `/meal-planning` screen's own CRUD
   (budgets/templates/plans) works against Firestore directly and does not
   require a Functions deploy, only the rules deploy.

2. **Live price providers are explicitly out of scope, per the spec's
   "manual first, then live providers" phrasing.** `LivePriceProvider` in
   `lib/features/meal_planning/data/price_provider.dart` is an interface
   with exactly one implementation this phase,
   `UnavailableLivePriceProvider`, which always returns a
   `PriceQuoteResult`/`PriceSnapshot` with `source: unavailable` and a null
   price — never a fabricated number, per the plan's "never silently blank
   or zero" constraint, but also never an actual Blinkit/Zepto/local-store
   integration. Suggested fix: implement a real `LivePriceProvider` against
   a chosen provider's API when/if that becomes a priority; no caller needs
   to change since the interface is already the seam.

3. **Meal-plan cost aggregation is duplicated, by hand, in two languages.**
   `lib/core/calculations/meal_plan_calculator.dart` (Dart, client-side) and
   `functions/src/coach/mealPlanCost.ts` (TypeScript, server-side for
   AI-proposed plans) implement the same "sum servings × cost/calories/
   protein per template, null-propagate on any unknown cost" logic
   independently, because this repo has no cross-language shared-code
   mechanism (same category of duplication risk as `AdherenceCalculator`/
   `readinessCalculationVersion`-style version constants living per-
   platform, but here it's actual arithmetic, not just a version number).
   Both are independently unit-tested and were verified to agree on the
   worked examples in each test suite, but a future change to one (e.g. a
   different budget-ceiling fallback rule) must be mirrored in the other by
   hand. Suggested fix: if a third money-math feature is ever added,
   consider whether a small shared-logic-as-data-contract (e.g. documented
   pseudocode both sides literally copy from) or a build step that
   generates one from the other is worth the complexity; not worth it yet
   for two call sites.

4. **`mealPlans` is owner-writable, not server-only, unlike
   `coachRecommendations`/`coachEvents`.** This was a judgment call the plan
   explicitly asked for: a user can build and save a meal plan directly from
   the `/meal-planning` screen (via `MealPlanRepository.createFromTemplates`,
   which always computes totals through `MealPlanCalculator` — there is no
   path that accepts a caller-supplied total) without ever going through the
   AI coach, the same way `goals`/`habits` are both user-editable AND
   coach-command-writable. `handleCommand`'s Admin-SDK write to `mealPlans`
   for an approved `mealPlanChange` bypasses these rules regardless, so
   owner-writable here doesn't weaken the AI-proposal integrity guarantee —
   it only matters for manually-created plans, which have no AI-trust
   concern in the first place.

5. **`ProposedMealPlanChange.periodType` is only `daily`/`weekly` — no
   `monthly` plan proposal type**, even though budgets support a
   `monthlyLimit` and the calculator exposes `projectMonthlyCost`. A monthly
   plan felt like a rarer authoring unit (most reusable-meal-template
   planning is naturally daily/weekly), so monthly is presented as a
   *projection* from a daily/weekly plan's total rather than its own
   plannable period. Suggested fix: add `monthly` as a third `periodType` if
   real usage shows people want to build/approve a plan at that granularity
   directly rather than just view a projection.

6. **The mealPlanChange budget-ceiling check is a hard `reject`, not
   `requireApproval`, when a proposal exceeds the configured budget** —
   different from `nutritionTargetChange`'s "large change requires
   approval" treatment. This was a deliberate choice for the phase's
   adversarial-test requirement ("a proposal exceeding budget must not
   silently succeed") and because a budget ceiling is closer to
   `nutritionTargetChange`'s safety-floor reject than to a discretionary
   "large but plausible" judgment call — but it means a user who might
   actually want to say "yes, blow the budget just this once" cannot
   approve an over-ceiling AI proposal at all; they'd need to lower the
   servings/items themselves and ask again, or build the plan manually
   (which has no budget check at all, only the AI-proposal path does).
   Revisit if this feels too rigid in practice.

7. **No UI affordance to browse/attach individual `priceSnapshots` to a
   meal template from the meal-planning screen** — `PriceRepository`/
   `ManualPriceProvider` exist and are tested, but `MealTemplate.costPerServing`
   is entered directly as a number in the template-creation dialog rather
   than composed from priced ingredient-level snapshots (consistent with
   "no ingredient/recipe builder" being explicitly out of scope). A price
   snapshot's real intended use in this phase is as a standalone
   price-tracking record (e.g. "what did chicken cost this week"), not yet
   wired into template cost entry. Suggested fix: if ingredient-level
   pricing becomes wanted later, add a picker in the template dialog that
   pulls `PriceRepository.latestForItem` results instead of a bare cost
   text field — but that edges toward the recipe-builder scope the plan
   excluded, so revisit deliberately, not by default.

8. **`generateMealPlanRecommendation` is a separate callable/prompt from
   `generateRecommendation`, not a generic case of it**, even though
   `ai/schemas.ts`'s `ProposedCommand` union (and therefore
   `parseCoachRecommendation`) already accepts a `mealPlanChange` from
   *either* endpoint. This mirrors the fact that `AiProvider` already had a
   distinct `generateMealPlanProposal` operation from Phase 7 that nothing
   called — closing that specific seam meant giving it a real caller with
   its own budget/template-focused prompt, rather than merging meal-plan
   generation into the general recommendation flow (which has no equivalent
   focused context to hand the model). Both endpoints write to the same
   `coachRecommendations` collection and go through the identical
   `handleCommand` accept/reject path, so there is no functional gap from
   having two generation entry points — just noting the asymmetry for
   anyone expecting exactly one "generate a recommendation" call site.

9. **No functions-side integration test exercises the real
   `firebase-admin` Firestore adapter for the new `budgetSettings`/
   `mealTemplates` reads in `buildCoachContext.ts`** — same category of gap
   as Phase 7 item 7 (`adminFirestore.ts` has zero automated coverage
   anywhere in this repo; no emulator harness exists). Low risk since
   `adminFirestore.ts` remains a thin, un-branching pass-through, but
   flagging again since this phase adds two more collections it reads from.

---

## Phase 9 — Personal-Use Polish

This was the final phase: integration/UI/build polish, not new domain
logic. No per-task review gate per the plan; self-checked with
`flutter test`/`flutter analyze` throughout, plus a full-suite pass at the
end (227 tests, zero regressions; `flutter analyze` shows only the same 2
pre-existing `prefer_initializing_formals` infos in `body_composition`/
`goals` repositories that predate this phase).

1. **`AdherenceWeights` validation is "non-negative, at least one weight
   greater than zero," not "sums to a particular total."** The settings
   screen's Save button rejects negative entries per-field and rejects an
   all-zero set (which would make every day's adherence score undefined),
   but otherwise accepts any non-negative combination, since
   `AdherenceCalculator` already renormalizes weights across only the
   non-excluded components for a given day — weights need not sum to 1.0
   by design (see the existing doc comment on `AdherenceWeights` in
   `lib/core/calculations/adherence_calculator.dart`). This matches the
   calculator's existing contract rather than inventing new validation.

2. **App version is read via `PackageInfo.fromPlatform()` (`package_info_plus`),
   not a hardcoded constant**, so it always reflects `pubspec.yaml`'s
   `version:` without needing to keep a second copy in sync. If the lookup
   ever fails (unlikely — it reads bundled platform metadata, not a
   network call), the settings screen shows "unknown" instead of crashing;
   this is cosmetic-only and intentionally swallows the error in
   `lib/features/settings/presentation/settings_screen.dart`'s `_loadVersion`.

3. **The app icon and splash screen are original, programmatically
   generated art** (`scripts/generate_icon.py`, Pillow-based, one-time
   local build-tool script — not shipped as an app dependency): a dark
   `AppColors.background` canvas, a soft `accentGreen` radial glow, a
   rounded `AppColors.surface` badge, and an abstract "activity pulse"
   (EKG-style zig-zag) glyph in `accentGreen` with a small `accentBlue`
   accent dot — no third-party logo, font, or copyrighted asset involved.
   Verified (not just trusted) to have actually replaced Flutter's stock
   icons/splash by comparing MD5 hashes and file sizes of every generated
   Android mipmap/adaptive-icon file and iOS `AppIcon.appiconset`/
   `LaunchImage.imageset` file before and after running
   `flutter_launcher_icons`/`flutter_native_splash` — all changed. A
   `.venv-icon` virtualenv was created to install Pillow without touching
   system Python (per the plan's allowance) and was deleted after the
   script ran; it is not part of the repo.

4. **`firebase_crashlytics` is wired for Dart-level error forwarding only
   (`FlutterError.onError` and `PlatformDispatcher.instance.onError` in
   `lib/main.dart`), with no native Crashlytics Gradle plugin added to
   `android/build.gradle.kts`/`android/app/build.gradle.kts`.** The Flutter
   plugin's own native SDK still initializes and can record/report errors
   via the method channel without the Gradle plugin; what the Gradle
   plugin additionally provides is automatic ProGuard/R8 mapping-file
   upload for de-obfuscating stack traces in the Crashlytics console, and
   NDK-level (native crash) symbolication. Since this is a personal,
   single-developer app with no CI/App Store pipeline requiring automated
   symbol upload, and adding the Gradle plugin would touch build files
   beyond what the plan's file-structure list called for, this was judged
   out of scope for this pass. Suggested fix: if Crashlytics reports ever
   show unsymbolicated release-mode stack traces and that becomes
   annoying, add `id("com.google.firebase.crashlytics")` to
   `android/app/build.gradle.kts`'s plugins block and the corresponding
   classpath entry to the project-level Gradle file, per Firebase's
   standard setup docs.
   Both `flutter build apk --release` and
   `flutter build ios --release --no-codesign` succeed with Crashlytics
   as configured, and the whole `flutter test` suite (which exercises
   route wiring and screen behavior, though nothing directly pokes
   `main()`'s top-level function) passes, so startup is not blocked.

5. **The dashboard was given a minimal `AppBar` (title + a settings
   `IconButton`) rather than the plan's optional "section headers grouping
   Nutrition/Training vs. Habits/Readiness/Adherence vs. Goals/Coach/Meal
   Planning" reorganization.** The plan explicitly said to skip
   reorganization "if it risks breaking existing widget tests ... and just
   add the app bar entry point instead" — the existing
   `dashboard_screen_test.dart` asserts on specific card text existing in
   a flat list, and reorganizing into sections seemed like unnecessary risk
   for a phase this close to done. The existing test was extended (not
   just left alone) with a new case for the settings entry point, per the
   plan's instruction not to let it silently break.

6. **Firebase deploy and physical-device install remain manual, per the
   phase's hard constraint** — same category as the Phase 7/8 "deployment
   is a manual step" entries above, now covering the Phase 9 additions too
   (no new Cloud Functions were added in this phase, but the Phase 7/8
   Functions and rules are still undeployed). See the new "Running this on
   your own phone" section in `docs/ROADMAP.md` for the concrete
   `firebase deploy` command and Xcode signing/device steps — no
   `firebase deploy` was run and no device-install/code-signing was
   attempted, per the plan's constraints.

---

## Post-audit wiring

Follow-ups from an over-engineering audit that flagged repository methods
implemented but never called from any screen — fixed by wiring them into
the UI (not deleting), since the underlying behavior is wanted.

- **`GoalRepository.archiveGoal`** (`lib/features/goals/data/goal_repository.dart`)
  was implemented but only ever invoked internally, via
  `_archiveOtherActivePrimaryGoals` as a side effect of `updateGoal`/
  `createGoal` — there was no direct, user-initiated way to archive a
  goal. Added an explicit "Archive" action to each goal card in
  `lib/features/goals/presentation/goals_screen.dart` (matching the
  existing `IconButton` archive-action convention already used on
  `HabitsScreen`), gated behind a confirm dialog since archiving isn't
  reversible from this UI. Archived goals stay in the (unfiltered) list —
  matching the screen's existing convention of showing all statuses — but
  are dimmed and lose the archive action once archived. Covered by a new
  widget test in `test/features/goals/presentation/goals_screen_test.dart`
  asserting the confirm/cancel path and that confirming calls
  `archiveGoal` and updates the goal's status.
