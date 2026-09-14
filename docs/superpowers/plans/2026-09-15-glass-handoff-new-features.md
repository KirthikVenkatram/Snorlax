# Glass-UI Handoff: New Features Plan

Source: `/Users/kirthikvenkatram/Downloads/design_handoff_glass_ui/README.md` (+ prototype +
screenshots). The visual foundation (tokens, `GlassCard` v2, `AmbientBackground`, pill
`PrimaryButton`, Sign-in restyle) is already done — commit `1248a70`. This plan covers the
**new features** the handoff describes that don't exist in the real app yet, reconciled against
what's actually built (the handoff doesn't know about Coach/Adherence/Readiness/Goals/Meal
Planning from Phases 5-8 — those stay, nothing is being removed).

## Reconciliation decisions (binding — agents implement these, not the literal handoff)

1. **Daily checklist vs. Habits.** The handoff's Today screen has a fixed 4-item checklist
   ("Log every meal", "20 min of movement", "2.5 L water", "Lights out by 23:30") described as
   *distinct* from the real `habits/{habitId}` system. Building a second, parallel, hardcoded
   checklist alongside the real flexible Habits feature would be confusing duplicate data. Today's
   checklist card shows the user's **real habits due today** (from `HabitRepository`), not a fake
   fixed list. If a user has zero habits configured, show an empty state pointing at
   `/habits` to add some — not four items nobody configured.
2. **Sleep has no data source.** No HealthKit/Health Connect integration exists or is being added
   in this pass (real device entitlements, native config, App Store review implications — out of
   scope for now). Build Sleep as a **manual check-in**, mirroring `ReadinessRepository`'s shape:
   bedtime, wake time, awake minutes, a self-rated 1-100 score, optional resting HR/HRV. If stage
   breakdown (awake/REM/deep/light minutes) is entered, render the stages bar; if not, show a
   simpler duration + score card instead of fabricating stage data. Architect the repository so a
   future HealthKit sync could write into the same `users/{uid}/sleep/{date}` doc without a schema
   change — that's it, don't build the sync now.
3. **Streaks are computed from real data**, not fake. A "streak" is the count of consecutive days
   (ending today or yesterday) with a `DailyAdherenceSummary.overallScore >= 0.6` (a reasonable,
   documented, adjustable threshold — not the exact number the mockup shows, which is fabricated
   prototype data). Build `lib/core/calculations/streak_calculator.dart`, pure and independently
   tested, taking a list of recent `DailyAdherenceSummary` (already fetchable via
   `AdherenceRepository`) and returning the current streak length + longest streak.
4. **Workouts has no fixed weekly program.** The handoff's Workouts screen lists a fictional
   "Push Day A / Pull Day B / Leg Day" program. The real app has no program/plan concept — only
   ad-hoc logged workouts. Don't invent a program feature. The Workouts list screen (already
   exists — `workouts_home_screen.dart`) keeps listing real logged workouts; add an "active
   session" flow reachable from its existing log actions (or a new "Quick start" pill that begins
   an ad-hoc session), not from a fake program row.
5. **Tab bar.** Keep the current 5-tab structure (Home / Nutrition / Train / Coach / More) —
   don't replace it with the handoff's Today/Train/Fuel/Rest/Me, which drops real features. New
   screens (Sleep, Trends, Streaks, Recipe builder, Scan food) join the relevant existing tab or
   `MoreTab`'s grouped list, exactly like Goals/Habits/Adherence/Readiness/Meal Planning already
   do. This integration (routing + MoreTab entries + Home tab rebuild) is a separate, final step
   — **not** part of any of the slices below, so parallel agents don't collide on
   `app_router.dart`/`more_tab.dart`/`home_tab.dart`.

## Shared conventions (all slices)

- Match `design_handoff_glass_ui/README.md`'s design tokens table exactly — they're already in
  `lib/core/theme/app_colors.dart` (`accentGreen`="neon" #00E5A0, `accentBlue`="accent" #FF3B24,
  `accentViolet`="violet" #7C4DFF, `accentGradient`, `glassFill`/`glassStroke`/`glassHighlight`,
  bloom colors). Use `GlassCard` (already v2), `PrimaryButton` (already a pill), and wrap each new
  screen's `Scaffold.body` in `AmbientBackground` (`lib/core/widgets/ambient_background.dart`).
- Pill geometry everywhere: chips/buttons use `StadiumBorder`/radius 999, cards use radius 26,
  inner tiles 18-20, per the token table.
- Archivo is already the heading font — do not touch `app_typography.dart`'s font choice.
- TDD for domain/calculator/repository logic (this repo's convention — see any existing
  `*_calculator.dart` + its test for the pattern). Widget tests for new screens, following existing
  test conventions (`fake_cloud_firestore`, `pumpTallSurface` helper pattern for tall scrollable
  screens — grep an existing screen test for the exact helper if unsure).
- Run `flutter analyze` and the FULL `flutter test` suite (not just your new files) before
  finishing — zero regressions. `mobile_scanner` and `http` are already added to `pubspec.yaml`;
  run `flutter pub get` if your environment doesn't already reflect that.
- Do NOT touch `app_router.dart`, `lib/features/dashboard/presentation/home_tab.dart`, or
  `lib/features/dashboard/presentation/more_tab.dart` — a separate final step wires routing/nav
  for everything built across all slices at once, to avoid parallel agents colliding on those
  shared files (a known risk in this repo — see `docs/superpowers/ISSUES.md` process notes).
- Log any judgment call, deferred item, or gap to `docs/superpowers/ISSUES.md` under a new
  "Glass handoff — new features" section (create it once; if it already exists from a parallel
  agent, re-read fresh and append rather than overwrite).
- Commit your slice's work when done (check `git status` first, add specific files, not `-A`
  blindly). Do not push. Do not run `firebase deploy`.

---

## Slice A — Recipe builder + Scan food (barcode) + Log food restyle

Owns: `lib/features/nutrition/**` (new files only where noted), does not touch
`nutrition_home_screen.dart`'s tab-bar integration (that's fine to restyle in place, it's not a
shared shell file).

1. **Log food restyle** (`log_food_screen.dart`, already exists): match handoff Screen 7 — a
   search field next to a green "Scan" pill, typing filters results with a
   `Results for "…"` label, a "no matches" card offering "Scan barcode" / "Build recipe" instead
   of a dead end (never a bare empty state). Today's log summary card: `TODAY · {kcal} kcal`
   (must not wrap) + `{n} items`, one row per logged item with a circular × to remove, and a
   coaching line — `"{n} kcal and {n}g protein still to go today"` under target, or
   `"You're over target for today. Tomorrow is a fresh sheet."` over target. A "FREQUENT FOODS"
   catalog section below (reuse `FoodSearchService`/`CustomFoodRepository` — a "frequent" list can
   be the user's most-recently-logged distinct foods, computed client-side from
   `NutritionRepository.listFoodLog`, not a new backend concept).
2. **Scan food** (new `lib/features/nutrition/presentation/scan_food_screen.dart`): full-screen
   camera capture via the `mobile_scanner` package (already added to `pubspec.yaml`) — rounded
   viewfinder frame, "Camera preview — hold the barcode inside the frame" caption, close + torch
   toggle, a "Looking for a barcode…" pill while scanning, and a "No barcode? Build it from
   ingredients" fallback linking to the recipe builder. On a detected barcode, look it up against
   Open Food Facts directly from the client via `http` (already added) —
   `GET https://world.openfoodfacts.org/api/v2/product/{barcode}.json` — no Cloud Function needed,
   it's a public unauthenticated API (mirror the shape `functions/src/foodSources.ts`'s
   `searchOpenFoodFacts` already parses, for consistent field mapping). On a match, a bottom sheet
   (product name + source `"Open Food Facts · {barcode}"`, kcal with a −/+ quantity stepper and
   serving size, four meal-slot pills, "Scan again" / "Add to log" via
   `NutritionRepository.logFood` with `FoodSource` — check `lib/features/nutrition/domain/food_entry.dart`'s
   `FoodSource` enum for the right value, add one if none fits (e.g. `openFoodFactsScanned`) rather
   than misusing an existing one. Camera permission denial (and "not found") both fall back to the
   same "build it from ingredients" path — never a dead end. Reachable only from Log food's "Scan"
   pill, not a separate tab or route anyone else links to yet.
3. **Recipe builder** (new `lib/features/nutrition/presentation/recipe_builder_screen.dart` +
   `lib/features/nutrition/data/recipe_repository.dart` + a `Recipe` domain type): recipe name
   field, servings stepper ("Macros below are per serving"), a checklist of common ingredients
   (South-Indian-leaning seed list per the handoff — Toor dal, Tamarind pulp, Groundnut oil,
   Onion, Drumstick, Sambar powder, etc. — tap to add/remove, selected rows tint green,
   `"Ingredients · {n} added"` live count). Ingredient macros: reuse the existing
   `FoodSearchService.estimateNutrition` (LLM-estimated per-100g) or `search` for known items — do
   not hardcode ingredient macro tables; the app already has a real nutrition-estimation path, use
   it. A green-tinted summary card totals selected ingredients' macros and divides by servings for
   a live per-serving figure. "Save and log one serving" writes to `users/{uid}/recipes/{recipeId}`
   and appends one entry to today's food log via `NutritionRepository.logFood` (mark
   `FoodSource.custom` or a new `recipe` source — again, add an enum value if none fits, don't
   misuse an existing one). After saving once, the recipe should be findable from Log food's
   catalog tagged "Recipe" for one-tap re-logging — a `RecipeRepository.list`/`search` plus a
   catalog row wired into Log food's "FREQUENT FOODS"/search results is enough; don't build a
   separate recipes tab.

Seed data for the frequent/catalog list per the handoff (Indian-first): Idli 2 pcs 156 kcal,
Sambar 120, Filter coffee 90, Whey shake 122, Curd rice 210, Chicken curry 280, Masala dosa 168,
Egg bhurji 245 — use these as `CustomFoodRepository` seed entries if the repo has a seeding
convention (check how `ExerciseLibraryRepository.seedDefaultsIfEmpty` does it for exercises and
mirror that pattern for consistency), or as a static fallback catalog if seeding user data isn't
appropriate for a shared "frequent foods" concept — use judgement, document the choice.

---

## Slice B — Active workout session + Session complete

Owns: `lib/features/workouts/**` (new files), does not touch `app_router.dart`.

1. **Active session** (new `lib/features/workouts/presentation/active_session_screen.dart` +
   a lightweight in-memory session controller — a `StateNotifier`/`ChangeNotifier` or simple
   `StatefulWidget` state is fine, this does not need to survive app restarts per the handoff's own
   state section ("activeWorkoutProvider: workout id, per-set completion map, elapsed seconds,
   running")). No tab bar while active (this screen is pushed full-screen, matching how other
   in-flow screens in this app already cover the tab bar via `Navigator.push`). Sticky translucent
   header (blur, gradient scrim, "← Exit" pill, `{done}/{total} sets` chip, workout name, a
   `mm:ss` timer ticking every second in `AppColors.accentGreen` with a glow, a rounded progress
   bar). One glass card per exercise (name + prescription, e.g. "4 × 8 @ 60 kg" — derive the
   prescription line from the exercise's own logged sets rather than inventing a program), a
   wrapping row of set chips (untapped = faint fill, tapped = accent-gradient filled with a glow);
   tapping toggles completion and updates the header count/bar. This can be reached either from a
   "Quick start" action on `workouts_home_screen.dart` (pick exercises the same way
   `log_strength_screen.dart` already does, or reuse that screen's exercise-picking flow directly)
   or from tapping an existing logged workout to "start" it — pick whichever fits the existing
   screen's structure with the least new UI, document the choice. On finish, write the completed
   sets via the EXISTING `WorkoutRepository.createStrengthWorkout` (real persistence, not a
   prototype-only state) and navigate to Session complete.
2. **Session complete** (new `lib/features/workouts/presentation/session_complete_screen.dart`):
   a celebratory interstitial — diagonal `accentGreen`→`accentViolet` gradient wash, "SESSION
   COMPLETE" kicker, "Nice work." headline (the handoff's streak-count line only makes sense once
   Slice D's real streak exists — show a workout-summary line instead, e.g. "{workout} logged."),
   three glass stat tiles (Time, Sets, Volume — computed from the just-finished session), two
   actions: "Log a meal" (glass, → push `/nutrition`) and "Back to today" (gradient primary, pop
   back to the tab shell). A haptic (`HapticFeedback.mediumImpact()`) on arrival is a reasonable,
   cheap "deliberate animated layer over the static base" per the handoff's own interaction notes
   — a full particle/confetti system is not required, don't add a new animation dependency for it.

---

## Slice C — Sleep

Owns: `lib/features/sleep/**` (new feature slice), does not touch `app_router.dart`.

Mirror `lib/features/readiness/` end to end (domain/data/presentation split, same repository
shape) — it's the closest existing feature to copy the pattern from.

1. `lib/features/sleep/domain/sleep_entry.dart` — `SleepEntry` (date, bedtime, wake time, awake
   minutes, self-rated score 1-100, optional resting HR, optional HRV, optional stage minutes
   `{awake, rem, deep, light}` if the user entered them), JSON codec, `sleepDocId` helper (mirror
   `readinessDocId`).
2. `lib/features/sleep/data/sleep_repository.dart` — owner-scoped CRUD at
   `users/{uid}/sleep/{date}`, `recordCheckIn`/`getByDate`/`listRecent(uid, days)` (for the 7-night
   bar chart).
3. `lib/features/sleep/presentation/sleep_check_in_screen.dart` — a manual entry form (bedtime/wake
   time pickers, awake minutes, 1-100 score slider, optional HR/HRV fields, optional stage-minutes
   fields collapsed under an "Add sleep stages" expandable section since most users won't have
   this data).
4. `lib/features/sleep/presentation/sleep_screen.dart` — the display screen per handoff Screen 10:
   violet "LAST NIGHT" kicker, duration at 58px with a violet glow, bed→wake time line. If stage
   minutes were entered: four stacked rounded lanes (awake/REM/deep/light) with a legend; if not,
   skip the stages card entirely rather than rendering fake bars. Three metric tiles (resting HR,
   HRV, score — omit tiles for fields the user didn't enter, don't show a fake "62 bpm"). A 7-night
   bar chart via `WeeklyBarChart` (already exists, `lib/core/widgets/weekly_bar_chart.dart` —
   reuse it, don't build a second bar chart widget) plotting each night's duration. Skip the
   handoff's canned insight line ("You sleep 48 minutes longer...") — that requires correlating
   sleep with training days, which is a real analysis worth doing properly later, not worth
   fabricating now; note this gap in ISSUES.md.
5. Tests: repository CRUD (`fake_cloud_firestore`), domain JSON round-trip, and a widget test for
   the check-in form persisting an entry and for the display screen rendering with/without stage
   data.

---

## Slice D — Streaks & habits screen

Owns: `lib/core/calculations/streak_calculator.dart` (new), `lib/features/habits/presentation/streaks_screen.dart`
(new), does not touch `app_router.dart` or the existing `habits_screen.dart`/`habit_repository.dart`
(read-only consumer of both Habits and Adherence).

1. `lib/core/calculations/streak_calculator.dart` — pure, independently tested:
   `StreakResult calculate(List<DailyAdherenceSummary> recentDaysNewestFirst, {double threshold = 0.6})`
   returning `{current: int, longest: int}`. A day counts toward the streak if
   `overallScore != null && overallScore >= threshold`; the current streak stops at the first day
   (scanning from most recent) that doesn't qualify OR has no summary at all (missing data breaks
   a streak — don't treat "no data" as "qualifies", and don't treat it as instantly zero either;
   write the exact rule as a doc comment and back it with tests for: an unbroken run, a run broken
   by a low-score day, a run broken by a missing day, an empty list, a single qualifying day).
2. `lib/features/habits/presentation/streaks_screen.dart` — per handoff Screen 12: "← Today" pill,
   the accent-gradient hero (`{n}` at 82px, "days in a row. Longest yet: {longest}."), a glass
   **Habits** card — one row per real habit (`HabitRepository.listHabits`) with a toggle for
   today's completion (reuse `HabitRepository.completeHabit`, already exists) and that single
   habit's own streak (run the same `StreakCalculator` logic against that habit's own completion
   history — you'll need a per-habit daily qualify rule; treat "completed that day" as qualifying,
   reusing the calculator's shape rather than writing a second one). Below: a 7×5 grid of cells
   (last 35 days) coloured by that day's overall adherence qualifying/not/missing, matching the
   handoff's visual language (qualifying = neon glow, current run = accent, miss = faint). Then
   milestone rows (7/10/14/30-day badges, unlocked vs. locked state computed from `longest`, not
   hardcoded).
3. Tests: calculator (task 1) thoroughly per the cases above; a widget test for the screen
   rendering a hero streak count and toggling a habit.

---

## Slice E — Trends

Owns: `lib/features/trends/**` (new feature slice), does not touch `app_router.dart`.

Read-only aggregation screen over data that already exists — no new Firestore writes.

1. `lib/features/trends/presentation/trends_screen.dart` — per handoff Screen 11: title + "Close"
   pill. Weight card: an 8-week line chart from `BodyCompositionRepository`'s existing weight
   measurements (reuse `ProgressChart`, `lib/core/widgets/progress_chart.dart` — already built for
   exactly this, don't build a second line chart widget), with the net change over the window
   (`"-3.4 kg"` style, real computed delta, in neon if negative-is-good or accent if not — use
   judgement, don't hardcode a sign). Discipline card: an 8-week bar chart of weekly adherence
   scores (`AdherenceRepository`'s `WeeklyAdherenceSummary` history — `getWeekly`/
   `computeAndCacheWeekly` already exist; you may need to add a `listRecentWeekly(uid, weeks)`-style
   helper if there's no existing multi-week fetch, matching that repository's existing method
   style) via `WeeklyBarChart`. Then a stats list: calories/day, protein/day, sessions/week,
   sleep/night — each with a real computed week-over-week (or similar window) delta from the
   relevant repository (nutrition, workouts, sleep from Slice C — if Slice C hasn't landed yet
   when this slice runs, stub the sleep row as "—" rather than blocking on it, and note the
   coupling in ISSUES.md). Never fabricate a percentage — compute it or omit that row.
2. Tests: a widget test asserting the screen renders real computed values from seeded repository
   data (not just that it doesn't crash) — follow this repo's existing convention for read-only
   aggregation-screen tests (e.g. `adherence_screen_test.dart`) for the exact pattern.

---

## Final integration (after A-E land — not a parallel slice, do this last)

1. Add go_router routes for every new screen: `/nutrition/scan`, `/nutrition/recipe`,
   `/workouts/active`, `/workouts/session-complete`, `/sleep`, `/sleep/check-in`, `/trends`,
   `/streaks` (adjust names to match whatever the slices actually produced).
2. `MoreTab`: add rows for Sleep, Trends, Streaks alongside the existing Goals/Habits/Adherence/
   Readiness/Meal Planning/Settings rows — same `_NavItem`/`_NavGroup` pattern already there, pick
   sensible section groupings (e.g. Sleep next to Body composition/Habits under "Track"; Trends
   and Streaks under "Insights" next to Adherence/Readiness).
3. `HomeTab` rebuild to match handoff Screen 2 using **real** data: the existing hero
   calorie/adherence cards evolve into the fuller card (ring + macro bars, per the handoff) rather
   than being replaced; a real "Training" tile (last logged workout / "no workout today, log one"
   → Train tab) and a real "Last night" tile (Slice C's latest sleep entry, or a prompt to check in
   if none) that deep-link into Sleep; the checklist card per reconciliation decision #1 (real
   habits due today, not a fake 4-item list); the streak banner using Slice D's real
   `StreakCalculator` output, linking to `/streaks`; an offline banner (Firestore connectivity —
   check if this repo already has a connectivity signal anywhere before adding a new dependency for
   it).
4. Full `flutter test` + `flutter analyze` across the whole app — zero regressions across
   everything built in Phases 1-9 plus this pass.
5. Update `docs/ROADMAP.md` with a line noting this pass and pointing at
   `docs/superpowers/ISSUES.md` for what's deferred (HealthKit sync, the sleep/training insight
   line, etc).
