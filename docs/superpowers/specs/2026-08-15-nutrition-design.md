# Phase 3: Nutrition — Design

Date: 2026-08-15

## Overview

Adds nutrition tracking to the fitness tracker: manual meal logging (search-based or
natural-language), daily calorie/macro goals with progress tracking, and multi-source food data
(USDA FoodData Central, Open Food Facts, Nutritionix) merged behind one search, with an LLM
(Groq, falling back to NVIDIA NIM) filling gaps neither source covers well — particularly
home-cooked South Indian dishes, which no single food database handles cleanly. Builds directly
on Phase 1's Firebase/auth/design-system foundation and reuses the `functions/` Cloud Functions
project Phase 2 established for Strava.

## Scope Decisions

- **Goals**: user sets a daily calorie target plus protein/carbs/fat targets (grams). The daily
  view shows progress against all four.
- **Meal structure**: entries are grouped by meal type (breakfast/lunch/dinner/snack); the daily
  view shows per-meal subtotals plus a day total.
- **Portion size**: always entered as grams. Food-source nutrition values are normalized to
  per-100g so any portion size can be scaled consistently regardless of which source (USDA, Open
  Food Facts, Nutritionix, LLM estimate, or a custom entry) supplied the base numbers.
- **Food data sources**: no single free source has usable coverage of home-cooked Indian food, so
  three are combined:
  - **USDA FoodData Central** — free, requires a (free) API key, ~380k generic foods, strong for
    Western/generic staples.
  - **Open Food Facts** — free, no API key, no meaningful rate limit, strong for
    branded/packaged products globally including many sold in India.
  - **Nutritionix** — free tier (500 req/day, ample for personal use), natural-language-friendly
    matching, broader restaurant/common-dish coverage.
  - When none of the three return a usable match (the common case for a specific home-cooked
    South Indian dish), the LLM estimation fallback (below) or a manual custom entry closes the
    gap.
- **Natural-language logging**: in addition to search-and-pick, a free-text field (e.g. "2 idlis
  and a cup of sambar") is parsed by an LLM into structured `{foodName, estimatedQuantityGrams}`
  items, which the user reviews/edits before saving — this is the fast path for home-cooked meals
  that would otherwise need several manual searches.
- **LLM provider**: Groq (Llama model via its free, no-credit-card-required tier: 30 req/min,
  14,400 req/day) is primary; NVIDIA NIM's free hosted endpoint is the fallback if Groq errors or
  is rate-limited. Both keys are Cloud Functions secrets, never in the client.
- **Custom foods**: when search and LLM estimation both come up empty (or the user just prefers
  manual entry), a custom food entry (name + per-100g calories/macros) can be added directly and
  is saved for reuse — same pattern as Phase 2's custom exercises.
- **Editing**: all food log entries are fully editable/deletable (there's no "read-only, synced
  from elsewhere" source in this phase, unlike Phase 2's Strava cardio workouts).

## Tech Stack Additions

- **Firebase Cloud Functions** (same `functions/` project as Phase 2) — three new callable
  functions:
  - `searchFood(query)` — queries USDA, Open Food Facts, and Nutritionix in parallel
    (`Promise.allSettled` — a single source failing doesn't fail the whole search), normalizes
    each hit to `{name, source, caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g}`, and
    returns a merged, deduplicated list.
  - `parseFoodText(text)` — sends the free-text input to Groq (fallback: NVIDIA NIM) with a
    prompt instructing it to extract a list of `{foodName, estimatedQuantityGrams}` items;
    returns that structured list for the client to review before matching against `searchFood`
    or falling through to `estimateNutrition`.
  - `estimateNutrition(foodName)` — when a `parseFoodText`-extracted food has no match in
    `searchFood`'s results, asks Groq (fallback: NVIDIA NIM) to estimate
    `{caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g}` for it, tagged
    `source: 'llm-estimated'` so the user can see the value is an estimate, not a database fact.
- No new Flutter dependencies expected beyond what Phase 1/2 already added (Riverpod, Firestore,
  `cloud_functions` already present from Phase 2's Strava integration).

## Data Model (Cloud Firestore additions, under existing `users/{uid}/...` scope)

- `users/{uid}/nutritionGoals` (single document) — `dailyCalories`, `proteinG`, `carbsG`, `fatG`.
- `users/{uid}/foodLog/{entryId}` — `date`, `mealType` (`breakfast|lunch|dinner|snack`),
  `foodName`, `quantityGrams`, `calories`, `proteinG`, `carbsG`, `fatG` (the last four are the
  *scaled* values for this entry's `quantityGrams`, computed once at save time — not recomputed
  from a per-100g source on every read), `source`
  (`usda|openfoodfacts|nutritionix|llm-estimated|custom`).
- `users/{uid}/customFoods/{foodId}` — `name`, `caloriesPer100g`, `proteinPer100g`,
  `carbsPer100g`, `fatPer100g`. Searched alongside the three external sources so previously-added
  custom foods come up in future searches without re-entering them.

Existing Firestore security rules (`match /users/{uid}/{document=**}`, with the Phase 2 carve-out
for `meta/stravaConnection`) already cover all of these new paths — no rule changes needed.

## Screens

1. **Nutrition home/daily summary** — today's log grouped by meal (breakfast/lunch/dinner/snack)
   with per-meal and day-total calories/macros, progress bars against `nutritionGoals`, a "+"
   action to log food, date navigation (previous/next day), and an entry point to edit goals.
2. **Log food** — two modes on one screen: (a) a free-text field for natural-language entry,
   which calls `parseFoodText`, shows the parsed items for review/edit (adjust quantity, drop an
   item, or manually match one to a different search result), then resolves each item's
   nutrition via `searchFood` match or `estimateNutrition` fallback before saving; (b) a manual
   search field (calls `searchFood`) with a result list to pick from, an "Add custom" fallback
   when nothing matches, and a grams input to set portion size before saving.
3. **Food log entry detail/edit** — view and edit a single saved entry's meal type, quantity, or
   delete it.
4. **Nutrition goals** — form to set/edit `dailyCalories`, `proteinG`, `carbsG`, `fatG`.

## Error Handling

- `searchFood`'s per-source failures are tolerated (`Promise.allSettled`) — a down Nutritionix
  shouldn't block USDA/Open Food Facts results from showing.
- `parseFoodText`/`estimateNutrition` failures (Groq and NVIDIA NIM both erroring, or a rate
  limit hit on both) surface a retry-able error in the log-food screen, with manual search/custom
  entry always available as a fallback path that doesn't depend on either LLM.
- Firestore offline persistence (already enabled app-wide) covers reading/writing `foodLog`,
  `customFoods`, and `nutritionGoals` once an entry's nutrition values are resolved; `searchFood`/
  `parseFoodText`/`estimateNutrition` themselves are Cloud Function calls and inherently require
  connectivity, same as Strava sync in Phase 2 — not expected to work offline.

## Testing

- Unit tests for a `NutritionRepository` (Firestore CRUD for `foodLog`/`customFoods`/
  `nutritionGoals`, using `fake_cloud_firestore` per the existing pattern).
- Cloud Functions: unit tests for `searchFood` (mocking all three source APIs, verifying
  merge/dedup and per-source-failure tolerance), `parseFoodText`, and `estimateNutrition`
  (mocking Groq/NIM responses and the fallback path) — no live external API calls in CI.
- Widget tests for the daily summary screen (goal progress rendering, empty state) and the
  log-food screen's two modes (search-and-pick flow; natural-language parse-review-save flow).
- No new Firestore rules to test (existing rules already cover the new paths).

## Out of Scope for This Phase

- Barcode scanning (Open Food Facts supports it, but no camera/scanning UI is built this phase —
  search is text-only).
- Recipe/meal composition (combining multiple foods into a reusable "meal" you log as one unit).
- Water tracking, micronutrients beyond protein/carbs/fat, or weight-tracking integration.
- HealthifyMe as a data source — no public developer API was found for it.
- Any paid tier of USDA/Open Food Facts/Nutritionix/Groq/NVIDIA NIM — this phase is scoped to
  stay within each provider's free tier; if usage patterns ever approach those limits, that's a
  future decision, not something silently upgraded to paid.
