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

2. **Price tracking (`PriceRepository`/`ManualPriceProvider`/
   `price_provider.dart`) and `MealTemplateRepository.update`/`.delete`/
   `MealPlanRepository.delete` were implemented and unit-tested but never
   called from the UI.** Same over-engineering-audit finding as item 1
   above, for `lib/features/meal_planning/`. Fixed by adding a "Prices"
   section directly to `MealPlanningScreen` (a `GlassCard` matching the
   existing budget/templates/plans sections) with a form that records a
   manual price snapshot via `ManualPriceProvider(manualPrice:
   ...).getPrice(...)` → `PriceRepository.record`, and a list from
   `PriceRepository.listAll`; and by adding edit/delete icon actions to the
   meal-templates list (`MealTemplateRepository.update`/`.delete`) and a
   delete action to the meal-plans list (`MealPlanRepository.delete`), each
   with a confirm dialog before delete. Price tracking stays a standalone
   "what did this cost over time" record, per Phase 8 item 7's reasoning —
   it is NOT wired into template cost entry, which is still a manually-typed
   number; composing template cost from priced ingredients would edge
   toward the out-of-scope recipe-builder. Tests: four new cases in
   `test/features/meal_planning/presentation/meal_planning_screen_test.dart`
   (record a price → shows in list; edit a template persists; delete a
   template removes it; delete a plan removes it), using a taller test
   surface (`pumpTallSurface`) since the new section pushed later sections
   past what the default test viewport builds lazily.

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

- **`ExerciseLibraryRepository.watchAll`**
  (`lib/features/workouts/data/exercise_library_repository.dart`) was
  implemented and even used internally by `search` (via `.first`), but
  nothing in the UI held a live subscription — so custom exercises added
  from another device or flow never appeared without a manual refresh.
  Added `lib/features/workouts/presentation/exercise_library_screen.dart`,
  a `StreamBuilder<List<Exercise>>` browse screen over `watchAll(uid)`
  with a client-side text filter and the same "add custom exercise when
  no exact match" affordance as the existing in-flow `ExercisePicker`
  (reused, not duplicated, by calling `addCustom` directly). Reachable
  from an "Exercise library" icon button in `WorkoutsHomeScreen`'s app
  bar, and also routed at `/workouts/exercise-library` in
  `lib/core/router/app_router.dart`. Left the in-flow picker
  (`lib/features/workouts/presentation/exercise_picker.dart`, used when
  logging a strength workout) on its one-off `search` Future as-is:
  it's a short-lived modal picker, not a place where multi-device live
  updates matter, and switching it would have been scope creep beyond
  wiring up the dead `watchAll` call. Covered by
  `test/features/workouts/presentation/exercise_library_screen_test.dart`,
  including a case that writes to the repository directly (simulating a
  write from elsewhere) and asserts the already-mounted screen picks it
  up via the stream without rebuilding.

---

## Glass handoff — new features

### Slice C — Sleep

- **Sleep/training-day insight line skipped.** The handoff's Sleep screen
  (Screen 10) shows a canned line ("You sleep 48 minutes longer on nights
  after a training day. Worth protecting.") — per the plan's reconciliation
  decision #2, this requires correlating `SleepRepository` entries against
  logged workout days, which is a real analysis worth doing properly (with
  enough historical data to be meaningful) rather than fabricating now.
  Not built. A future pass could add it once there's a natural place to
  compute it (candidate: `Trends`, which already aggregates workouts +
  another repository over a window).
- **No HealthKit/Health Connect sync**, as scoped — `SleepEntry`/
  `SleepRepository` (`lib/features/sleep/domain/sleep_entry.dart`,
  `lib/features/sleep/data/sleep_repository.dart`) are manual-entry only,
  writing to `users/{uid}/sleep/{date}`. The doc shape (bedtime, wakeTime,
  awakeMinutes, score, optional restingHeartRate/hrv/stages) is written so
  a future HealthKit/Health Connect sync could populate the same doc
  without a schema change — that sync itself is out of scope.
- **Stages card denominator.** `_StagesCard` in `sleep_screen.dart` scales
  each stage's bar width against the *largest* single stage's minutes
  (not the sum of all four), matching the handoff's visual weighting where
  each lane reads as its own proportion of the night rather than a
  stacked/cumulative bar. Documented here since it's a judgment call, not
  specified exactly in the handoff text.
- **Routing not wired.** Per the plan, `/sleep` and `/sleep/check-in`
  routes, the `MoreTab` entry, and `HomeTab`'s "Last night" tile deep-link
  are all left for the final integration step — not part of this slice.
  `SleepScreen` navigates to `SleepCheckInScreen` internally via
  `Navigator.push` (not a named route) so the check-in flow is reachable
  today without touching `app_router.dart`.

## Glass handoff — pixel rebuild

Group E (Sleep, Trends, Streaks) visual-fidelity pass.

- **Sleep stages card denominator changed.** Superseding the "Stages card
  denominator" note above: switched `_StagesCard` from scaling each lane
  against the *largest* single stage to scaling against the *sum* of all
  four stages. The screenshot (`10-sleep.png`) draws each lane as a
  full-width track (`white@12%`) with the coloured fill as that stage's
  share of the whole night, not relative to whichever stage happens to be
  biggest — sum-of-all-four is the only denominator that makes "full width
  = one full night" true. Also added the legend row
  (`AWAKE 34M · REM 1H 22M · DEEP 1H 04M · LIGHT 4H 12M`, colour-coded)
  beneath the lanes to match the screenshot, and removed the old inline
  per-lane label/minute text.
- **Streaks grid "current run" color logic — genuinely ambiguous, made a
  call.** The task description says the grid is neon = qualifying, red = "a
  miss inside the current run", faint = other miss/no-data. Taken
  literally, this is contradictory: `StreakCalculator`'s "current streak"
  is by definition an unbroken run of qualifying days, so there can never
  be a miss *inside* it. The old code had this backwards anyway — it
  painted qualifying days inside the current streak red and qualifying
  days outside it green, and painted every miss the same faint colour
  regardless of position, which doesn't match the screenshot
  (`11-streaks-habits.png`) either (its bottom-most, most-recent row shows
  red misses; older rows show only faint misses).
  Interpretation used: "the current run" = the most recent calendar week
  (the last 7 cells / bottom grid row, `newestFirstIndex < 7`), since that
  matches the screenshot's red row being the most recent one and gives a
  literal, non-contradictory reading of "the days that are still part of
  what's currently happening, where a miss is still fresh/alarming" as
  opposed to older history. Implemented in `_StreakGrid` in
  `streaks_screen.dart`: qualifying → `accentGreen` + glow (always,
  regardless of position); non-qualifying within the last 7 days →
  `AppColors.error`; non-qualifying older than that, or no data →
  `AppColors.glassFill`. If this doesn't match design intent, the fix is a
  one-line change to `_currentRunWindowDays` or the window definition in
  `_StreakGrid.build`.
- **Trends card titles changed from `headlineMedium` (28px) to a small
  uppercase kicker (`WEIGHT` / `DISCIPLINE` / `STATS`, `bodySmall`)** to
  match the kicker style every other card on this screen and on Sleep/
  Streaks uses (`STAGES`, `LAST 7 NIGHTS`, `LAST 5 WEEKS`) — the original
  28px headline read oversized next to a small delta line. No screenshot
  exists for Trends (per the plan, built from README prose only), so this
  is a consistency call against the rest of the design system rather than
  a pixel match to a reference image.
- **Streaks grid card title changed from "Last 35 days" to "LAST 5
  WEEKS"** (small kicker) to literally match the screenshot's card title
  text and styling; 35 days = 5 weeks so the meaning is unchanged.

---

## Glass handoff — pixel rebuild

### Group C — Workouts, Active session, Session complete

- **Workouts list: no fake program, no separate "Recent" section.** The
  mockup's "Push Day A / Pull Day B / Leg Day" rows are a fixed weekly
  program the real app doesn't have. Kept the row *styling* exactly (type
  chip, duration, bold name, detail line, gradient pill) but populated it
  from real `WorkoutRepository.listWorkouts` (newest first), with a
  "Quick start" row pinned above the list as the real entry point into
  `QuickStartScreen`. Folded the mockup's separate low-contrast "Recent"
  card into the single main list instead of building a second, largely
  redundant section — the main list already *is* "recent" since it's
  newest-first real history.
- **"Start" pill relabelled to "View" for logged rows.** The mockup's
  gradient pill reads "Start" because those rows are upcoming program
  entries. Real rows in `WorkoutsHomeScreen` are already-completed logs;
  tapping them opens `WorkoutDetailScreen` to view/edit, not start a
  session, so the pill on the "Quick start" row alone reads "Start" and
  every logged-workout row reads "View" — same gradient-pill visual,
  honest label per row's actual behaviour.
- **Row name/detail derivation (no fixed program to draw from):**
  strength → name "Strength session", detail = its own exercise names
  joined by " · "; cardio → name "Cardio session", detail = its own
  `distanceKm`/`paceMinPerKm` when present (else no detail line); general
  → name = the workout's own `notes` (falls back to "Workout"), no
  detail line (nothing else on a general workout to show). All type
  chips use the same green per the handoff copy ("neon@16% fill, #00E5A0
  text — Strength / Cardio / General" — one colour, different labels).
- **Session complete headline stays a workout summary, not a streak
  count.** The mockup's "Nice work, that's {n} days." references a
  training-day streak. `StreakCalculator` now exists (Slice D) but it
  operates over `DailyAdherenceSummary` history via `AdherenceRepository`
  — wiring that into `SessionCompleteScreen` would mean threading a new
  repository + async fetch into a screen the plan explicitly scoped as a
  **fidelity pass only** ("don't tear those down and rebuild"). Kept the
  existing real workout-summary headline/subtitle and only adjusted the
  visual layer (gradient wash now green→red→violet three-stop per the
  screenshot, stat tile value size bumped for weight). A future pass
  could pass `WorkoutRepository` + `AdherenceRepository` in and compute a
  real streak for the headline if that's wanted.
- **Active session header** got the sticky blurred gradient scrim (blur
  22, `#080910` 92%→55%, hairline bottom border) the handoff calls for —
  everything else in that screen (timer size/colour/glow, set-chip
  states, progress bar) already matched and was left as-is.

### Group A — Sign in, Onboarding, Profile

- **Sign-in**: left as-is. Already matched the screenshot (88px mark,
  44px "Snorlax", two-line tagline, bottom-anchored pills) from a prior
  pass; no drift found worth a diff.
- **Onboarding "Name" field isn't persisted.** The screenshot's step 1
  shows a Name field, but `UserProfile`/`UserProfileRepository` (and thus
  the existing `saveProfile` contract this rebuild had to preserve
  exactly) has no `name` field — only `AppUser.displayName` (from the
  Google/Apple sign-in provider) carries a name anywhere in this app.
  Kept the field in the UI for visual fidelity but it's write-only/
  cosmetic — not wired to any save call, not prefilled. Adding real name
  storage would mean changing the `UserProfile` schema, which is out of
  scope for a "preserve existing save behavior exactly" rebuild. Flagging
  in case product wants a real editable display name later (natural
  home: `UserProfile` + a Firestore field, surfaced on Profile too).
- **Onboarding step 3 goal pills show a `-500kcal`/`+500kcal` sub-label,
  Profile's goal pill doesn't.** Both reuse the new `SegmentedPill`
  widget (`lib/core/widgets/segmented_pill.dart`), but only Onboarding
  passes `subLabelBuilder`. There's no screenshot for onboarding step 3
  (`02-onboarding.png` only shows step 1), so that one follows the plan
  prose verbatim ("Lose fat -500kcal / Maintain / Build +500kcal").
  Profile *does* have a screenshot (`12-profile.png`/`13-screen.png`)
  and it shows a plain single-line "Lose fat | Maintain | Build" with no
  kcal delta — matched that literally instead of carrying the sub-label
  over, per "screenshot is primary spec, prose secondary."
- **Profile's "Reminders / Units / Connected / Export data" rows are
  static/display-only**, per the plan's explicit allowance ("these can
  be static/display-only rows if there's no real feature behind them
  yet") — none of those exist as real features in this app yet, so no
  fake state or values are shown, just a chevron row.
- **Adherence-weight editing lives inside a collapsed "Adherence
  weights" row in Profile's settings list**, reusing the exact
  validation/save logic from `SettingsScreen` (`lib/features/settings/
  presentation/settings_screen.dart`) rather than a second copy — same
  non-negative-and-sum>0 validation, same `AdherenceRepository.
  setWeights` call. `/settings` itself is untouched and still routes to
  the old screen for anything still linking to it.
- **New shared widgets added** (not a parallel styling system — reused
  by both Onboarding and Profile): `lib/core/widgets/glass_text_field.dart`
  (labeled rounded glass input — no equivalent existed before this pass)
  and `lib/core/widgets/segmented_pill.dart` (the Sex/Goal toggle pill).
- **`ProfileScreen.displayName`** is a new optional constructor param
  (sourced from `firebaseAuthProvider`'s `currentUser.displayName` in
  `app_router.dart`) — not present on `SettingsScreen`, added because the
  screenshot's name header needs a real name and `UserProfile` has none
  (see the Name-field note above). Falls back to "Signed in" when null,
  same as `SettingsScreen`'s email fallback pattern.

### Group D — Log food, Scan food, Recipe builder

- **Log food's "already added in a prior pass" search field/Scan pill
  didn't actually exist.** The plan's task description says the Search
  tab's search field + Scan pill "already added in a prior pass — verify
  placement matches" — in the code found, there was no top-level search
  field at all; `FoodPicker` owned its own internal search field
  (`Key('foodSearchField')`) with no Scan pill, and the Scan pill sat in a
  separate Row next to a plain `MealType` `DropdownButton`. Since
  `FoodPicker`'s search field is exercised directly by
  `food_picker_test.dart` and must stay self-contained (one field, no
  duplicate `Key('foodSearchField')`), the fix was to add an optional
  `onScanTap` param to `FoodPicker` so it renders the Scan pill beside its
  own field, plus an `expandResults: false` mode so the results shrink-wrap
  to content instead of filling all remaining space — letting the TODAY
  summary card and Frequent Foods sit directly below the search field in
  the same scroll view when idle, matching `07-log-food.png`'s order
  exactly, with search results dropping in above them only while a query
  is active.
- **Meal-type selector kept, restyled as a 4-way glass pill row
  (`_MealTypeRow`), not dropped.** `07-log-food.png`'s crop doesn't show a
  meal picker at all (it likely lives one Figma step later, off-crop), but
  logging a food with no meal is meaningless in this app's data model — so
  it was kept and restyled to the glass system instead of removed, placed
  under Frequent Foods on the Search tab and reused as-is on the
  Describe/Photo tabs (replacing their old plain `DropdownButton`).
- **TODAY card's coaching line only renders once `NutritionGoals` exist**
  (`NutritionRepository.getGoals`); with no saved goals the card still
  shows today's real logged items and totals, just without the closing
  "N kcal / Ng protein still to go" line — never a fabricated target.
- **Removing an item from the TODAY card does not call `widget.onSaved`.**
  `onSaved` is the "a food was logged, pop and refresh the caller" signal
  (see `NutritionHomeScreen._openLogFood`); firing it on a same-screen
  removal would incorrectly pop `LogFoodScreen`. Removal instead only
  refreshes this screen's own local `_entriesFuture`/`_catalogFuture`, via
  a new `_refreshToday()` also now called after every successful log path
  (catalog tap, search-and-save, describe/photo save-all, including the
  partial-failure branch that deliberately doesn't call `onSaved`) so the
  TODAY card reflects reality whenever the screen stays open.
- **Recipe builder's ingredient checklist changed from a `Wrap` of chips to
  a `Column` of full-width rows** (`_IngredientRow`, replacing
  `_IngredientChip`), matching `09-recipe-builder.png`'s actual per-row
  card layout (name + "100 g · kcal" detail line + trailing circular +/−)
  rather than the old inline-chip layout, which didn't match the
  screenshot's structure at all. Each row shows "Looking up…"/"100g
  serving" placeholders (never a fabricated kcal number) until its
  estimate resolves. Header also changed from an `AppBar` ("Build a
  recipe") to the screenshot's "Recipe" title + "Cancel" pill, and the
  ingredients label changed from "Ingredients · N added" to the
  screenshot's "INGREDIENTS · N ADDED" mono kicker — updated
  `recipe_builder_screen_test.dart`'s matching text assertion to match
  (test still passes, same behavioural assertions otherwise).
- **Scan food's viewfinder rebuilt as a `CustomPainter`** (dashed
  rounded-rect outline + four glowing neon corner brackets,
  `_ViewfinderPainter`) instead of a solid 3px full-border box — the
  screenshot (`08-scan-food.png`) clearly shows a corner-bracket frame,
  and its own notes column calls out "the ring a `CustomPainter`"
  explicitly. Header buttons also changed to match: top-left is a
  text-only "Close" pill (was icon+label), top-right is a round icon-only
  torch toggle (was icon+"Torch" label).
- **No smoke test added for `scan_food_screen.dart`.** It has no existing
  test file and none of `mobile_scanner`'s `MobileScanner`/
  `MobileScannerController` widgets are exercised anywhere else in this
  repo's test suite (camera platform channels aren't available in a plain
  widget test) — adding one here risked being the first attempt at that
  and destabilizing an otherwise-working fidelity pass. `flutter analyze`
  is clean on the file and it was read/reviewed manually against the
  screenshot; a future pass could add a fake `MobileScannerController`
  harness if scan-flow regressions become a real risk.

## Glass handoff — Group G (Coach/Goals)

- **Coach status colours**: `pending` uses `AppColors.warningYellow`, `accepted` uses `accentGreen`, `rejected` uses `error` — the handoff mockup (`15-coach.png`) only shows a plain grey "Status: pending"/"Status: accepted" text line with no colour coding, but the rest of the app's glass cards consistently colour-code status via the card glow + status text, so this extends that established pattern rather than copying the mockup's flatter placeholder text verbatim.
- **Coach header toggle wording**: mockup shows a static "Audit log" pill; made it a real toggle whose label flips to "Recommendations" when the audit view is active, since a static label would leave no way back to the recommendations list.
- **"Summarize my progress"** isn't in the coach mockup at all (out of scope screen), but it's real existing functionality (`CoachService.summarizeProgress`) with an existing test — kept it as a secondary glass pill below the primary CTA rather than dropping the feature.
- **Goals category pills**: handoff mockup (`16-goals.png`) shows placeholder pill labels "Physique / Strength / Endurance / Habit", but `FitnessGoal.category` is actually `GoalCategory { primary, physique, performance, lifestyle }`. Used the real enum values (capitalized: Primary/Physique/Performance/Lifestyle) via `SegmentedPill<GoalCategory>` instead of inventing categories that don't exist in the domain model, per the task's explicit instruction not to guess values.
- **Goals list item target display**: mockup shows "100 kg" inline after the category/status line; only rendered when `goal.targetValue` is non-null (many existing goals have no target), formatted via `toStringAsFixed(0)` for whole numbers and `.1` otherwise — no fabricated numbers, all from `FitnessGoal.targetValue`/`unit`.
- **Kept priority field and target-date picker** in the goal form even though neither appears in the mockup — both are real existing save fields (`priority`, `targetDate`) and the task said restyle, not reinvent the form.
- Updated `goals_screen_test.dart` for the `SegmentedPill` replacing the old `DropdownButtonFormField` (tap pill text directly instead of opening a dropdown menu) and disambiguated a text assertion that became ambiguous once the pill option label and the list-item caption both contain "Performance". Added new tests: coach accept flow + audit-log toggle round-trip, goals target-value/unit display.

## Glass handoff — Group F (Adherence/Readiness)

- **Adherence weekly card has no component breakdown.** `13-adherence.png` reads as if "This week" repeats the exact "Today" layout (hero number + four component rows), but `WeeklyAdherenceSummary` only stores `dailyScores` (7 day-level numbers), not a per-component weekly rollup — there is no real per-component weekly score to show. Rendered the weekly card with just the kicker/number/supportive-line, no component rows, rather than fabricating percentages or reusing today's component numbers under a "week" label.
- **Readiness red uses `AppColors.accentBlue`** per the task's explicit instruction ("red = accentBlue which is the repo's red-orange"), replacing the previous `AppColors.error`; yellow switched from `accentAmber` to the newly-added `AppColors.warningYellow` (`0xFFF5C242`) to match the handoff token. Both are visual-only swaps — `ReadinessCalculator`'s level logic (including the pain/injury hard override to red) is untouched.
- **Sliders reshaped into labelled `−`/`+` steppers** (`_StepperRow`) matching `14-readiness.png` exactly, per the handoff's own instruction that this is "a mobile-friendly stand-in for a `Slider`". Same state variables, same `setState`/clamp logic as the original `Slider.onChanged` rows — only the input widget changed. Step sizes: 0.5h for sleep hours (range 0–12), 10% for the five `[0, 1]` fraction inputs (consistency/soreness/fatigue/energy/training load).
- **Pain/injury toggle kept as a native `Switch`** (restyled: `accentBlue` active thumb) rather than invented as a new pill-toggle widget — no existing `Pressable`-based toggle component in `core/widgets/` fit better, and `Switch` is the platform-native input for a boolean per the ladder (native feature before custom).
- **Both screens kept a plain `AppBar` header** (title + transparent background) rather than a custom in-body 28px title, matching `sleep_screen.dart`'s established convention for pushed (non-tab-bar) screens rather than inventing a new header pattern for these two.
- Rewrote `adherence_screen_test.dart`'s two top-level text assertions for the new uppercase kickers ("TODAY"/"THIS WEEK" replacing "Today"/"This week") and added assertions for the four component row labels and the new `weeklySupportiveSummary` key. Added `readiness_check_in_screen_test.dart` (new file, no prior test existed): renders the form with no entry, a stepper-tap + save round trip that shows the result card with the disclaimer verbatim, and the pain/injury override forcing "Red — recovery / rest".

## Glass handoff — Group H (Body composition/Meal planning/Trends)

- **Body composition "New check-in" card trimmed to 4 fields** (weight, waist, neck, hip) matching `17-body-composition.png`'s 2x2 grid, dropping the chest/thigh/upper-arm/forearm optional fields the old screen exposed. `BodyCompositionCalculator.estimate` only ever consumes weight/waist/neck/hip (verified by reading `body_composition_calculator.dart`) — the dropped fields fed no calculation, they just wrote extra `BodyMeasurement` docs with metrics nothing else in the app reads. `BodyMetric` enum and `BodyCompositionRepository` are untouched, so nothing stops a future screen from writing those metrics again if a use for them shows up.
- **Body composition history rendered as charts, not the mockup's plain text rows.** The screenshot (`17-body-composition.png`) shows "Weight history" as literal `Aug 24  95.4 kg` list rows (cropped before any chart in the mockup's frame), but the written task spec explicitly says "using the existing chart widgets" and "the SAME log Trends' weight chart already reads" — both history cards use `ProgressChart` (weight in kg, body-fat % from `BodyCompositionEstimate.bodyFatPercent`) rather than duplicating a new list-row layout, consistent with how Trends already visualizes the same weight log.
- **Meal planning "Ask coach to propose a plan" button relabeled to "Ask coach"** to match `18-meal-planning.png`'s literal pill copy, paired with a new glass "Build a plan" pill (was a full-width gradient `PrimaryButton` for both actions) — the mockup shows the two side by side, one glass, one gradient. Updated `meal_planning_screen_test.dart`'s text-based finder from `'Ask coach to propose a plan'` to `'Ask coach'` (behavioural assertions — `generateMealPlanRecommendation` call + `/coach` navigation — unchanged).
- **Meal planning budget card condensed to "Daily N · Weekly N {currency}"** per the mockup's single summary line, dropping the standalone "Currency: …" line and the monthly-limit line from the visible card (the field/value are untouched in `BudgetSettings`/`BudgetRepository` — this is a display-only condensation, monthly limit is just not shown on this card, same as the mockup).
- **Removed now-dead `_sourceLabel`/`_dateLabel` helpers** in `_PricesCard` after restyling its rows to show only item name + `price / unit` (matching the mockup's two-column price rows) — the price source ("manual"/"live") and recorded date are still persisted on `PriceSnapshot`, just no longer shown inline on this card.
- **Trends discipline bars can't reuse `WeeklyBarChart`** (the shared `core/widgets/` chart used for the weight/nutrition bar charts elsewhere) because that widget renders every bar in one fixed color, and the mockup spec calls for three color bands (older `white@14%`, recent 3 weeks violet, this week neon). Added a small local `_DisciplineBars` widget inside `trends_screen.dart` instead of editing the shared widget — real data still comes from the same `DayValue` list already computed from `AdherenceRepository.listRecentWeekly`.
- **Trends "Sleep / night" stays a stub ("—")**, unchanged from the prior pass. `SleepRepository` exists now (it didn't when Trends was first typography-passed), but `listRecent(uid, days)` only returns the N most-recent check-ins by count, not a date-ranged query, and wiring a new `SleepRepository` constructor parameter into `TrendsScreen` means also editing `lib/core/router/app_router.dart` where it's constructed — explicitly out of scope for this pass (risk of colliding with a parallel agent). A future pass can wire it once touching the router is safe.
- **Trends stat-row deltas (Calories/Protein/Sessions) now always render in neon green**, replacing the previous sign-dependent green/red color — the weight card still keeps its sign-aware color (a bulk wants +ve, a cut wants -ve, so weight has no universal "good" direction and is called out with its own comment), but the handoff spec for the stats list just says "deltas in neon" with no sign logic, so the stat rows now match that literally.
- No behavioral/calculation changes in any of the three screens — every number rendered still comes from the same repository calls and calculators as before; only presentation/layout changed. Existing tests (`body_composition_screen_test.dart`, `trends_screen_test.dart`, `meal_planning_screen_test.dart` aside from the one button-label fix above) pass unmodified.
