# Phase 7: AI Coach Infrastructure Implementation Plan

> **For agentic workers:** Implement task-by-task with TDD (red/green). FAST-TRACK phase: do NOT stop for a formal per-task review gate. Self-check with `flutter test`/`flutter analyze` (Dart) and the functions test runner (TypeScript) after each task; fix obvious breakage yourself. Log anything uncertain, deferred, or risky to `docs/superpowers/ISSUES.md` (append, don't overwrite) instead of blocking. Commit at the end of the phase once tests pass. **Do NOT run `firebase deploy` or otherwise deploy Cloud Functions to production — write and test the code only; note in ISSUES.md that deployment is a manual step for the user.**

**Goal:** Add advisory-only AI coaching: a provider abstraction over the existing Groq/NIM client, a deterministic versioned `CoachContext` built server-side from existing data, schema-validated structured recommendations, a command-validation layer with deterministic safety limits, and an approval-gated command handler that is the *only* way an AI-originated proposal can mutate protected data. Every AI-originated change is auditable via `coachEvents`.

**Spec:** `docs/superpowers/specs/2026-08-24-fitness-operating-system-architecture.md` (see "AI Provider and Coaching Architecture" and "Firestore Security").

## Global Constraints

- AI never writes data directly. Flow is strictly: context -> AI recommendation -> schema validation -> deterministic command validation (`allow`/`requireApproval`/`reject`) -> user approval (if required) -> command handler writes via Admin SDK -> `coachEvents` audit record.
- All AI provider credentials stay inside Cloud Functions (`functions/src/`), reusing `functions/src/llmClient.ts`'s Groq-primary/NIM-fallback pattern — wrap it in a typed `AiProvider` interface rather than replacing it.
- `coachRecommendations/{recommendationId}` and `coachEvents/{eventId}` are server-written, client-readable only. Update `firestore.rules` to explicitly deny client create/update/delete on both collections (`allow read: if isOwner(uid); allow write: if false;`), and exclude them from any broad wildcard.
- `CoachContext` must be deterministic and versioned (`contextSchemaVersion`), built from existing repositories/summaries (profile, active goals, recent body measurements/trends, nutrition and training summaries, adherence, readiness, budget constraints if available) — never raw Firestore dumps. Keep it compact; this is a context-window and privacy boundary, not just a style preference.
- Command validator must apply deterministic safety limits (e.g. don't allow a proposed nutrition target below a safe floor, don't allow a goal change that violates the one-active-primary-goal rule, don't allow overriding a readiness hard-safety red result). It must be pure/testable and independent of the AI call itself, so "no-bypass" is verifiable by tests that call the validator directly with adversarial inputs.
- Every provider operation (parse food log reuse aside — that's Phase 3, don't touch it) validates output against a runtime schema (e.g. zod, or hand-rolled type guards matching existing repo conventions — check `functions/src/parseFoodText.ts` for the existing validation style) before it's used; invalid output is rejected, never coerced into health data.
- This phase does NOT need a chat UI. A recommendations list/detail screen with accept/reject and an events/audit log view is sufficient for personal use.

## File Structure

Cloud Functions (`functions/src/`):
- `ai/aiProvider.ts` - `AiProvider` interface wrapping `llmClient.ts`; typed operations: `generateCoachRecommendation`, `summarizeProgress`, `generateMealPlanProposal` (meal plan proposal can be a stub/TODO if Phase 8 hasn't landed yet — note in ISSUES.md, don't block this phase on Phase 8).
- `ai/schemas.ts` - runtime validators for each operation's expected output shape.
- `coach/buildCoachContext.ts` - deterministic, versioned context builder reading existing collections (profile, goals, body composition, nutrition, workouts, adherence, readiness).
- `coach/generateRecommendation.ts` - callable Function: builds context, calls AI provider, validates output, writes `coachRecommendations/{id}` via Admin SDK.
- `coach/validateCommand.ts` - pure deterministic validator: typed proposed-change inputs (`ProposedNutritionTargetChange`, `ProposedWorkoutChange`, `ProposedGoalChange`, `ProposedHabitChange`) -> `{result: 'allow' | 'requireApproval' | 'reject', reason}`.
- `coach/handleCommand.ts` - callable Function: takes a recommendation id + user decision, re-validates, writes the mutation + a `coachEvents/{id}` audit record via Admin SDK. Rejects if not approved when approval was required.
- `index.ts` - export the new callables.

Flutter (`lib/features/coach/`):
- `domain/coach_recommendation.dart`, `domain/coach_event.dart` - typed models mirroring the Firestore schema, read-only from the client's perspective.
- `data/coach_service.dart` - callable-function client wrapper (mirrors how `lib/features/nutrition/` calls its callables).
- `presentation/coach_providers.dart`, `coach_recommendations_screen.dart` - list recommendations, show detail/evidence, accept/reject action (calls `handleCommand`), and a simple `coachEvents` audit log view.
- `lib/core/router/app_router.dart`, `lib/features/dashboard/presentation/dashboard_screen.dart` - navigation wiring only.

- `firestore.rules` - `coachRecommendations`/`coachEvents` explicit read-only-for-client rules per constraint above.

## Tasks

1. **AiProvider abstraction + schemas** - wrap `llmClient.ts`, define typed operations and output schemas/validators. Unit tests mock only the provider boundary (the actual Groq/NIM fetch), not the validation logic.
2. **CoachContext builder** - deterministic, versioned, tested against `fake_cloud_firestore`-equivalent (functions test setup — check existing `*.test.ts` files for the harness used, e.g. `estimateNutrition.test.ts`) with a fixed set of input fixtures producing a fixed expected context shape.
3. **generateRecommendation callable** - builds context, calls provider, validates output against schema, writes `coachRecommendations`. Test with a mocked provider returning both valid and invalid/malformed output (invalid must be rejected, never written).
4. **Command validator** - pure, independently tested with adversarial cases: proposed nutrition target below safe floor -> reject; proposed goal change that would create two active primaries -> reject; proposed change while readiness is hard-safety red (if relevant to the proposed type) -> requireApproval or reject per your judgement, logged if ambiguous; ordinary in-bounds proposals -> allow or requireApproval per spec intent.
5. **handleCommand callable** - re-validates on submit (never trusts a stale client-side validation result), writes the mutation and a `coachEvents` record only on an approved/allowed path; writes a rejected `coachEvents` record (no mutation) otherwise. Tested for the no-bypass property explicitly (submitting a decision that shouldn't be allowed must not mutate protected data).
6. **Firestore rules** - explicit deny-client-write rules for `coachRecommendations`/`coachEvents`; exclude from broad wildcard if one currently covers them.
7. **Flutter coach feature** - domain models, service wrapper, recommendations list/detail UI with accept/reject, audit log view. Wire into router (`/coach`) and dashboard.
8. **Regression pass** - run the functions test suite (check `functions/package.json` for the test command) and the full Flutter `flutter test` + `flutter analyze`; fix regressions; log anything non-obvious to ISSUES.md under a new "Phase 7" section, including the deployment note required by the constraints above.
9. **Update docs/ROADMAP.md** - mark Phase 7 done (implemented, not deployed — note that distinction in the one-liner).
10. **Commit** - git add relevant files (check `git status` first, not `-A` blindly), clear message, no push, no deploy.
