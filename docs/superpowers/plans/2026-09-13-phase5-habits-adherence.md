# Phase 5: Habits + Adherence Implementation Plan

> **For agentic workers:** Implement task-by-task with TDD (red/green). This is a FAST-TRACK phase: do NOT stop for a formal per-task review gate. Self-check with `flutter test` and `flutter analyze` after each task, fix obvious breakage yourself, and log anything uncertain, deferred, or risky to `docs/superpowers/ISSUES.md` (append, don't overwrite) instead of blocking. Commit at the end of the phase once tests and analyzer are clean.

**Goal:** Add user-managed habits with daily completions, and deterministic daily/weekly adherence summaries combining nutrition, training, habits, and recovery components, with supportive (never punitive) language and neutral-exclusion reasons.

**Spec:** `docs/superpowers/specs/2026-08-24-fitness-operating-system-architecture.md` (see "Habits and Adherence").

## Global Constraints

- Preserve all Phase 1-4 collections and public constructors.
- Store habits at `users/{uid}/habits/{habitId}`, completions at `users/{uid}/habitCompletions/{date}` (date-keyed doc, map of habitId -> completed/excluded/reason).
- Derived summaries at `users/{uid}/adherenceDaily/{date}` and `users/{uid}/adherenceWeekly/{weekId}`.
- Default component weights: nutrition 40%, training 25%, habits 20%, recovery 15% (recovery component can be a stub/neutral value until Phase 6 lands readiness data — note this in ISSUES.md rather than blocking). Weights are user-configurable settings, stored per-user.
- Neutral/excluded reasons (illness, injury, planned rest, travel, schedule change) must reduce neither adherence nor the day's/week's standing — excluded days are omitted from the denominator, not scored as 0.
- Adherence copy must read as descriptive/supportive, never punitive (no streak-shaming language).
- If enforcing "clients cannot write derived summaries directly" via Firestore rules + a callable Function is too slow for this pass, implement the calculator as a pure Dart service + repository that computes and caches summaries from the client, and log the security-rule gap to ISSUES.md for the final pass. Do not skip writing the rule change entirely if it's cheap — only defer if it requires a new Cloud Function.

## File Structure

- `lib/features/habits/domain/habit.dart` - `Habit` model (id, name, cadence/frequency, createdAt, archived).
- `lib/features/habits/domain/habit_completion.dart` - per-date completion map value object with excluded/reason support.
- `lib/features/habits/data/habit_repository.dart` - owner-scoped Firestore CRUD for habits + completions.
- `lib/features/habits/presentation/habit_providers.dart`, `habits_screen.dart` - list/create/complete/archive UI, follows GlassCard/PrimaryButton/AppColors conventions.
- `lib/core/calculations/adherence_calculator.dart` - pure function(s): daily and weekly adherence from component inputs + weights + exclusions.
- `lib/features/adherence/domain/adherence_summary.dart` - daily/weekly summary records with component breakdown.
- `lib/features/adherence/data/adherence_repository.dart` - persistence/read of derived summaries, weight settings.
- `lib/features/adherence/presentation/adherence_providers.dart`, `adherence_screen.dart` - trend display, supportive copy.
- `lib/core/router/app_router.dart`, `lib/features/dashboard/presentation/dashboard_screen.dart` - navigation wiring only.
- `firestore.rules` - habits/habitCompletions owner read-write; adherenceDaily/Weekly per constraint above.

## Tasks

1. **Habit domain model** - `Habit`, `HabitCompletion`, JSON codecs, unit tests for edge cases (archived habits excluded from today's list, cadence validation).
2. **Habit repository** - CRUD + `completeHabit(date, habitId, {excluded, reason})`, tested against `fake_cloud_firestore`.
3. **Habits UI** - today's habit list with complete/exclude actions, create/archive habit flow, wired into router + dashboard entry point.
4. **Adherence calculator** - pure, independently tested: component scores in [0,1], weighted sum, exclusion handling (excluded days shrink the denominator not the numerator), weekly rollup from daily records.
5. **Adherence repository + settings** - compute-and-cache daily/weekly summaries from nutrition/workout/habit repositories already in the app; configurable weights persisted per-user (default weights above); recovery component stubbed neutral (e.g. 1.0 or excluded) until Phase 6 — log this coupling point in ISSUES.md.
6. **Adherence UI** - daily/weekly trend view with component breakdown and supportive copy; wire into dashboard.
7. **Firestore rules** - add explicit habits/habitCompletions rules; add adherenceDaily/Weekly rules per the constraint note; run existing rules tests if present.
8. **Regression pass** - full `flutter test` + `flutter analyze` across the whole app (not just new files); fix regressions; log anything non-obvious to ISSUES.md.
9. **Commit** - one commit for the phase (or a few logical ones), message describing what landed and pointing to ISSUES.md entries if any were added.
