# Fast-track issues log (Phases 5-8)

Running list of bugs, gaps, and shortcuts taken while building Phases 5-8 at
speed (no per-task review gate). Everything here gets triaged and fixed in one
consolidated review pass before Phase 9 polish.

Each entry: phase, what's wrong/deferred, why, suggested fix.

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
