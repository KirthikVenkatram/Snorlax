# Snorlax Domain Model

This document describes the app's data model in implementation-neutral terms: entities, fields, relationships, validation rules, and derived-value logic. It is derived from the current state of the codebase (Flutter client + Firebase Cloud Functions), not an aspirational spec.

Snorlax is a **single-user-per-account** fitness tracker: every piece of data belongs to exactly one authenticated user and lives under that user's own namespace. There is no cross-user sharing or multi-tenant modeling.

---

## 1. Conventions used below

- **Units** are noted in parentheses after a field's type where the field represents a physical quantity (kg, cm, kcal, g, ml, minutes, km, min/km).
- **Nullable** means the field may be absent/null and that absence has defined meaning (almost always "unknown" or "not applicable" — see individual entities for how null propagates through calculations).
- **Embedded** means the data is nested inside a parent document, not a separate collection.
- **FK-like reference** means one entity stores another entity's id as a plain string field (Firestore has no native foreign keys or referential integrity).
- Dates that key a document (e.g. a daily log) are generally formatted `yyyy-MM-dd` and used directly as the Firestore document id, which also gives chronological documents a naturally sortable/lexicographic id.

---

## 2. Identity

### User

The root entity everything else nests under.

| Field | Type | Notes |
|---|---|---|
| `uid` | string | Firebase Auth UID; primary identifier for all data |
| `email` | string, optional | |
| `displayName` | string, optional | |

A `User` has no validation of its own — identity is delegated to Firebase Auth. The **user profile** document at the root of a user's namespace is a separate, lightly-modeled document that other subcollections nest under; all per-user data below is scoped by `uid`.

---

## 3. Body composition

### BodyMeasurement

A single raw measurement of one body metric, taken at a point in time.

| Field | Type | Notes |
|---|---|---|
| `metric` | enum: `weight \| waist \| neck \| hip \| chest \| thigh \| upperArm \| forearm` | |
| `value` | double | magnitude in `unit` |
| `unit` | string | free-text unit label (e.g. "kg", "cm") — not a closed enum |
| `measuredAt` | datetime | when the physical measurement was taken |
| `createdAt` | datetime | when the record was written |
| `method` | string, optional | e.g. "manual", "tape", "scale" |
| `note` | string, optional | |
| `supersessionId` | string, optional | **self-reference**: id of a prior `BodyMeasurement` this one corrects/replaces |

No validation is enforced on this entity at the domain layer.

### BodyCompositionEstimate

A derived, versioned estimate produced by a deterministic calculation — never entered directly by the user.

| Field | Type | Notes |
|---|---|---|
| `bodyFatPercent` | double (%) | |
| `fatMassKg` | double (kg) | |
| `leanBodyMassKg` | double (kg) | |
| `method` | string | estimation method identifier, e.g. `"us-navy-circumference"` |
| `calculationVersion` | int | versions the formula so historical estimates stay reproducible if the formula changes later |
| `sourceMeasurementIds` | list of string | **relationship**: the `BodyMeasurement` ids that fed this estimate |
| `calculatedAt` | datetime | |

**Derived-value rule — U.S. Navy circumference method:**
Given sex, height, weight, waist, neck, and (for females) hip circumference:
1. Convert circumference measurements from cm to inches.
2. Compute body density via a sex-specific log10 formula over the circumference measurements.
3. `bodyFatPercent = 495 / density − 450`, clamped/validated to fall within `[2, 75]` percent (a hard sanity range, not a physiological guarantee).
4. `fatMassKg = weightKg × bodyFatPercent / 100`
5. `leanBodyMassKg = weightKg − fatMassKg`

All input measurements must be positive; hip circumference is required and must be positive for female subjects (not used for male).

---

## 4. Nutrition

### FoodEntry

A single logged food item consumed at a point in time.

| Field | Type | Notes |
|---|---|---|
| `id` | string | |
| `date` | datetime | |
| `mealType` | enum: `breakfast \| lunch \| dinner \| snack` | |
| `foodName` | string | |
| `quantityGrams` | double (g) | |
| `calories` | double (kcal) | |
| `proteinG`, `carbsG`, `fatG` | double (g) each | |
| `source` | enum: `usda \| openFoodFacts \| nutritionix \| llmEstimated \| custom \| openFoodFactsScanned \| recipe` | provenance of the nutrition numbers; `openFoodFactsScanned` (barcode scan) is distinct from `openFoodFacts` (text search) |

No field-level validation is enforced when logging; the log trusts the values supplied by whichever source produced them.

### NutritionGoals

A per-user singleton of daily macro targets.

| Field | Type |
|---|---|
| `dailyCalories` | double (kcal) |
| `proteinG`, `carbsG`, `fatG` | double (g) each |

**Derived-value rule (calculator, not stored automatically):** Targets can be computed from a person's stats via the Mifflin-St Jeor equation:
- `BMR = 10 × weightKg + 6.25 × heightCm − 5 × age + sexOffset`, where `sexOffset = +5` for male, `−161` for female.
- `TDEE = BMR × activityMultiplier`, where activity multiplier is one of `sedentary=1.2, light=1.375, moderate=1.55, active=1.725, veryActive=1.9`.
- `dailyCalories = round(TDEE + goalAdjustment)`, where goal adjustment is `−500` (lose), `0` (maintain), or `+500` (gain) kcal/day.
- `proteinG = weightKg × 2`
- `fatG = (dailyCalories × 0.25) / 9`
- `carbsG = (dailyCalories − proteinG×4 − fatG×9) / 4`
- A related, independent derived figure: `waterTargetMl = round(weightKg × 35)`.

### Water log

Not a modeled entity class — a per-day document holding a single field.

| Field | Type | Notes |
|---|---|---|
| `ml` | int (ml) | clamped to `[0, 2³⁰)` on every write; writes are deltas (can be negative, to undo an entry), not absolute sets |

### CustomFood

A user-defined food with nutrition expressed per 100g.

| Field | Type |
|---|---|
| `id`, `name` | string |
| `caloriesPer100g` | double (kcal / 100g) |
| `proteinPer100g`, `carbsPer100g`, `fatPer100g` | double (g / 100g) each |

### ScannedFood

Ephemeral result of a barcode lookup (Open Food Facts) — not persisted directly; becomes a `FoodEntry` once the user logs it.

| Field | Type |
|---|---|
| `name`, `barcode` | string |
| `caloriesPer100g`, `proteinPer100g`, `carbsPer100g`, `fatPer100g` | double, per 100g |
| `servingLabel` | string, optional (informational, e.g. "per 100g serving") |

### FoodSearchResult

Ephemeral, returned from the server-side food search — not persisted.

| Field | Type |
|---|---|
| `name` | string |
| `source` | enum `FoodSource` (see above) |
| `caloriesPer100g`, `proteinPer100g`, `carbsPer100g`, `fatPer100g` | double, per 100g |

### ParsedFoodItem

Ephemeral output of AI text/image meal parsing — not persisted directly.

| Field | Type |
|---|---|
| `foodName` | string |
| `estimatedQuantityGrams` | double (g) |

### Recipe

A user-built recipe with whole-batch nutrition totals.

| Field | Type |
|---|---|
| `id`, `name` | string |
| `servings` | int |
| `ingredientNames` | list of string (names only — no structured quantities per ingredient) |
| `totalCalories`, `totalProteinG`, `totalCarbsG`, `totalFatG` | double, whole-batch totals |

**Derived-value rule:** `caloriesPerServing = totalCalories / servings` (and the analogous per-serving macro getters), *except* when `servings ≤ 0`, in which case the raw total is returned unchanged rather than dividing by zero.

### CatalogItem (display-only, not persisted)

A unifying shape used to build a "Frequent Foods" list from three sources: recent `FoodEntry` history, `Recipe`s, and a static seed catalog. Built by deduplicating recent food-log entries case-insensitively by name (first occurrence wins), then appending recipes, then the static seed list, capped at a display limit (8 by default).

---

## 5. Meal planning & budgeting

### BudgetSettings

A per-user singleton describing spending limits and preferences.

| Field | Type | Notes |
|---|---|---|
| `currency` | string | e.g. "USD"; free text, not validated against a currency list |
| `dailyLimit`, `weeklyLimit`, `monthlyLimit` | double, nullable, each ≥ 0 | all three may be null ("no budget set" is a valid state) |
| `preferredStores` | list of string | free text |
| `substitutions` | map of string → string | item name → preferred substitute |

### PriceSnapshot

One observed price for a grocery item at a point in time.

| Field | Type | Notes |
|---|---|---|
| `id`, `itemName` | string | |
| `price` | double, nullable | null **only if** `source == unavailable` — never fabricated as 0 |
| `currency` | string | |
| `unit` | string | e.g. "kg", "each", "lb" |
| `quantity` | double, must be > 0 | amount of `unit` the price covers |
| `source` | enum: `manual \| live \| estimated \| unavailable` | `unavailable` is a first-class state, not an error |
| `timestamp` | datetime | |

### MealTemplate

A reusable meal definition with manually-entered per-serving macros and cost (not an ingredient-level recipe builder).

| Field | Type | Notes |
|---|---|---|
| `id`, `name` | string | |
| `servings` | int, must be > 0 | basis for the per-serving figures; kept for display only |
| `caloriesPerServing`, `proteinGPerServing`, `carbsGPerServing`, `fatGPerServing` | double, each ≥ 0 | |
| `costPerServing` | double, nullable, ≥ 0 when present | null means "unpriced," never 0 |
| `currency` | string | |
| `costSource` | enum `PriceSource` (see above) | |
| `costTimestamp` | datetime | |

### MealPlanItem (embedded in MealPlan)

One line item referencing a template plus a quantity, with totals precomputed at aggregation time.

| Field | Type | Notes |
|---|---|---|
| `templateId` | string | **FK-like reference** → `MealTemplate.id` |
| `templateName` | string | denormalized copy of the template's name at aggregation time |
| `servings` | double, must be > 0 | |
| `costPerServing`, `lineCost`, `lineCalories`, `lineProteinG` | double, all nullable | null propagates from an unpriced template rather than being fabricated as 0 |

### MealPlan

A full daily or weekly meal plan.

| Field | Type | Notes |
|---|---|---|
| `id`, `name` | string | |
| `periodType` | enum: `daily \| weekly` | |
| `items` | list of `MealPlanItem` | embedded, not a subcollection |
| `totalCost`, `totalCalories`, `totalProteinG`, `proteinPerCurrencyUnit` | double, all nullable | `totalCost` (and therefore `proteinPerCurrencyUnit`) is null if **any** item's cost is unknown — a plan total is never shown as complete when part of it is unpriced |
| `currency` | string | |
| `source` | enum: `manual \| aiProposal` | provenance only, no behavioral difference |
| `createdAt` | datetime | |

**Derived-value rules (aggregation, shared logic between client calculator and server-side equivalent):**
- `lineCost = template.costPerServing × servings` (null if template unpriced)
- `lineCalories = template.caloriesPerServing × servings`
- `lineProteinG = template.proteinGPerServing × servings`
- `totalCost/totalCalories/totalProteinG` = sums of the corresponding line values; `totalCost` is null if any line's cost is null
- `proteinPerCurrencyUnit = totalProteinG / totalCost`, null if `totalCost` is null or ≤ 0
- Cost projection between period types: `weeklyCost = dailyCost × 7`; `monthlyCost = dailyCost × (365.25 / 12)` (an average month length, so the projection doesn't depend on which month it's computed in); any null input propagates as null.
- **Budget ceiling resolution:** for a `weekly` plan with no explicit `weeklyLimit`, the ceiling falls back to `dailyLimit × 7`; for a `daily` plan it falls back through `weeklyLimit / 7` then `monthlyLimit / 30`. If no relevant limit is configured at all, "within budget" is `null` (indeterminate), not `true` or `false`.

---

## 6. Workouts

### Exercise

An entry in the user's exercise-name catalog, used for autocomplete/reuse across workouts (not embedded inside a workout).

| Field | Type | Notes |
|---|---|---|
| `id`, `name` | string | |
| `isCustom` | bool | true if user-added, false if from a seeded/library list |

### SetEntry (embedded)

One set within a strength exercise.

| Field | Type |
|---|---|
| `reps` | int |
| `weightKg` | double (kg) |

### ExerciseEntry (embedded)

One exercise performed within a strength workout.

| Field | Type | Notes |
|---|---|---|
| `exerciseName` | string | free text — **not** an FK into the `Exercise` catalog |
| `sets` | list of `SetEntry` | |

### Workout

A single logged session. Fields populated depend on `type` (one entity models three shapes rather than three subclasses).

| Field | Type | Notes |
|---|---|---|
| `id` | string | |
| `type` | enum: `strength \| cardio \| general` | |
| `source` | enum: `manual \| strava` | |
| `date` | datetime | |
| `durationMinutes` | int (min) | |
| `exercises` | list of `ExerciseEntry`, nullable | populated only when `type == strength` |
| `distanceKm` | double (km), nullable | populated only when `type == cardio` |
| `paceMinPerKm` | double (min/km), nullable | populated only when `type == cardio` |
| `stravaActivityId` | string, nullable | external reference into Strava's activity id space; set when `source == strava` |
| `notes` | string, nullable | populated only when `type == general` |

**Derived-value rule (Strava ingestion only):** `paceMinPerKm = durationMinutes / distanceKm` (0 if `distanceKm` is 0). Every Strava-sourced activity is stored as `type: cardio` regardless of the actual Strava activity type (e.g. "WeightTraining") — a deliberate simplification, not a classification failure.

---

## 7. Goals

### FitnessGoal

| Field | Type | Notes |
|---|---|---|
| `id`, `name` | string | |
| `category` | enum: `primary \| physique \| performance \| lifestyle` | |
| `status` | enum: `active \| paused \| completed \| archived` | |
| `priority` | int | must be a non-negative integer (enforced by the coach command validator; not necessarily by the client) |
| `targetValue`, `baselineValue`, `currentValue` | double, optional | share one `unit` |
| `unit` | string, optional | free text |
| `targetDate` | datetime, optional | |
| `createdAt`, `updatedAt` | datetime | |
| `metadata` | free-form map, defaults empty | |

**Invariant:** at most one goal may be both `category == primary` and `status == active` at a time. This is enforced by the client repository on create/update, and re-checked independently by the AI coach's command validator (see §11) before any AI-originated goal write is applied.

---

## 8. Habits & adherence

### Habit

| Field | Type | Notes |
|---|---|---|
| `id`, `name` | string | |
| `cadence` | enum: `daily \| weekly` | |
| `timesPerWeek` | int, optional | **required, and must be in `[1, 7]`, when `cadence == weekly`**; ignored for `daily` |
| `createdAt` | datetime | |
| `archived` | bool, default false | |

**Validation rule:** a weekly-cadence habit whose `timesPerWeek` is null or outside `[1, 7]` is rejected before being written (enforced at both the constructor and the repository layer).

### HabitCompletion

A per-day record of every habit's status that day.

| Field | Type | Notes |
|---|---|---|
| `date` | datetime | keys the document (`yyyy-MM-dd`) |
| `entries` | map of `habitId` → `HabitEntryStatus` | **relationship**: each key is a `Habit.id` |

### HabitEntryStatus (embedded)

| Field | Type | Notes |
|---|---|---|
| `completed` | bool | |
| `excluded` | bool, default false | |
| `reason` | enum, optional: `illness \| injury \| plannedRest \| travel \| scheduleChange` | |

**Validation rules:** an excluded entry must carry a `reason`; an entry cannot be both `completed` and `excluded` at once.

### DailyAdherenceSummary

A derived, cached rollup of how well a day matched the user's plan.

| Field | Type | Notes |
|---|---|---|
| `date` | datetime | keys the document |
| `overallScore` | double `[0,1]`, nullable | null means every component was excluded that day — presented neutrally, not as zero |
| `componentScores` | map of component → double `[0,1]` | components: `nutrition, training, habits, recovery` |
| `excludedComponents` | set of component | |
| `calculatedAt` | datetime | |

**Derived-value rule:** `overallScore` is the weighted average of the non-excluded components, using weights that default to `nutrition=0.40, training=0.25, habits=0.20, recovery=0.15`. Excluded components are removed from **both** the numerator and the denominator (the remaining weights are renormalized to sum to 1.0), so a planned rest day or illness does not pull the score down or up relative to a normal day. If every component is excluded, `overallScore` is null. Custom weights, if the user sets any, are stored separately.

### WeeklyAdherenceSummary

| Field | Type | Notes |
|---|---|---|
| `weekId` | string | ISO-8601 week id, format `yyyy-Www` (Thursday-anchored week numbering) |
| `overallScore` | double `[0,1]`, nullable | |
| `dailyScores` | list of double, nullable | that week's 7 `DailyAdherenceSummary.overallScore` values |
| `calculatedAt` | datetime | |

**Derived-value rule:** `overallScore` is the plain average of the non-null entries in `dailyScores` — days with no score shrink the denominator rather than counting as zero. Null if every day was null.

### Streaks (derived, not persisted as an entity)

Computed on demand from a sequence of `DailyAdherenceSummary` (or any similar day-by-day qualifying flag), ordered most-recent-first:
- A day **qualifies** if `overallScore != null && overallScore ≥ threshold` (default `0.6`).
- `current` streak = the count of leading qualifying days before the first non-qualifying day (whether that's a low score or missing data).
- `longest` streak = the longest run of consecutive qualifying days anywhere in the sequence.
- Missing/excluded days do not qualify, but they also do not retroactively erase a streak recorded before them.

---

## 9. Readiness & recovery

### ReadinessEntry

A daily self-reported wellness check-in plus its computed result.

| Field | Type | Notes |
|---|---|---|
| `date` | datetime | keys the document |
| `inputs` | `ReadinessInputs` (embedded) | |
| `result` | `ReadinessResult` (embedded) | always computed together with `inputs`, never stored alone |
| `calculationVersion` | int | versions the scoring formula |

### ReadinessInputs (embedded)

| Field | Type | Notes |
|---|---|---|
| `sleepHours` | double (h), ≥ 0 | |
| `sleepConsistency` | double `[0,1]` | higher = better |
| `soreness` | double `[0,1]` | higher = worse |
| `fatigue` | double `[0,1]` | higher = worse |
| `energy` | double `[0,1]` | higher = better |
| `recentTrainingLoad` | double `[0,1]` | higher = worse |
| `painOrInjury` | bool, default false | |

All numeric ranges above are enforced at construction time.

### ReadinessResult (embedded)

| Field | Type |
|---|---|
| `level` | enum: `green \| yellow \| red` |
| `score` | double `[0,1]` |
| `notes` | list of string (human-readable rationale) |
| `safetyOverrideTriggered` | bool |

**Derived-value rule:**
1. **Hard safety overrides** (checked first, unconditionally force `red`, bypassing the composite score entirely):
   - `painOrInjury == true`, or
   - `sleepHours ≤ 4.0 AND soreness ≥ 0.8`.
2. Otherwise, the composite `score` is the average of six normalized sub-scores: `min(sleepHours/8, 1)`, `sleepConsistency`, `1 − soreness`, `1 − fatigue`, `energy`, `1 − recentTrainingLoad`.
3. Level thresholds: `score ≥ 0.70 → green`, `score ≥ 0.45 → yellow`, otherwise `red`.

This is explicitly not medical advice — it's a self-reported wellness heuristic, not a diagnostic tool.

---

## 10. Sleep

### SleepEntry

| Field | Type | Notes |
|---|---|---|
| `date` | datetime | keys the document |
| `bedtime`, `wakeTime` | datetime | |
| `awakeMinutes` | int (min), ≥ 0 | time spent awake between bedtime and wake time |
| `score` | int `[1,100]` | |
| `restingHeartRate` | int, optional | |
| `hrv` | double, optional | heart-rate variability |
| `stages` | `SleepStageMinutes`, optional (embedded) | only present if manually entered |

### SleepStageMinutes (embedded, optional)

| Field | Type |
|---|---|
| `awake`, `rem`, `deep`, `light` | int (min), each ≥ 0 |

**Derived-value rule:** `timeAsleep = (wakeTime − bedtime) − awakeMinutes`, clamped to zero if the result would be negative.

The schema is deliberately shaped so a future automatic sync (e.g. HealthKit) could populate the same document shape without a migration.

---

## 11. AI coach

The AI coach subsystem reasons over a compact, deterministic snapshot of a user's data (never a raw dump), proposes a change, and only ever applies that change after independent, non-AI validation and explicit user approval. See §14 (Cloud Functions) for the full request flow.

### CoachRecommendation

A record of one AI-generated suggestion. **Server-written only** — the client can read but never write this collection directly; all client mutation goes through the `handleCommand` operation.

| Field | Type | Notes |
|---|---|---|
| `id` | string | |
| `summary` | string | short human-readable summary |
| `rationale` | string | explanation of the reasoning |
| `status` | enum: `pending \| accepted \| rejected` | |
| `createdAt` | datetime | |
| `contextSchemaVersion` | int, optional | versions the context snapshot shape used to generate this recommendation |
| `proposedCommand` | nested, optional | discriminated union — see below |

### ProposedCommand (one of, discriminated by `type`)

| Type | Fields |
|---|---|
| `nutritionTargetChange` | `dailyCalories`, `proteinG`, `carbsG`, `fatG` (all numbers) |
| `goalChange` | `goalId` (nullable — null means "create new"), `name`, `category`, `status`, `priority`, `targetValue` (nullable), `unit` (nullable) |
| `habitChange` | `habitId` (nullable — null means "create new"), `name`, `cadence`, `timesPerWeek` (nullable), `archived` |
| `workoutChange` | `description` (free text) — **advisory only**; there is no structured workout-proposal schema, so this type is never auto-applied |
| `mealPlanChange` | `planId` (nullable), `name`, `periodType`, `items`: list of `{ templateId, servings }` — the AI never supplies cost/calorie/protein numbers itself; those are always computed server-side from already-persisted `MealTemplate` data |

### CoachEvent

An immutable audit record of what actually happened when a recommendation's proposed command was decided on. **Server-written only.**

| Field | Type | Notes |
|---|---|---|
| `id` | string | |
| `recommendationId` | string | **FK-like reference** → `CoachRecommendation.id` |
| `decision` | enum: `approve \| reject` | the user's decision |
| `outcome` | enum: `applied \| rejectedByUser \| rejectedByValidation \| failed` | what actually happened |
| `reason` | string | |
| `createdAt` | datetime | |

### CoachContext (ephemeral request payload, not persisted as its own document — embedded inside `CoachRecommendation.context`)

A compact, versioned summary built fresh on every coach request, deliberately narrower than a full data dump (both a token-budget and a privacy boundary):

- `goals.activePrimary` (id/name/targetValue/unit or null) and `activeSecondaryCount`
- `nutrition.dailyCalorieTarget/proteinTargetG/carbsTargetG/fatTargetG`
- `adherence.latestWeeklyOverallScore`
- `readiness.latestLevel` and `latestSafetyOverrideTriggered`
- `habits.activeCount` (non-archived count)
- `mealPlanning.budget` and `mealPlanning.templates` (capped at 50 templates, each reduced to id/name/costPerServing/caloriesPerServing/proteinGPerServing)

**Validation rules applied to a `ProposedCommand` before it may be applied** (deterministic, non-AI logic — see §14 for how it's wired into the request flow):

- **`nutritionTargetChange`**: rejected outright if `dailyCalories < 1200` (a hard safety floor, not a substitute for the per-user goal calculator) or if any macro is negative. Requires explicit approval (rather than auto-applying) if the change from the current target exceeds 300 kcal in either direction.
- **`goalChange`**: rejected if `priority` isn't a non-negative integer. Rejected if it would create a second concurrently-active primary goal (the AI is never allowed to auto-archive the existing one on the user's behalf). Otherwise always requires explicit approval.
- **`habitChange`**: rejected if `cadence == weekly` and `timesPerWeek` is missing or outside `[1, 7]`. Otherwise allowed automatically.
- **`workoutChange`**: always requires explicit approval; if the user's latest readiness is `red` or a safety override was triggered, this is called out explicitly in the validation reason (but the outcome is still "require approval," never "allow" or "reject" — a coach might legitimately be proposing rest).
- **`mealPlanChange`**: rejected if it has zero items, more than 40 items, any item with `servings ≤ 0` or `> 20`, or any item referencing an unknown `templateId` (an unpriceable plan is never partially allowed through). Rejected if the computed total cost exceeds the applicable budget ceiling for the proposed period (see §5's budget-ceiling fallback rule — same logic, kept consistent between client and server). Otherwise always requires explicit approval.

A validation result computed at recommendation-generation time is purely informational; the command is **re-validated from scratch against freshly-read data** at the moment the user approves it, and only that second validation gates the actual write.

---

## 12. Strava integration

### StravaConnection

| Field | Type | Notes |
|---|---|---|
| `athleteId` | int | Strava's athlete id — used by the Strava webhook to route incoming activity events to a Snorlax user |
| `refreshToken` | string | OAuth refresh token; rotates on use, so the stored value is only ever current as of the last successful refresh |
| `connectedAt` | datetime, nullable | |

This document is **server-owned**: only the token-exchange Cloud Function writes it (via elevated credentials that bypass normal access rules). The client may read it (to show connection status) and delete it (to disconnect), but never write or modify it directly — this prevents a client from redirecting another athlete's activity data to itself.

---

## 13. Firestore collection structure

All application data lives under a single top-level collection, scoped per user:

```
users/{uid}                              — user profile (root document)
users/{uid}/meta/stravaConnection        — StravaConnection (server-write-only)
users/{uid}/meta/{other}                 — misc per-user settings (e.g. adherenceWeights)
users/{uid}/bodyMeasurements/{id}        — BodyMeasurement
users/{uid}/bodyCompositionRecords/{id}  — BodyCompositionEstimate
users/{uid}/foodLog/{id}                 — FoodEntry
users/{uid}/nutritionGoals/goals         — NutritionGoals (fixed doc id)
users/{uid}/waterLog/{yyyy-M-d}          — daily water total
users/{uid}/customFoods/{id}             — CustomFood
users/{uid}/recipes/{id}                 — Recipe
users/{uid}/budgetSettings/current       — BudgetSettings (fixed doc id)
users/{uid}/priceSnapshots/{id}          — PriceSnapshot
users/{uid}/mealTemplates/{id}           — MealTemplate
users/{uid}/mealPlans/{id}               — MealPlan
users/{uid}/workouts/{id}                — Workout
users/{uid}/exerciseLibrary/{id}         — Exercise
users/{uid}/goals/{id}                   — FitnessGoal
users/{uid}/habits/{id}                  — Habit
users/{uid}/habitCompletions/{yyyy-MM-dd}— HabitCompletion
users/{uid}/adherenceDaily/{yyyy-MM-dd}  — DailyAdherenceSummary
users/{uid}/adherenceWeekly/{yyyy-Www}   — WeeklyAdherenceSummary
users/{uid}/readiness/{yyyy-MM-dd}       — ReadinessEntry
users/{uid}/sleep/{yyyy-MM-dd}           — SleepEntry
users/{uid}/coachRecommendations/{id}    — CoachRecommendation (server-write-only)
users/{uid}/coachEvents/{id}             — CoachEvent (server-write-only)
```

**Access model (from `firestore.rules`):** every document under `users/{uid}` is readable and writable only by the authenticated owner of that `uid` — there is no cross-user access anywhere in the schema. Three collections carve out an exception to the owner's normal write access, because they are populated only by Cloud Functions running with elevated (Admin SDK) credentials:
- `users/{uid}/meta/stravaConnection` — owner may read/delete, never write.
- `users/{uid}/coachRecommendations/*` and `users/{uid}/coachEvents/*` — owner may read only.

Everything else — including `goals`, `habits`, and `mealPlans`, which the AI coach can *also* write via the Admin SDK — remains directly owner-writable; there is no schema-level distinction between a user-made edit and a coach-applied edit to those collections.

A known, accepted gap: `adherenceDaily`/`adherenceWeekly` are conceptually *derived* data (a client shouldn't be able to fabricate its own adherence score), but stand up no dedicated write-only Cloud Function yet — they remain owner-writable like ordinary user data, computed and cached by the client-side calculator.

---

## 14. Cloud Function business logic

Nine callable/HTTP Cloud Functions implement server-side logic that must not be trusted to the client: calling external APIs with secrets, running AI inference, and gatekeeping any write the AI proposes.

### `searchFood` (callable)
Fans out a text query to three external food databases (USDA, Open Food Facts, Nutritionix) concurrently, merges whichever succeed (a failure in one source doesn't fail the whole search), and returns ephemeral `FoodSearchResult`s. Nothing is persisted.

### `parseFoodText` (callable)
Sends a free-text meal description to an LLM, asking it to extract each distinct food item as `{foodName, estimatedQuantityGrams}`. Tolerates surrounding prose/markdown in the model's response by extracting the first JSON array literal. Nothing is persisted; the client decides what to log.

### `parseFoodImage` (callable)
Same extraction as `parseFoodText`, but from a base64-encoded photo via a vision-capable LLM call.

### `estimateNutrition` (callable)
Asks an LLM to estimate `{caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g}` for a named food, for cases where no database match exists. Nothing is persisted; this is a fallback data source, one of the `FoodSource` values (`llmEstimated`).

### `exchangeStravaToken` (callable)
Exchanges a Strava OAuth authorization code for tokens, then upserts `users/{uid}/meta/stravaConnection` (`athleteId`, `refreshToken`, `connectedAt`) using the Admin SDK — the only path by which that document is ever written.

### `stravaWebhook` (HTTP endpoint)
Handles both Strava's webhook subscription handshake (GET, echoes a challenge token) and incoming activity events (POST). For a `create` event on an `activity` object:
1. Looks up which user owns the given Strava athlete id via a collection-group query over `meta` documents.
2. Refreshes that user's Strava access token, persisting the rotated refresh token if Strava issued a new one.
3. Fetches the full activity and writes it to `users/{uid}/workouts/strava_{activityId}` with a deterministic document id, so redelivery of the same event is idempotent (an upsert, not a duplicate).
4. Derives `distanceKm = distance / 1000`, `durationMinutes = round(movingTimeSeconds / 60)`, `paceMinPerKm = durationMinutes / distanceKm` (0 if no distance). Every Strava activity is stored with `type: cardio` regardless of its real Strava type.
5. Events that don't map to a known user, or aren't activity-creation events, are silently dropped (not retried) rather than erroring, since Strava's redelivery would just repeat the same no-op.

### `generateRecommendation` (callable)
Builds a `CoachContext` (§11), sends it to an AI provider with a general coaching prompt, validates the AI's JSON response against a strict runtime schema (invalid shapes are rejected and never written), runs the proposed command through the same deterministic validator used at approval time (informational only at this stage), and writes a new `coachRecommendations` document with status `pending`. This function's only write is that recommendation record — it never mutates goals/habits/nutrition/meal-plan data itself.

### `generateMealPlanRecommendation` (callable)
Same shape as `generateRecommendation`, but with a budget/template-focused prompt restricted to proposing only `mealPlanChange` commands (or none) using only template ids the user already has.

### `summarizeProgress` (callable)
Builds the same `CoachContext`, asks the AI for a short natural-language progress summary (2-4 sentences), and returns it directly to the caller. Read-only and advisory — no recommendation record is written, since there is no proposed mutation to gate.

### `handleCommand` (callable)
The single entry point through which an AI-originated proposal can ever actually mutate protected data. Given a `recommendationId` and the user's `approve`/`reject` decision:
1. Loads the recommendation. If rejected (or it had no proposed command), writes a `coachEvents` record with outcome `rejectedByUser` and marks the recommendation `rejected`.
2. If approved: rebuilds `CoachContext` from scratch (never trusts the context or validation result stored on the original recommendation, since context may be stale and any client-supplied field is potentially forgeable) and re-runs the deterministic validator.
3. If validation now rejects, writes a `coachEvents` record with outcome `rejectedByValidation` and marks the recommendation `rejected`.
4. Otherwise applies the command by writing directly to the collection it targets:
   - `nutritionTargetChange` → overwrites `nutritionGoals/goals`.
   - `goalChange` → creates or updates a `goals/{id}` document.
   - `habitChange` → creates or updates a `habits/{id}` document.
   - `workoutChange` → no-op (advisory only; no structured target exists).
   - `mealPlanChange` → computes cost/nutrition totals deterministically from the fresh context's meal templates (never from AI-supplied numbers) and creates or updates a `mealPlans/{id}` document.
5. If the write target no longer exists (e.g. the goal was deleted between generation and approval), catches that as an expected race rather than a server error, records outcome `failed`, and marks the recommendation `rejected` (the closest status the client model supports).
6. On success, writes a `coachEvents` record with outcome `applied` and marks the recommendation `accepted`.

Every path through `handleCommand` writes exactly one `coachEvents` audit record, so every recommendation's fate — applied, rejected by the user, rejected by validation, or failed — is traceable after the fact.
