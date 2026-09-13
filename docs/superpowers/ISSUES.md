# Fast-track issues log (Phases 5-8)

Running list of bugs, gaps, and shortcuts taken while building Phases 5-8 at
speed (no per-task review gate). Everything here gets triaged and fixed in one
consolidated review pass before Phase 9 polish.

Each entry: phase, what's wrong/deferred, why, suggested fix.

---

## Phase 5 — Habits + Adherence

1. **Recovery component is always excluded (neutral), not scored.**
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
