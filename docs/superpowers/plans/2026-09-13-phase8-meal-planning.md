# Phase 8: Budget-Aware Meal Planning Implementation Plan

> **For agentic workers:** Implement task-by-task with TDD (red/green). FAST-TRACK phase: do NOT stop for a formal per-task review gate. Self-check with `flutter test`/`flutter analyze` and the functions test runner after each task; fix obvious breakage yourself. Log anything uncertain, deferred, or risky to `docs/superpowers/ISSUES.md` (append, don't overwrite). Commit at the end once tests pass. **Do NOT run `firebase deploy`.**

**Goal:** Add budgets, price snapshots (manual first, live-provider-ready via an abstraction), reusable meal templates, and proposed meal plans with deterministic cost/nutrition calculations. Then close the Phase 7 ISSUES.md stub for `generateMealPlanProposal` by wiring it to real meal-planning data.

**Spec:** `docs/superpowers/specs/2026-08-24-fitness-operating-system-architecture.md` (see "Budget-aware Nutrition and Meal Planning").

## Global Constraints

- Keep `customFoods` and the existing food-log architecture untouched. Do NOT add an ingredient recipe builder.
- New collections: `users/{uid}/budgetSettings/current` (monthly/weekly/daily budgets, currency, preferred stores, substitutions), `users/{uid}/priceSnapshots/{snapshotId}` (item price, quantity/unit, source, timestamp, manual-vs-live flag), `users/{uid}/mealTemplates/{templateId}` (reusable meals/portions), `users/{uid}/mealPlans/{planId}` (proposed daily/weekly plans with calculated nutrition/cost totals).
- Prices are never hardcoded. Implement a price-provider abstraction: manual entry works now; a live-provider interface exists but only a stub/no-op or manual-fallback implementation ships this phase (no real Blinkit/Zepto integration — note this in ISSUES.md, it's explicitly out of scope for now per spec's "then live providers" phrasing).
- Unavailable live prices must render as "manual" or "estimated" with source and timestamp — never silently blank or zero.
- Meal-plan calculations are deterministic and pure: cost per meal, daily/weekly/monthly cost projection, and protein-per-currency-unit. Put this in `lib/core/calculations/meal_plan_calculator.dart`, independently tested, mirroring `adherence_calculator.dart`'s pattern.
- AI (Phase 7's `generateMealPlanProposal`) may propose a plan but must never calculate or persist cost without going through the deterministic calculator/validator — wire the Phase 7 stub to call into this phase's real templates/prices, but the actual persisted `mealPlans` document must be written by deterministic code after the proposal is accepted, following the same recommendation -> validate -> command-handler pattern Phase 7 established (a plan proposal becomes a `ProposedMealPlanChange` command type validated by `coach/validateCommand.ts`).
- Existing food-log entries may later receive optional `costSnapshot`/`mealTemplateId` fields — additive only, never rewrite existing records.

## File Structure

- `lib/features/meal_planning/domain/budget_settings.dart`, `price_snapshot.dart`, `meal_template.dart`, `meal_plan.dart` - immutable models + JSON codecs.
- `lib/core/calculations/meal_plan_calculator.dart` - pure cost/nutrition aggregation functions.
- `lib/features/meal_planning/data/budget_repository.dart`, `price_repository.dart`, `meal_template_repository.dart`, `meal_plan_repository.dart` - owner-scoped Firestore CRUD, tested with `fake_cloud_firestore`.
- `lib/features/meal_planning/data/price_provider.dart` - abstraction with a manual-entry implementation (live-provider interface present, unimplemented/stubbed).
- `lib/features/meal_planning/presentation/*` - budget settings screen, meal template builder, price entry, plan view with cost/nutrition breakdown; follows GlassCard/PrimaryButton/AppColors conventions.
- `functions/src/coach/validateCommand.ts` - extend with a `ProposedMealPlanChange` case (cost/nutrition sanity bounds, budget-ceiling check).
- `functions/src/ai/aiProvider.ts` - replace the Phase 7 `generateMealPlanProposal` stub with a real implementation reading templates/prices/budget via `coach/firestorePort.ts`, per Phase 7's existing pattern.
- `lib/core/router/app_router.dart`, `lib/features/dashboard/presentation/dashboard_screen.dart` - navigation wiring only.
- `firestore.rules` - owner read/write for budgetSettings/priceSnapshots/mealTemplates; `mealPlans` follows the coachRecommendations-style server-write pattern only if AI-proposed plans require it — otherwise owner-writable like other user data. Use your judgement and log the choice.

## Tasks

1. **Domain models** - budget settings, price snapshot, meal template, meal plan; JSON round-trip tests.
2. **Meal plan calculator** - pure, independently tested: cost per meal, daily/weekly/monthly projection, protein-per-currency-unit, budget-ceiling comparison.
3. **Repositories** - CRUD for all four new collections against `fake_cloud_firestore`.
4. **Price provider abstraction** - manual implementation now; live-provider interface stubbed (throws `UnimplementedError` or returns a clearly-flagged "unavailable" result) — tests cover the manual path and the unavailable-live-provider fallback path.
5. **UI** - budget settings, meal template builder, price entry, plan view with cost/nutrition breakdown and manual/estimated/live source labelling. Wire into router (`/meal-planning`) and dashboard.
6. **Close Phase 7's meal-plan stub** - implement `generateMealPlanProposal` in `functions/src/ai/aiProvider.ts` for real, reading templates/prices/budget; add `ProposedMealPlanChange` to `coach/validateCommand.ts` with deterministic bounds; add tests including adversarial cases (proposal exceeding budget must reject/requireApproval, not silently allow).
7. **Firestore rules** - add explicit rules for the four new collections per the constraint note above.
8. **Regression pass** - full functions test suite + `flutter test` + `flutter analyze` across the whole app; fix regressions; log anything non-obvious to ISSUES.md under a new "Phase 8" section.
9. **Update docs/ROADMAP.md** - mark Phase 8 done (implemented, not deployed if Functions changed).
10. **Commit** - git add relevant files (check `git status` first), clear message, no push, no deploy.
