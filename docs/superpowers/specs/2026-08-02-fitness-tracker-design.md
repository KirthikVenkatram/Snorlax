# Fitness Tracker App — Design

Date: 2026-08-02

## Overview

Replace the existing Snorlax task-organizer app entirely with a new single-user
fitness tracker: a Flutter app (iOS + Android) that tracks strength/cardio/general
workouts, full nutrition logging (calories/macros, with an ingredient-based recipe
builder to cover home-cooked and Indian/South Indian dishes not present in packaged-food
databases), and a "discipline" module combining habit streaks, a custom daily checklist,
and an auto-computed daily consistency score. Backend is Firebase-only (no custom server).

## Repo Transition

This is a full pivot of the existing repository, not an addition to it.

- Delete: `backend/`, `frontend/`, `snorlax_organizer.db`, `run.py`, `run.bat`,
  `Makefile`, `requirements.txt`, `PRODUCT.md`, `DESIGN.md`, `README.md`, `CLAUDE.md`,
  `package.json`, `package-lock.json`, `.venv/`, `node_modules/`, and any other
  Snorlax-specific files.
- Rewrite git history so no trace of the old Snorlax codebase remains (explicitly
  requested by the user — irreversible; confirm exact command before running).
- Scaffold a fresh Flutter project (`flutter create`) in the repo root.
- Write a new `CLAUDE.md`/`README.md` describing the new app once scaffolding exists.

## Tech Stack

- **Flutter** (Dart) — single codebase for iOS + Android.
- **State management: Riverpod** — testable, no BuildContext plumbing required for
  reads, integrates well with async Firestore streams.
- **Routing**: go_router.
- **Firebase**:
  - Auth — Google Sign-In and Apple Sign-In only (no email/password). Apple Sign-In
    is included alongside Google to satisfy App Store guidelines.
  - Cloud Firestore — all application data (see Data Model).
  - Cloud Storage — progress photos.
  - Cloud Functions — nightly discipline-score recalculation, scheduled reminder
    triggers, optional Open Food Facts proxy.
  - Firebase Cloud Messaging (FCM) — push reminders (e.g. "log today's workout",
    streak-at-risk nudges).
  - Analytics + Crashlytics.
- **Nutrition data source**: Open Food Facts API for barcode/branded product search,
  combined with a per-user `recipes` collection for ingredient-based custom foods
  (built by the user from generic ingredients, which are well covered by open
  databases even when the finished dish, e.g. sambar or dosa, is not).

## Project Layout

```
lib/
  core/           # Firebase clients, theming, routing, shared widgets
  features/
    auth/
    dashboard/
    workouts/
    nutrition/
    discipline/
    profile/
      data/         # Firestore/Firebase access
      domain/       # models, business logic (macro calc, streak calc)
      presentation/ # screens, widgets, Riverpod providers
```

## Data Model (Cloud Firestore)

All data is scoped per-user under `users/{uid}/...`. Security rules require
`request.auth.uid == uid` on every path — no cross-user access in v1 (single-user,
no social features).

- `users/{uid}` — profile (age, weight, height, activity level, goal: lose/maintain/gain),
  computed calorie/macro targets.
- `users/{uid}/workouts/{workoutId}` — type (strength/cardio/general), date, duration;
  strength workouts have an `exercises/{exerciseId}` subcollection (sets/reps/weight);
  cardio workouts store distance/pace inline; general logs are free-form (notes only).
- `users/{uid}/foodLogs/{logId}` — date, mealType, foodRef (Open Food Facts product id
  or a `recipes` doc id), quantity, computed calories/macros.
- `users/{uid}/recipes/{recipeId}` — user-built custom foods: name, ingredient list
  (each with quantity + macro source), computed total macros, reusable for one-tap
  logging thereafter.
- `users/{uid}/habits/{habitId}` — name, frequency (daily/weekly), streak count,
  `completions/{date}` subcollection.
- `users/{uid}/dailyChecklist/{date}` — custom checklist items and completion state.
- `users/{uid}/disciplineScores/{date}` — daily score computed by a Cloud Function
  from workout/food/habit logging consistency.

## Features

1. **Auth** — Google/Apple sign-in; first-login onboarding form (age/weight/height/
   activity level/goal) computes initial calorie/macro targets (BMR/TDEE-based),
   editable afterward from Profile.
2. **Dashboard (home)** — today's snapshot: habit checklist, calories/macros so far
   vs. target (progress rings), whether a workout was logged today, discipline score
   badge.
3. **Workouts** — log a session (strength: exercise picker + sets/reps/weight; cardio:
   duration/distance/pace; general: free-form notes), history list, per-exercise
   progress charts over time.
4. **Nutrition** — search Open Food Facts or the user's saved recipes/custom foods,
   log against a meal; recipe builder (add ingredients → auto-computed macros → save
   as a reusable food); daily macro totals vs. goal.
5. **Discipline** — habit list with streaks, custom daily checklist editor, discipline
   score trend chart.
6. **Profile/Settings** — edit profile & goals, notification preferences, sign out.

## Error Handling & Offline Behavior

- Firestore's built-in offline persistence caches data locally and syncs when back
  online, so logging (workouts, food, habits) works offline by default.
- If an Open Food Facts search returns no results, the UI falls back to "add
  manually?" which drops the user into the recipe/custom-food builder.
- Firebase Auth/network failures show a retry affordance rather than crashing.

## UI / Design Direction

Target feel: modern, sleek, industry-standard, futuristic — a hybrid of two references:

- **Everyday screens (dashboard, logs, history, profile)**: dark, near-black base
  (Whoop/Oura-style) with glowing neon accent colors (electric blue/violet/green),
  glassmorphic cards, circular progress rings, big bold numbers for key stats,
  restrained/data-forward layout.
- **High-emotion moments (workout completed, streak milestone, macro goal hit)**:
  vibrant animated gradients and bold, energetic motion (Nike Training/Strava-style)
  as a celebratory layer on top of the dark base — not the default resting state.
- Micro-interactions throughout (button presses, progress ring fills, checklist ticks)
  should feel tactile/haptic, not static.
- Typography: bold, confident numerals for stats; clean sans-serif for body text.
- Establish this as a proper design system (color tokens, spacing scale, component
  library) up front so it stays consistent as features are added, rather than
  styling each screen ad hoc.

## Testing

- Widget tests for core screens: dashboard, log-workout form, log-food form.
- Unit tests for calculation logic: macro totals, streak counting, discipline-score
  computation.
- Firestore security rules tested via the Firebase Local Emulator Suite.

## Out of Scope for v1

- Social features (friends, feeds, leaderboards) — explicitly deferred; data model
  and security rules assume single-user only.
- Email/password auth.
- Native wearable integrations (Apple Health / Google Fit sync).
