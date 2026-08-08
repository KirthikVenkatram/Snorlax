# Phase 2: Workouts — Design

Date: 2026-08-08

## Overview

Adds workout tracking to the fitness tracker: manual strength and general workout logging, a
curated + user-extensible exercise library, per-exercise progress charts, and automatic cardio
logging via a Strava integration (OAuth connect + webhook-driven sync — no manual GPS tracking
built in this app). Builds directly on Phase 1's Firebase/auth/design-system foundation.

Two features that came up during scoping were explicitly deferred to their own future phases,
not included here:
- An AI coach that personalizes plans from profile/body data — deferred until there's workout
  history for it to use.
- Nothing else was deferred; Strava integration (raised as an alternative to building native GPS
  tracking) IS in scope for this phase, per explicit decision below.

## Scope Decisions

- **Exercise selection**: curated built-in exercise library (common strength exercises) plus
  user-added custom exercises, both searchable from one picker.
- **Cardio tracking**: no native GPS tracking is built. Cardio workouts come exclusively from a
  Strava integration (OAuth connect once, then automatic sync via Strava webhooks). No manual
  cardio-entry form in this phase — if Strava isn't connected, cardio simply isn't logged yet.
- **Weight units**: kg only (no unit toggle in this phase).
- **Editing**: manually-logged workouts (strength, general) are fully editable and deletable.
  Strava-sourced cardio workouts are read-only in the app (Strava is the source of truth; fix
  data there and it re-syncs).
- **Progress charts**: a simple line chart per exercise, plotting top-set weight across recent
  sessions.
- **Strava credentials**: the user registers a Strava API application
  (https://www.strava.com/settings/api) and provides the Client ID + Client Secret. The secret is
  stored and used only server-side in a Cloud Function — it never ships in the client app.

## Tech Stack Additions

- **fl_chart** — line chart rendering for exercise progress, wrapped in a `ProgressChart`
  design-system widget so it inherits the dark/neon theme (`AppColors`, `AppTypography`).
- **flutter_web_auth_2** (or `url_launcher` if simpler in practice) — capturing the OAuth
  redirect from Strava's authorization page.
- **Firebase Cloud Functions** (Node.js/TypeScript, standard Firebase Functions runtime) — first
  use of Cloud Functions in this project. Two functions:
  - `exchangeStravaToken` (callable) — exchanges an OAuth authorization code for tokens using the
    Strava client secret; stores the refresh token in Firestore; also ensures the project-level
    Strava webhook subscription is registered.
  - `stravaWebhook` (HTTPS endpoint) — receives Strava's activity-created push events, resolves
    the Firebase user from the Strava athlete ID, refreshes that user's access token if needed,
    fetches the activity from Strava's API, and writes a `cardio` workout document.

## Data Model (Cloud Firestore additions, under existing `users/{uid}/...` scope)

- `users/{uid}/workouts/{workoutId}`:
  - `type`: `strength` | `cardio` | `general`
  - `date`, `durationMinutes`
  - `source`: `manual` | `strava`
  - `strength` workouts have a nested `exercises/{exerciseId}` subcollection, each with
    `exerciseName` and `sets: [{reps, weightKg}]`.
  - `cardio` workouts (always `source: 'strava'`) store `distanceKm`, `paceMinPerKm`, and
    `stravaActivityId` inline (no subcollection).
  - `general` workouts store free-form `notes` inline.
- `users/{uid}/exerciseLibrary/{exerciseId}` — `name`, `isCustom` (true for user-added exercises,
  false for the curated built-in set). Searched by the exercise picker; new custom exercises are
  written here so they're offered again on future logs.
- `users/{uid}/stravaConnection` (single document) — `athleteId`, `refreshToken` (written only by
  Cloud Functions, never read directly by client code — Firestore rules already restrict this
  path to the owning user, but the client UI itself never needs to read the token value, only a
  connected/disconnected status), `connectedAt`.

Existing Firestore security rules (`match /users/{uid}/{document=**}`) already cover all of these
paths — no rule changes needed for this phase.

## Strava Connection Flow

1. **Connect**: a "Connect Strava" action, surfaced as a banner/button on the Workouts home
   screen when not yet connected, opens Strava's OAuth authorization page in an in-app browser
   flow, capturing the redirect back into the app.
2. The app sends the received authorization code to the `exchangeStravaToken` Cloud Function,
   which exchanges it for an access/refresh token pair via Strava's token endpoint (using the
   client secret, server-side only) and writes the refresh token to
   `users/{uid}/stravaConnection`.
3. The same function call also ensures the Strava webhook subscription is registered for this
   app (a one-time, project-level registration, not per-user).
4. **Sync (automatic, no user action)**: Strava pushes new-activity events to the `stravaWebhook`
   HTTPS endpoint. The function resolves which Firebase user the event's athlete ID belongs to,
   refreshes that user's access token via their stored refresh token if needed, fetches the full
   activity from Strava's API, and writes a `cardio` workout document with `source: 'strava'`
   into that user's `workouts` collection.
5. **Disconnect**: deletes the `stravaConnection` document and revokes the token via Strava's
   deauthorize endpoint (Cloud Function call).

## Screens

1. **Workouts home/history** — reverse-chronological list of logged workouts (type/date/summary
   per row); tap for detail; a "+" action to log a new strength or general workout; a "Connect
   Strava" banner/button at the top when not yet connected (see Strava Connection Flow above).
2. **Log strength workout** — exercise picker (search curated + custom exercises, "add custom
   exercise" inline), then per-exercise sets (reps × weight in kg) with "add set"/"add exercise";
   saving writes the workout document plus its `exercises` subcollection.
3. **Log general workout** — minimal form: date, duration, free-form notes.
4. **Workout detail** — view a single workout's full data; edit/delete available for
   `source: 'manual'` workouts; read-only for `source: 'strava'` workouts.
5. **Exercise progress** — pick an exercise from logged history, view a `fl_chart` line chart of
   top-set weight across recent sessions for that exercise.

## Error Handling

- Strava token exchange/refresh failures surface a retry-able error state in the connect flow,
  not a silent failure — matches the existing app-wide pattern established in Phase 1's sign-in
  screen (loading state + error SnackBar).
- If the `stravaWebhook` function can't resolve a Firebase user for an incoming athlete ID (e.g.
  a stale/orphaned webhook event), it should log and drop the event rather than throwing —
  Strava will not usefully retry on our behalf for this class of error.
- Firestore offline persistence (already enabled app-wide) covers manual workout logging;
  Strava sync inherently requires connectivity (it's server-to-server) and isn't expected to work
  offline.

## Testing

- Unit tests for `WorkoutRepository` (Firestore CRUD, using `fake_cloud_firestore` per the
  existing pattern from Phase 1's `UserProfileRepository`).
- Unit tests for the exercise library search/add-custom logic.
- Widget tests for the strength-logging form (add exercise, add set, validation) and the
  workout history list.
- Cloud Functions: unit tests for `exchangeStravaToken` and `stravaWebhook` using the Firebase
  Functions test SDK, mocking Strava's API responses — no live Strava calls in CI.
- No new Firestore rules to test (existing `users/{uid}` rule already covers the new paths).

## Out of Scope for This Phase

- Native GPS-based cardio tracking (explicitly replaced by Strava integration).
- Manual cardio entry (deferred — cardio is Strava-only for now; could be added later as a
  fallback for users without Strava).
- AI coach / personalized plan generation (deferred to its own future phase).
- Weight unit toggle (kg-only for now).
- Workout programs/routines (predefined multi-week plans) — not part of this phase's spec scope.
