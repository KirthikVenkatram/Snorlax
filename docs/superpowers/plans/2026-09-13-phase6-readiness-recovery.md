# Phase 6: Readiness + Recovery Implementation Plan

> **For agentic workers:** Implement task-by-task with TDD (red/green). FAST-TRACK phase: do NOT stop for a formal per-task review gate. Self-check with `flutter test` and `flutter analyze` after each task, fix obvious breakage yourself, and log anything uncertain, deferred, or risky to `docs/superpowers/ISSUES.md` (append, don't overwrite) instead of blocking. Commit at the end of the phase once tests and analyzer are clean.

**Goal:** Add daily self-reported readiness inputs and a deterministic, non-medical readiness result (green/yellow/red), and close the ISSUES.md item #1 from Phase 5 by wiring a real recovery component into the adherence calculator.

**Spec:** `docs/superpowers/specs/2026-08-24-fitness-operating-system-architecture.md` (see "Readiness and Recovery").

## Global Constraints

- Preserve all Phase 1-5 collections and public constructors.
- Store at `users/{uid}/readiness/{date}`: sleep duration/consistency, soreness, fatigue, energy, pain/injury flags, recent training-load inputs, the deterministic result, and `calculationVersion`.
- Result is green (train normally), yellow (reduce volume/intensity), or red (recovery/rest; seek appropriate professional help when pain/concerning symptoms present).
- This is explicitly NOT medical advice or a medically validated assessment — label it as such in UI copy and doc comments.
- Hard safety conditions (e.g. reported pain/injury flag, very low sleep + high soreness) must force red regardless of other inputs — AI (future Phase 7) must never be able to override these; keep the calculator pure/deterministic so that guarantee is structural, not a convention.
- Implement the calculator as a pure, independently tested service in `lib/core/calculations/readiness_calculator.dart`, following the same pattern as `adherence_calculator.dart` / `body_composition_calculator.dart`.
- Close out ISSUES.md Phase 5 item #1: in `lib/features/adherence/data/adherence_repository.dart`, replace the hardcoded `ComponentInput.excluded()` recovery component with a real read from the day's readiness record (fall back to excluded if no readiness record exists for that date — don't force a score of 0 for missing data). Update `test/features/adherence/data/adherence_repository_test.dart` accordingly.

## File Structure

- `lib/features/readiness/domain/readiness_entry.dart` - inputs + result + `ReadinessLevel { green, yellow, red }` enum, JSON codec.
- `lib/core/calculations/readiness_calculator.dart` - pure function: inputs -> `ReadinessLevel` + component notes, with hard safety overrides.
- `lib/features/readiness/data/readiness_repository.dart` - owner-scoped Firestore CRUD, read-by-date.
- `lib/features/readiness/presentation/readiness_providers.dart`, `readiness_check_in_screen.dart` - daily check-in form + result display with clear non-medical disclaimer copy, follows GlassCard/PrimaryButton/AppColors conventions.
- `lib/features/adherence/data/adherence_repository.dart` - modify to consume readiness for the recovery component.
- `lib/core/router/app_router.dart`, `lib/features/dashboard/presentation/dashboard_screen.dart` - navigation wiring only.
- `firestore.rules` - readiness owner read/write rule.

## Tasks

1. **Readiness domain model** - inputs (sleep hours/consistency 0-1, soreness/fatigue/energy 0-1 or 1-5 scale — pick one and be consistent with adherence's [0,1] convention), pain/injury boolean flags, recent training-load summary, `ReadinessLevel`, `calculationVersion`. Unit tests for JSON round-trip.
2. **Readiness calculator** - pure, independently tested: normal-input scoring producing green/yellow/red; hard safety overrides (pain/injury flag -> red always; extreme sleep deprivation + high soreness -> red) tested explicitly as their own cases so the "AI can't override" guarantee is verifiable by a test.
3. **Readiness repository** - CRUD against `fake_cloud_firestore`, read-by-date for adherence's recovery lookup.
4. **Readiness check-in UI** - daily form, result display with green/yellow/red visual treatment (using AppColors semantic colors, not raw Colors.*) and an explicit "not medical advice" disclaimer line. Wire into router (`/readiness`) and dashboard card.
5. **Wire recovery into adherence** - replace the Phase 5 stub per the constraint above; update/extend adherence repository tests.
6. **Firestore rules** - add explicit `readiness` owner rule.
7. **Regression pass** - full `flutter test` + `flutter analyze` across the whole app; fix regressions; log anything non-obvious to ISSUES.md under a new "Phase 6" section.
8. **Update docs/ROADMAP.md** - mark Phase 6 done, one line matching existing style.
9. **Commit** - git add relevant files (check `git status` first, don't blindly `-A`), clear message, no push.
