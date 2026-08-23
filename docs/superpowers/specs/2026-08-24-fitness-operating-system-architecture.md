# Fitness Operating System — Architecture and Migration Design

Date: 2026-08-24

## Purpose

Evolve the existing personal Flutter + Firebase fitness tracker into a personal
fitness operating system. The application coordinates body composition,
nutrition, training, habits, recovery, goals, budget-aware meal planning, and
AI-assisted coaching. It remains private, single-user, non-medical, and
non-monetized.

Existing Phase 1–3 behavior is valuable and remains in place. This design adds
new modules and controlled integration points rather than replacing the current
auth, workouts, nutrition, Strava, Firebase, Riverpod, or dark neon/glass UI
architecture.

## Current Baseline

- Flutter app for iOS and Android with Riverpod and go_router.
- Firebase Auth, Firestore, Cloud Functions, and Hosting are configured.
- `users/{uid}` stores the onboarding profile and initial calculated nutrition
  targets.
- Workouts are stored at `users/{uid}/workouts` and include manual strength and
  general workouts plus Strava-sourced cardio workouts.
- Nutrition uses `foodLog`, `customFoods`, and `nutritionGoals` subcollections.
- Callable Functions provide authenticated food search, natural-language food
  parsing, and nutrition estimation through Groq with NVIDIA NIM fallback.

## Design Principles

1. Deterministic code owns calculations, safety boundaries, data validation,
   and database mutations.
2. AI interprets compact, structured context and proposes recommendations; it
   never silently changes health, goals, nutrition, training, or habit data.
3. User-entered data is retained as historical data. Derived estimates retain
   their method and calculation version.
4. New Firestore collections are additive and user-scoped. Existing Phase 1–3
   records remain valid without a bulk migration.
5. All AI provider credentials remain inside Cloud Functions.
6. UI work follows domain and persistence work; the dashboard consumes feature
   summaries rather than owning feature business logic.

## System Flow

```text
User data
  -> deterministic summaries and calculations
  -> versioned CoachContext
  -> AI structured recommendation
  -> deterministic validation
  -> optional user approval
  -> command handler
  -> Firestore mutation and coaching event
  -> measurable outcome included in future context
```

The recommendation layer is advisory. A command handler is the only route by
which an AI-originated proposal can modify protected data.

## Goals

### Model

`Goal` is a new first-class domain model in `features/goals`. It has:

- `id`, `name`, `category`, `status`, `priority`, `createdAt`, `updatedAt`
- optional `targetValue`, `unit`, `baselineValue`, `currentValue`, and
  `targetDate`
- extensible optional `metadata` for future goal-type-specific details

Categories are `primary`, `physique`, `performance`, and `lifestyle`. Status is
`active`, `paused`, `completed`, or `archived`. New categories and goal types
must be representable without changing the Firestore schema.

### Primary-goal rule

At most one primary goal may be active at once. Any number of physique,
performance, and lifestyle goals may be active. This prevents contradictory
primary directions while keeping the plan expressive.

### Legacy profile migration

The existing `Goal` enum in the onboarding profile (`lose`, `maintain`, `gain`)
is retained as a legacy metabolic intent for backwards-compatible profile reads
and initial target calculation. It is not an active goal after this migration.
New active goals live at `users/{uid}/goals/{goalId}`.

Profile saves must use Firestore merge semantics before new root-level metadata
is introduced, preventing a profile update from overwriting unrelated root user
fields.

## Body Composition

### Measurements

Raw values are stored as individual immutable historical records at
`users/{uid}/bodyMeasurements/{measurementId}`:

- `metric`: weight, waist, neck, chest, thigh, upperArm, or forearm
- `value`, `unit`, `measuredAt`
- optional `method`, `note`, and `supersedesMeasurementId`
- `createdAt`

Weight uses kilograms internally and circumferences use centimetres internally.
UI conversion, if later added, occurs at the presentation boundary.

### Composition estimates

Derived records are stored separately at
`users/{uid}/bodyCompositionRecords/{recordId}`. A record contains estimated
body-fat percentage, fat mass, and lean body mass, plus `method`, source
measurement IDs, `calculationVersion`, and `calculatedAt`.

Lean body mass is never called muscle mass. All body-fat output is labelled as
an estimate and explicitly not medical-grade. A circumference-based formula is
implemented as a pure, independently tested calculation service.

Progress photos are deferred. When Storage is introduced, Firestore holds only
photo metadata and Storage paths, not image bytes.

## Habits and Adherence

Habits are user-managed at `users/{uid}/habits/{habitId}`. Completions are
recorded by date at `users/{uid}/habitCompletions/{date}`. Daily and weekly
adherence summaries are derived records at `adherenceDaily/{date}` and
`adherenceWeekly/{weekId}`.

The adherence calculator reports nutrition, training, habits, and recovery
components. Default weights are nutrition 40%, training 25%, habits 20%, and
recovery 15%; they are configurable user settings. The calculator accepts
neutral/excluded reasons such as illness, injury, planned rest, travel, and
schedule change. These reduce neither adherence nor the user’s standing.

Adherence language is descriptive and supportive, never punitive.

## Readiness and Recovery

`users/{uid}/readiness/{date}` stores self-reported sleep duration/consistency,
soreness, fatigue, energy, pain or injury flags, recent training-load inputs,
the deterministic readiness result, and calculation version.

The initial deterministic result is green (train normally), yellow (reduce
volume or intensity), or red (recovery/rest; seek appropriate professional help
when pain or concerning symptoms are present). It is not medical advice or a
medically validated assessment. AI may explain the result but cannot override
hard safety conditions.

## Budget-aware Nutrition and Meal Planning

Keep `customFoods` and the present food-log architecture. Do not add an
ingredient recipe builder in this scope.

Add:

- `budgetSettings/current` for monthly, weekly, and daily budgets, currency,
  preferred stores, and substitutions
- `priceSnapshots/{snapshotId}` for item price, quantity/unit, source,
  timestamp, and whether it is manual or live
- `mealTemplates/{templateId}` for reusable meals and portions
- `mealPlans/{planId}` for proposed daily/weekly plans and their calculated
  nutrition/cost totals

Existing food entries may later receive optional `costSnapshot` and
`mealTemplateId` fields. No existing record must be rewritten. Prices are never
hardcoded; a price-provider abstraction supports manual entry first, then live
providers such as Blinkit, Zepto, or local stores. Unavailable live prices are
shown as manual or estimated, with source and timestamp.

Meal-plan calculations deterministically report cost per meal, daily/weekly/
monthly projection, and protein per currency unit. AI may propose a plan but
does not calculate or persist cost without validation.

## AI Provider and Coaching Architecture

### Provider interface

Cloud Functions gains an `AiProvider` abstraction. Provider implementations
remain isolated and preserve Groq as primary and NVIDIA NIM as fallback.

The interface supports structured operations:

- parse food log
- generate coach recommendation
- summarize progress
- generate meal-plan proposal

Each operation validates provider output against a runtime schema before it is
returned or used. Invalid output is rejected, not coerced into health data.

### Coach context

The server builds a compact, deterministic `CoachContext`, including profile,
active goals, recent measurements, 7/30/90-day trends, nutrition and training
summaries, adherence, recovery/readiness, budget constraints, and relevant
recent notes. It includes `contextSchemaVersion` and summary calculation
versions. Raw Firestore exports and unnecessary private data are never sent to
the model.

### Recommendations and commands

`coachRecommendations/{recommendationId}` stores structured advisory output:

- type, title, explanation, evidence, proposed changes, confidence
- `requiresApproval`, context/schema version, provider/model, created time

Recommendations are server-written and client-readable. An accepted proposal
becomes a typed command, for example `ProposedNutritionTargetChange`,
`ProposedWorkoutChange`, `ProposedGoalChange`, or `ProposedHabitChange`.

The command validator applies deterministic safety limits using active goals,
weight trend, nutrition targets, adherence, recovery, and training data. It
returns `allow`, `requireApproval`, or `reject`. A callable command handler
writes validated changes and an immutable event only after the required user
approval.

`coachEvents/{eventId}` is a server-written, client-readable audit record with
recommendation ID, context version, provider/model, proposed action,
validation result, user decision, resulting change, and measurable outcome when
available. It excludes unnecessary raw private data.

## Firestore Security

The current broad owner-write wildcard remains appropriate for normal private
records but must exclude server-owned coaching and derived-record collections.

- Clients may read recommendations and coach events but may not create, edit, or
  delete them.
- Clients cannot write derived adherence/readiness summaries directly.
- AI-originated changes go through authenticated callable Functions.
- Functions validate `request.auth.uid` and use the Admin SDK for protected
  writes.
- Firestore rules must add explicit rules for protected collections and exclude
  them from the existing broad wildcard.

The existing Strava server-owned exception stays unchanged.

## Module Boundaries

```text
lib/features/goals/              domain, repository, providers, UI
lib/features/body_composition/   measurements, trends, calculations, UI
lib/features/habits/             habits and completions
lib/features/adherence/          deterministic summaries and UI
lib/features/readiness/          inputs, calculator, UI
lib/features/meal_planning/      budgets, prices, templates, plans
lib/features/coach/              presentation and callable client service
lib/core/calculations/           pure deterministic calculators
functions/src/ai/                provider abstraction and schemas
functions/src/coach/             context, recommendation, validation, commands
functions/src/meal_planning/     server-side provider adapters where needed
```

Existing workout and nutrition repositories remain their source of truth. New
features consume summaries or repository reads rather than duplicating their
data.

## Delivery Order

1. Body Composition + Goals
2. Habits + Adherence
3. Readiness + Recovery
4. AI Coach infrastructure
5. Budget-aware meal planning
6. Dashboard integration and personal-use polish

Each phase receives a separate implementation plan, TDD-first implementation,
Firestore-rule review, complete relevant test run, analyzer run, and regression
check for all existing phases.

## Test Strategy

Required new tests include:

- circumference/body-composition calculation and measurement validation
- hierarchical goal creation/update and single-active-primary-goal validation
- daily and weekly adherence calculations including neutral exclusions
- readiness result calculation and hard safety conditions
- budget, meal cost, and price-source calculations
- AI recommendation schema validation
- command validation, approval, rejection, and no-bypass behavior
- deterministic, versioned CoachContext generation
- Firestore security rules for server-owned coaching/derived records

External provider calls use mocks only at the provider boundary. Pure domain and
calculation tests use real production code.

## Non-goals

This program does not add social feeds, followers, leaderboards, ads,
subscriptions, App Store monetization, barcode scanning, Apple Health, Google
Fit, or a full ingredient recipe builder. It does not provide medical diagnosis
or medical-grade body-composition/readiness claims.
