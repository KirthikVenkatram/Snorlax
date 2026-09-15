# Glass-UI Handoff: Pixel-Fidelity Rebuild

The user wants a literal one-to-one visual match to
`/Users/kirthikvenkatram/Downloads/design_handoff_glass_ui/` — not the token/component layer
already applied (commit `1248a70` onward), but the actual per-screen LAYOUT, spacing, copy, and
structure from the screenshots in `screens/`. **Replace old layouts outright — don't blend old
structure with new colors.** Read the actual PNG for your screen(s) before writing any code; the
README's prose is a secondary reference, the screenshot is the primary spec.

**Process for this pass, per explicit user instruction:** implement breadth first — get every
screen visually right — before writing thorough tests. A light smoke test per screen (renders
without crashing, key text/buttons present) is enough for now; do not do full TDD. Do NOT run
`flutter run` / install on a device — the user will do that themselves later.

## Non-negotiable: visual fidelity yes, fabricated data no

Match the screenshot's STRUCTURE, spacing, typography, chip/pill styling, and card layout exactly.
Do NOT invent fake data to match the mockup's placeholder content:
- Workouts: the mockup shows a fixed "Push Day A / Pull Day B / Leg Day" program. The real app has
  no program concept — style the list rows exactly like the mockup (type chip, duration, bold
  name, detail line, gradient Start pill) but populate them from real logged/loggable workouts
  (recent `WorkoutRepository` entries + a "Quick start" row), never a hardcoded fake program.
- Today's checklist: real habits due today (`HabitRepository`), never a fixed 4-item list — this
  was already decided and built; preserve it when rebuilding Today's layout.
- Streaks: already computed for real via `StreakCalculator` — preserve that, just fix the visual
  layout around it.
- Every other screen: wire real repository data exactly like the current implementation already
  does: only the visual shell changes, not the data source.

## Shared conventions

Use the existing tokens/widgets (`lib/core/theme/app_colors.dart`, `AppTypography.mono` for HUD
labels, `GlassCard`, `PrimaryButton`, `AmbientBackground`, `Pressable`) — extend them if a screen
needs a shape they don't yet support, don't fork a parallel styling system. `flutter analyze` clean
and the touched screen's smoke test passing before you finish; a broken build blocks every other
agent's work in this shared repo. Commit your own files only (check `git status`, no `-A`). Log
anything genuinely ambiguous to `docs/superpowers/ISSUES.md` under "Glass handoff — pixel rebuild"
(append, don't overwrite) — but don't stop and ask; make the reasonable call and keep moving.

---

## Group A — Sign in, Onboarding, Profile

Screenshots: `screens/01-sign-in.png` (already close, fidelity pass only), `screens/02-onboarding.png`,
`screens/12-profile.png` / `13-screen.png` (same screen, two crops).

1. **Sign-in** (`lib/features/auth/presentation/sign_in_screen.dart`) — already restyled; just
   verify against the screenshot (mark tile top-two-thirds centered, 44px "Snorlax", tagline,
   bottom-anchored pills, footnote) and fix any drift. Low effort, don't over-invest here.
2. **Onboarding** (`lib/features/auth/presentation/onboarding_screen.dart`) — full rebuild, 3
   steps: progress = three 5px pills at top (filled green as steps complete), "STEP n OF 3" kicker,
   34px title, 14px subtitle, then a glass card per step:
   - Step 1 "Who's training?" — Name field, Age field + Male/Female segmented pill (selected =
     neon@20% fill, neon text).
   - Step 2 "Your numbers" — Weight (kg) + Height (cm) side by side, then 5 full-width activity
     pills (Sedentary/Light/Moderate/Active/Very active), selected = neon@18% fill + neon@45%
     border + neon label.
   - Step 3 "Pick a direction" — 3 goal pills (Lose fat -500kcal / Maintain / Build +500kcal), then
     a glass summary card: target kcal at 58px neon with glow, three inner tiles Protein/Carbs/Fat.
     Footer: "Mifflin-St Jeor, scaled by activity, adjusted for your goal. Editable any time."
   Footer nav: "Back" (glass pill) + primary gradient pill ("Continue" / "Start tracking" on step
   3). Targets come from the existing `NutritionGoalCalculator` — recompute on every field change,
   same maths, just the new visual shell. Preserve the existing `onComplete`/`profileRepository`
   save behavior exactly.
3. **Profile** — genuinely new screen, doesn't exist yet
   (`lib/features/auth/presentation/profile_screen.dart` or under settings/ — your call on
   location, but name the class `ProfileScreen`). Per the screenshot: name at 28px, summary line
   ("27 · 92 kg · 178 cm · light" style, built from the real `UserProfile`), hero glass card
   (target kcal at 50px neon + three macro tiles — reuse `NutritionGoalCalculator`/the user's saved
   `NutritionGoals` exactly like the nutrition screen already does), an editor card (Weight/Height
   fields + a Lose fat/Maintain/Build goal segmented pill, footnote "Targets recalculate the moment
   you change anything here" — wire it to actually recompute and let the user save, mirroring
   onboarding step 2/3's calculation), then a settings list (Reminders, Units, Connected, Export
   data — these can be static/display-only rows if there's no real feature behind them yet, that's
   fine, just don't fabricate fake values for anything that IS real, like the account email) and
   two bottom pills: "Replay onboarding" (glass, navigates to `/onboarding`) and "Sign out"
   (red-tinted, calls the real `AuthRepository.signOut` — check `lib/features/settings/presentation/settings_screen.dart`,
   the existing settings screen, for exactly how sign-out and the adherence-weight editor are
   currently wired, and fold that real functionality into this new Profile screen rather than
   duplicating a second settings surface — the adherence-weight editor can live under a collapsed
   "Adherence weights" section within Profile's settings list). Wire a new `/profile` route in
   `lib/core/router/app_router.dart` and repoint `MoreTab`'s "Settings" row at it (keep `/settings`
   route itself working too, in case anything else links to it, but Profile becomes the primary
   Account destination).

---

## Group C — Workouts, Active session, Session complete

Screenshots: `screens/04-workouts.png`, `screens/05-active-session.png`, `screens/06-session-complete.png`.

1. **Workouts list** (`lib/features/workouts/presentation/workouts_home_screen.dart`) — rebuild
   the list rows to match the screenshot exactly: a small pill chip (green "STRENGTH" / "CARDIO"
   etc. per `Workout.type`, `neon@16%` fill, neon text) + duration on one line, bold 17px name,
   12px detail line (e.g. exercise names for strength, pace/zone for cardio — derive from the
   workout's own real data, don't invent), gradient "Start" pill on the right. Populate from real
   `WorkoutRepository.listWorkouts` entries (most recent first) plus a "Quick start" row/button at
   the top that launches the existing `QuickStartScreen` flow — see reconciliation note above, NOT
   a fake fixed program. Below the list, a lower-contrast "Recent" section is redundant with the
   main list now showing real logged workouts — use your judgement on whether to keep a distinct
   "Recent" section or fold it in; document the call.
2. **Active session** (`lib/features/workouts/presentation/active_session_screen.dart`) — already
   built close to spec (sticky header, timer, exercise cards, set chips); do a fidelity pass
   against the screenshot (header gradient scrim, chip glow states, spacing) rather than a rebuild.
3. **Session complete** (`lib/features/workouts/presentation/session_complete_screen.dart`) —
   already close; fidelity pass against the screenshot (gradient wash direction, stat tile layout,
   button row) rather than a rebuild.

---

## Group D — Log food, Scan food, Recipe builder

Screenshots: `screens/07-log-food.png`, `screens/08-scan-food.png`, `screens/09-recipe-builder.png`.

1. **Log food** (`lib/features/nutrition/presentation/log_food_screen.dart`) — this is the biggest
   gap. Rebuild the Search tab's top section to match exactly: large "Log food" title, then a
   search field with a green "Scan" pill directly beside it (already added in a prior pass — verify
   placement matches), then a glass card titled `TODAY · {kcal} kcal` (must not wrap) with
   `{n} items` on the right, one row per logged item (name, "{meal} · {P}P · {C}C · {F}F" detail
   line, kcal, circular × to remove), and a closing coaching line in neon ("{n} kcal and {n}g
   protein still to go today" / "You're over target for today. Tomorrow is a fresh sheet." when
   over). Below that, the existing "FREQUENT FOODS" row (already built) — verify it matches the
   screenshot's card style. The existing Describe/Photo tabs and their logic stay as-is, just make
   sure the overall screen shell (title, AmbientBackground, tab bar) matches the new visual system
   — don't rebuild working logic, only the presentation layer around it.
2. **Scan food** (`lib/features/nutrition/presentation/scan_food_screen.dart`) — already built
   close to spec; fidelity pass against the screenshot (viewfinder frame size/glow, pill styling,
   caption copy) rather than a rebuild.
3. **Recipe builder** (`lib/features/nutrition/presentation/recipe_builder_screen.dart`) — already
   built; fidelity pass against the screenshot (ingredient checklist row style, live per-serving
   summary card styling) rather than a rebuild.

---

## Group E — Sleep, Trends, Streaks

Screenshots: `screens/10-sleep.png`, `screens/11-streaks-habits.png` (Trends has no screenshot,
work from the README's Screen 11 description — already implemented, just needs a fidelity pass on
spacing/typography since it was built without a screenshot reference).

1. **Sleep** (`lib/features/sleep/presentation/sleep_screen.dart`) — fidelity pass against the
   screenshot: violet "LAST NIGHT" kicker, 58px duration with violet glow + "asleep" suffix,
   bed→wake + awake-minutes line, a STAGES card with four full-width rounded horizontal lane bars
   (awake=red dot markers, REM=violet, deep=neon, light=white@65%) over `white@12%` tracks with a
   colour-coded legend row beneath (AWAKE/REM/DEEP/LIGHT with their minute counts), three metric
   tiles (Resting HR / HRV / Score, score tile neon-tinted) in a row, then the existing 7-night bar
   chart. Only render what the existing `SleepEntry` actually has (already correct per Slice C —
   preserve that, this is a visual-only pass).
2. **Trends** (`lib/features/trends/presentation/trends_screen.dart`) — fidelity pass: title +
   "Close" pill header, weight line chart card with the real delta headline, discipline bar chart
   card, then the stats list rows with real deltas (already correct — preserve, visual-only pass).
3. **Streaks** (`lib/features/habits/presentation/streaks_screen.dart`) — fidelity pass against the
   screenshot: "← Today" pill, red-gradient hero with 82px streak number + "days in a row. Longest
   yet: {n}." line, a glass Habits card above the grid (already built — verify placement), then a
   7-wide grid of 10px-radius cells (neon = qualifying day with glow, red = a miss inside the
   current run, `white@8%` = other miss/no-data) — check the existing grid's exact color logic
   against this description and correct if it diverges. Milestone rows below (already built,
   verify styling only).

---

## Group B (not parallelized — done directly, most central screen)

**Today / Home tab** (`lib/features/dashboard/presentation/home_tab.dart`) — screenshot
`screens/03-today.png`. Full rebuild to match: header row (uppercase date kicker + 28px "Morning,
{name}." greeting + glass "Trends" pill on the right, linking to `/trends`), ONE hero glass card
(radius 30) containing BOTH the 140px calorie ring (14px stroke, neon, glow, "KCAL LEFT" label) AND
macro bars side-by-side in the same card (not two separate hero cards like the current build) —
"EATEN/TARGET" label, `{eaten} / {target}` at 20px, three 8px rounded macro bars (protein neon,
carbs violet, fat accent) with "P 47/184g" style captions. Below: the two half-width Training/Last
night tiles (already built, keep), the real-habits daily checklist (already built, keep, verify
visual match — circular checkboxes, strikethrough+dim on completion), an offline banner slot (check
if this repo has any existing connectivity signal before adding a new package for it — if not,
skip and log it, don't add a new dependency just for this), and the real streak banner (already
built, keep, verify gradient direction/typography match). This replaces the current split-hero-card
layout with the mockup's single combined hero card — a real structural change, not just styling.
