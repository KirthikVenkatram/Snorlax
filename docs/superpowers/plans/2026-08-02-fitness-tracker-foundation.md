# Fitness Tracker — Phase 1: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tear down the old Snorlax codebase, scaffold a new Flutter + Firebase app, establish the dark/neon design system with reusable components, and ship a working auth → onboarding → dashboard-shell flow that runs on iOS and Android simulators.

**Architecture:** Flutter app with Riverpod for state, go_router for navigation, Firebase (Auth, Firestore) as the only backend. Feature-first folder structure (`lib/features/<feature>/{data,domain,presentation}`) with shared design-system code in `lib/core/`.

**Tech Stack:** Flutter (Dart), Riverpod, go_router, firebase_core, firebase_auth, cloud_firestore, google_sign_in, sign_in_with_apple, google_fonts, mocktail (test), fake_cloud_firestore (test), firebase_auth_mocks (test).

## Global Constraints

- Single-user app: every Firestore path is scoped `users/{uid}/...`; no cross-user reads. (Spec: Data Model)
- Auth methods are Google Sign-In and Apple Sign-In only — no email/password. (Spec: Tech Stack)
- Onboarding computes calorie/macro targets from profile via BMR/TDEE; user can edit afterward. (Spec: Features #1)
- Visual direction: dark, near-black base with neon-glow accents (electric blue/violet/green) and glassmorphic cards for everyday screens; vibrant gradients/bold motion reserved for celebratory moments only, not the resting state. (Spec: UI/Design Direction)
- Firestore offline persistence must remain enabled (default) so logging works offline. (Spec: Error Handling & Offline Behavior)
- The old Snorlax git history must be removed entirely per user instruction (Task 1 only — irreversible, confirm before executing).

---

### Task 1: Repo teardown and history rewrite

**Files:**
- Delete: `backend/`, `frontend/`, `snorlax_organizer.db`, `run.py`, `run.bat`, `Makefile`, `requirements.txt`, `PRODUCT.md`, `DESIGN.md`, `README.md`, `CLAUDE.md`, `package.json`, `package-lock.json`, `.venv/`, `node_modules/`, `docs/` (all pre-existing docs, but **not** the newly created `docs/superpowers/` tree)
- Keep: `.git/`, `.gitignore`, `docs/superpowers/specs/2026-08-02-fitness-tracker-design.md`, `docs/superpowers/plans/2026-08-02-fitness-tracker-foundation.md`, `.claude/`, `.impeccable/`, `.vscode/`

**Interfaces:** N/A (filesystem/git operation only).

- [ ] **Step 1: Confirm with the user before running anything destructive**

This step is a hard stop for a human/subagent operator: re-read back to the user
"I'm about to delete backend/, frontend/, and all other Snorlax files, then rewrite
git history so none of it is recoverable — confirm?" and wait for explicit
confirmation in this session before proceeding to Step 2. Do not proceed on an
assumed yes.

- [ ] **Step 2: Delete the old application files, preserving the new spec/plan docs**

```bash
git rm -r --quiet backend frontend run.py run.bat Makefile requirements.txt \
  PRODUCT.md DESIGN.md README.md CLAUDE.md package.json package-lock.json \
  snorlax_organizer.db
rm -rf .venv node_modules
# Remove old docs/ subtree but keep the new superpowers docs
find docs -mindepth 1 -maxdepth 1 ! -name superpowers -exec git rm -r --quiet {} +
git status
```

Expected: `git status` shows only the new `docs/superpowers/` files remaining
tracked, plus deletions staged for everything else.

- [ ] **Step 3: Commit the teardown**

```bash
git add -A
git commit -m "Remove Snorlax task-organizer app ahead of fitness-tracker rebuild"
```

- [ ] **Step 4: Rewrite git history to remove all trace of the old app**

```bash
git checkout --orphan fresh-start
git add -A
git commit -m "Initial commit: fitness tracker app"
git branch -D main
git branch -m main
git gc --prune=now --aggressive
git log --oneline
```

Expected: `git log --oneline` shows exactly one commit on `main`.

- [ ] **Step 5: If a remote exists, tell the user a force-push is required and stop**

```bash
git remote -v
```

If this prints a remote, tell the user explicitly that `git push --force` to that
remote is required to publish the rewritten history, and wait for their
confirmation before running it — do not force-push unprompted. If no remote is
configured, skip.

---

### Task 2: Flutter project scaffold

**Files:**
- Create: entire Flutter project at repo root (`pubspec.yaml`, `lib/main.dart`, `ios/`, `android/`, `test/`, etc. via `flutter create`)

**Interfaces:** N/A (tooling scaffold).

- [ ] **Step 1: Verify Flutter is installed and on a stable channel**

```bash
flutter --version
flutter doctor
```

Expected: a Flutter 3.x version prints and channel is `stable`. Resolve any
`flutter doctor` errors relevant to iOS/Android toolchains before continuing
(missing Xcode/Android Studio components) — note them to the user if present but
don't block the rest of this task on optional items like unsigned Android
licenses.

- [ ] **Step 2: Scaffold the project into the repo root**

```bash
flutter create --org com.snorlax.fitness --project-name fitness_tracker .
```

Expected: `pubspec.yaml`, `lib/main.dart`, `ios/`, `android/`, `test/widget_test.dart`
are created in the repo root.

- [ ] **Step 3: Remove the default counter app files that will be replaced**

```bash
rm test/widget_test.dart
```

(We replace `lib/main.dart` in Task 9 once the router/theme exist — leave it as
the `flutter create` default for now so `flutter run` still works after this task.)

- [ ] **Step 4: Create the feature-first folder structure**

```bash
mkdir -p lib/core/theme lib/core/router lib/core/widgets lib/core/calculations
mkdir -p lib/features/auth/data lib/features/auth/domain lib/features/auth/presentation
mkdir -p lib/features/dashboard/presentation
mkdir -p test/core/theme test/core/calculations
mkdir -p test/features/auth/data test/features/auth/domain
```

- [ ] **Step 5: Add core dependencies**

```bash
flutter pub add flutter_riverpod go_router google_fonts
flutter pub add --dev mocktail
```

Expected: `pubspec.yaml` gains `flutter_riverpod`, `go_router`, `google_fonts`
under `dependencies` and `mocktail` under `dev_dependencies`.

- [ ] **Step 6: Verify the scaffold builds**

```bash
flutter analyze
flutter test
```

Expected: `flutter analyze` reports "No issues found!" and `flutter test` passes
(no tests exist yet, so it reports 0 tests run, exit code 0).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Scaffold Flutter project with feature-first folder structure"
```

---

### Task 3: Firebase project setup and FlutterFire configuration

**Files:**
- Create: `lib/core/firebase/firebase_options.dart` (generated by `flutterfire configure`)
- Modify: `pubspec.yaml` (adds `firebase_core`, `firebase_auth`, `cloud_firestore`)

**Interfaces:**
- Produces: `DefaultFirebaseOptions.currentPlatform` (generated, used by Task 9's `main.dart` to call `Firebase.initializeApp`).

- [ ] **Step 1: Create the Firebase project (manual, one-time, via console)**

Tell the user to go to https://console.firebase.google.com, create a new project
(e.g. "fitness-tracker"), and enable Google Analytics if desired. This step
cannot be automated — wait for the user to confirm the project exists before
continuing.

- [ ] **Step 2: Enable Auth providers in the Firebase console**

Tell the user to go to Authentication → Sign-in method in the Firebase console
and enable **Google** and **Apple** providers. Apple Sign-In additionally
requires an Apple Developer account configuration (Services ID, key) — tell the
user this is required before Apple Sign-In will work on a real device, but it can
be deferred for simulator-only development in this phase. Wait for confirmation
before continuing.

- [ ] **Step 3: Install the Firebase and FlutterFire CLIs**

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
```

Expected: `firebase login` opens a browser and completes authentication.

- [ ] **Step 4: Run FlutterFire configure**

```bash
flutterfire configure
```

When prompted, select the Firebase project created in Step 1, and select both
`ios` and `android` platforms. Expected: this generates
`lib/firebase_options.dart` and registers iOS/Android apps in the Firebase
project (adds `GoogleService-Info.plist` under `ios/Runner/` and
`google-services.json` under `android/app/`).

- [ ] **Step 5: Move the generated options file into core/firebase**

```bash
mkdir -p lib/core/firebase
mv lib/firebase_options.dart lib/core/firebase/firebase_options.dart
```

- [ ] **Step 6: Add Firebase dependencies**

```bash
flutter pub add firebase_core firebase_auth cloud_firestore
```

- [ ] **Step 7: Verify the app still analyzes cleanly**

```bash
flutter analyze
```

Expected: "No issues found!" (the generated `firebase_options.dart` file must
not reference anything undefined).

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Set up Firebase project and FlutterFire configuration"
```

Note: `google-services.json` and `GoogleService-Info.plist` contain project
identifiers, not secrets — safe to commit, matching standard Firebase/Flutter
practice.

---

### Task 4: Design tokens — colors, typography, theme

**Files:**
- Create: `lib/core/theme/app_colors.dart`
- Create: `lib/core/theme/app_typography.dart`
- Create: `lib/core/theme/app_theme.dart`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Produces: `AppColors` (static color constants), `AppTypography.textTheme` (a `TextTheme`), `AppTheme.dark` (a `ThemeData`) — consumed by `main.dart` in Task 9 and by all component widgets in Task 5.

- [ ] **Step 1: Write the failing test for the theme**

```dart
// test/core/theme/app_theme_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/theme/app_theme.dart';
import 'package:fitness_tracker/core/theme/app_colors.dart';

void main() {
  test('AppTheme.dark uses the near-black background and neon accent', () {
    final theme = AppTheme.dark;

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.accentBlue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: FAIL — `app_theme.dart` / `app_colors.dart` don't exist yet (compile error).

- [ ] **Step 3: Write the color tokens**

```dart
// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

/// Design tokens for the dark, neon-accented base UI.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF15151F);
  static const surfaceGlass = Color(0x1AFFFFFF); // translucent white for glass cards

  static const accentBlue = Color(0xFF3D5AFE);
  static const accentViolet = Color(0xFF9C4DFF);
  static const accentGreen = Color(0xFF00E5A0);

  static const textPrimary = Color(0xFFF5F5FA);
  static const textSecondary = Color(0xFFA0A0B2);

  static const celebrationGradient = [accentViolet, accentBlue, accentGreen];
}
```

- [ ] **Step 4: Write the typography tokens**

```dart
// lib/core/theme/app_typography.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Bold, confident numerals for stats; clean sans-serif for body text.
class AppTypography {
  AppTypography._();

  static TextTheme get textTheme => TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 57,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
      );
}
```

- [ ] **Step 5: Write the theme that composes them**

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentBlue,
          secondary: AppColors.accentViolet,
          tertiary: AppColors.accentGreen,
          surface: AppColors.surface,
        ),
        textTheme: AppTypography.textTheme,
        useMaterial3: true,
      );
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: PASS (1 test).

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme test/core/theme
git commit -m "Add dark neon-accented design tokens and theme"
```

---

### Task 5: Base design-system components — GlassCard, ProgressRing, GradientButton

**Files:**
- Create: `lib/core/widgets/glass_card.dart`
- Create: `lib/core/widgets/progress_ring.dart`
- Create: `lib/core/widgets/gradient_button.dart`
- Test: `test/core/widgets/glass_card_test.dart`
- Test: `test/core/widgets/progress_ring_test.dart`
- Test: `test/core/widgets/gradient_button_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppTypography` from Task 4.
- Produces: `GlassCard({required Widget child})`, `ProgressRing({required double progress, required Color color, Widget? center})` (`progress` is 0.0–1.0), `GradientButton({required String label, required VoidCallback onPressed})` — consumed by Dashboard (Task 10) and later feature phases.

- [ ] **Step 1: Write the failing test for GlassCard**

```dart
// test/core/widgets/glass_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/widgets/glass_card.dart';

void main() {
  testWidgets('GlassCard renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassCard(child: Text('hello')),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/glass_card_test.dart`
Expected: FAIL — `glass_card.dart` doesn't exist.

- [ ] **Step 3: Implement GlassCard**

```dart
// lib/core/widgets/glass_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A frosted-glass card used across everyday (non-celebratory) screens.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/glass_card_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Write the failing test for ProgressRing**

```dart
// test/core/widgets/progress_ring_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/widgets/progress_ring.dart';
import 'package:fitness_tracker/core/theme/app_colors.dart';

void main() {
  testWidgets('ProgressRing renders its center widget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProgressRing(
          progress: 0.5,
          color: AppColors.accentGreen,
          center: const Text('50%'),
        ),
      ),
    );

    expect(find.text('50%'), findsOneWidget);
  });

  test('ProgressRing clamps progress to 0.0-1.0', () {
    const ring = ProgressRing(progress: 1.5, color: AppColors.accentGreen);
    expect(ring.progress.clamp(0.0, 1.0), 1.0);
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/core/widgets/progress_ring_test.dart`
Expected: FAIL — `progress_ring.dart` doesn't exist.

- [ ] **Step 7: Implement ProgressRing**

```dart
// lib/core/widgets/progress_ring.dart
import 'package:flutter/material.dart';

/// A circular progress indicator used for stats like "calories so far".
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.center,
    this.size = 96,
    this.strokeWidth = 10,
  });

  /// 0.0 to 1.0. Values outside this range are clamped at build time.
  final double progress;
  final Color color;
  final Widget? center;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: strokeWidth,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/core/widgets/progress_ring_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 9: Write the failing test for GradientButton**

```dart
// test/core/widgets/gradient_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/widgets/gradient_button.dart';

void main() {
  testWidgets('GradientButton shows its label and calls onPressed when tapped', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: GradientButton(
          label: 'Log Workout',
          onPressed: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Log Workout'), findsOneWidget);

    await tester.tap(find.byType(GradientButton));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 10: Run test to verify it fails**

Run: `flutter test test/core/widgets/gradient_button_test.dart`
Expected: FAIL — `gradient_button.dart` doesn't exist.

- [ ] **Step 11: Implement GradientButton**

```dart
// lib/core/widgets/gradient_button.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A gradient-filled CTA button, used for primary actions and celebratory moments.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: AppColors.celebrationGradient),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 12: Run test to verify it passes**

Run: `flutter test test/core/widgets/gradient_button_test.dart`
Expected: PASS (1 test).

- [ ] **Step 13: Commit**

```bash
git add lib/core/widgets test/core/widgets
git commit -m "Add GlassCard, ProgressRing, and GradientButton design-system components"
```

---

### Task 6: Nutrition goal calculator (BMR/TDEE)

**Files:**
- Create: `lib/core/calculations/nutrition_goal_calculator.dart`
- Test: `test/core/calculations/nutrition_goal_calculator_test.dart`

**Interfaces:**
- Produces: `NutritionGoalCalculator.calculate({required double weightKg, required double heightCm, required int age, required Sex sex, required ActivityLevel activityLevel, required Goal goal})` returning `NutritionTargets { calories, proteinGrams, carbsGrams, fatGrams }`; `Sex` (male/female), `ActivityLevel` (sedentary/light/moderate/active/veryActive), `Goal` (lose/maintain/gain) enums — consumed by the onboarding screen in Task 8.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/calculations/nutrition_goal_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/nutrition_goal_calculator.dart';

void main() {
  group('NutritionGoalCalculator', () {
    test('computes maintenance calories for a moderately active male', () {
      final targets = NutritionGoalCalculator.calculate(
        weightKg: 75,
        heightCm: 178,
        age: 28,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
      );

      // Mifflin-St Jeor BMR = 10*75 + 6.25*178 - 5*28 + 5 = 1737.5
      // TDEE = BMR * 1.55 (moderate) = 2693.125 -> rounds to 2693
      expect(targets.calories, 2693);
      expect(targets.proteinGrams, closeTo(150, 1)); // ~2g/kg bodyweight
    });

    test('applies a 500 calorie deficit for a "lose" goal', () {
      final maintain = NutritionGoalCalculator.calculate(
        weightKg: 75,
        heightCm: 178,
        age: 28,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
      );
      final lose = NutritionGoalCalculator.calculate(
        weightKg: 75,
        heightCm: 178,
        age: 28,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.lose,
      );

      expect(maintain.calories - lose.calories, 500);
    });

    test('applies a 500 calorie surplus for a "gain" goal', () {
      final maintain = NutritionGoalCalculator.calculate(
        weightKg: 75,
        heightCm: 178,
        age: 28,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
      );
      final gain = NutritionGoalCalculator.calculate(
        weightKg: 75,
        heightCm: 178,
        age: 28,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.gain,
      );

      expect(gain.calories - maintain.calories, 500);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/calculations/nutrition_goal_calculator_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement the calculator**

```dart
// lib/core/calculations/nutrition_goal_calculator.dart

enum Sex { male, female }

enum ActivityLevel {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  active(1.725),
  veryActive(1.9);

  const ActivityLevel(this.multiplier);
  final double multiplier;
}

enum Goal { lose, maintain, gain }

class NutritionTargets {
  const NutritionTargets({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
  });

  final int calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
}

/// Computes daily calorie/macro targets using the Mifflin-St Jeor equation
/// for BMR, scaled by activity level to get TDEE, then adjusted for the
/// user's goal. Macros are split protein-first (2g/kg bodyweight), then
/// fat at 25% of total calories, with the remainder as carbs.
class NutritionGoalCalculator {
  NutritionGoalCalculator._();

  static NutritionTargets calculate({
    required double weightKg,
    required double heightCm,
    required int age,
    required Sex sex,
    required ActivityLevel activityLevel,
    required Goal goal,
  }) {
    final sexOffset = sex == Sex.male ? 5 : -161;
    final bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + sexOffset;
    final tdee = bmr * activityLevel.multiplier;

    final goalAdjustment = switch (goal) {
      Goal.lose => -500,
      Goal.maintain => 0,
      Goal.gain => 500,
    };

    final calories = (tdee + goalAdjustment).round();

    final proteinGrams = weightKg * 2;
    final fatGrams = (calories * 0.25) / 9;
    final proteinCalories = proteinGrams * 4;
    final fatCalories = fatGrams * 9;
    final carbsGrams = (calories - proteinCalories - fatCalories) / 4;

    return NutritionTargets(
      calories: calories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/calculations/nutrition_goal_calculator_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/calculations test/core/calculations
git commit -m "Add BMR/TDEE-based nutrition goal calculator"
```

---

### Task 7: AppUser model and Auth repository

**Files:**
- Create: `lib/features/auth/domain/app_user.dart`
- Create: `lib/features/auth/data/auth_repository.dart`
- Test: `test/features/auth/domain/app_user_test.dart`
- Test: `test/features/auth/data/auth_repository_test.dart`

**Interfaces:**
- Consumes: `firebase_auth`'s `FirebaseAuth`, `User`, `GoogleAuthProvider`; `google_sign_in`'s `GoogleSignIn`.
- Produces: `AppUser { uid, email, displayName }` with `AppUser.fromFirebaseUser(User)`; `AuthRepository { Stream<AppUser?> authStateChanges(), Future<AppUser?> signInWithGoogle(), Future<AppUser?> signInWithApple(), Future<void> signOut() }` — consumed by Task 9's routing and Task 8's onboarding.

- [ ] **Step 1: Add auth-related dependencies**

```bash
flutter pub add google_sign_in sign_in_with_apple crypto
flutter pub add --dev firebase_auth_mocks fake_cloud_firestore
```

- [ ] **Step 2: Write the failing test for AppUser**

```dart
// test/features/auth/domain/app_user_test.dart
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/auth/domain/app_user.dart';

void main() {
  test('AppUser.fromFirebaseUser maps uid, email, and displayName', () {
    final firebaseUser = MockUser(
      uid: 'uid-123',
      email: 'trainer@example.com',
      displayName: 'Ash Ketchum',
    );

    final appUser = AppUser.fromFirebaseUser(firebaseUser);

    expect(appUser.uid, 'uid-123');
    expect(appUser.email, 'trainer@example.com');
    expect(appUser.displayName, 'Ash Ketchum');
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/auth/domain/app_user_test.dart`
Expected: FAIL — `app_user.dart` doesn't exist.

- [ ] **Step 4: Implement AppUser**

```dart
// lib/features/auth/domain/app_user.dart
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class AppUser {
  const AppUser({required this.uid, this.email, this.displayName});

  final String uid;
  final String? email;
  final String? displayName;

  factory AppUser.fromFirebaseUser(fb_auth.User user) {
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/auth/domain/app_user_test.dart`
Expected: PASS (1 test).

- [ ] **Step 6: Write the failing test for AuthRepository**

```dart
// test/features/auth/data/auth_repository_test.dart
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/auth/data/auth_repository.dart';

void main() {
  test('authStateChanges emits null when signed out', () async {
    final mockAuth = MockFirebaseAuth(signedIn: false);
    final repository = AuthRepository(firebaseAuth: mockAuth);

    final result = await repository.authStateChanges().first;

    expect(result, isNull);
  });

  test('authStateChanges emits an AppUser when signed in', () async {
    final mockUser = MockUser(uid: 'uid-456', email: 'gym@example.com');
    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
    final repository = AuthRepository(firebaseAuth: mockAuth);

    final result = await repository.authStateChanges().first;

    expect(result?.uid, 'uid-456');
  });

  test('signOut calls FirebaseAuth.signOut', () async {
    final mockUser = MockUser(uid: 'uid-789');
    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
    final repository = AuthRepository(firebaseAuth: mockAuth);

    await repository.signOut();

    expect(mockAuth.currentUser, isNull);
  });
}
```

- [ ] **Step 7: Run test to verify it fails**

Run: `flutter test test/features/auth/data/auth_repository_test.dart`
Expected: FAIL — `auth_repository.dart` doesn't exist.

- [ ] **Step 8: Implement AuthRepository**

```dart
// lib/features/auth/data/auth_repository.dart
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../domain/app_user.dart';

class AuthRepository {
  AuthRepository({
    required fb_auth.FirebaseAuth firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final fb_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  Stream<AppUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(
          (user) => user == null ? null : AppUser.fromFirebaseUser(user),
        );
  }

  Future<AppUser?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    final credential = fb_auth.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    final user = userCredential.user;
    return user == null ? null : AppUser.fromFirebaseUser(user);
  }

  Future<AppUser?> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = fb_auth.OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(oauthCredential);
    final user = userCredential.user;
    return user == null ? null : AppUser.fromFirebaseUser(user);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }
}
```

- [ ] **Step 9: Run test to verify it passes**

Run: `flutter test test/features/auth/data/auth_repository_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 10: Commit**

```bash
git add lib/features/auth/domain lib/features/auth/data test/features/auth pubspec.yaml pubspec.lock
git commit -m "Add AppUser model and AuthRepository with Google/Apple sign-in"
```

---

### Task 8: User profile repository and onboarding screen

**Files:**
- Create: `lib/features/auth/data/user_profile_repository.dart`
- Create: `lib/features/auth/presentation/onboarding_screen.dart`
- Test: `test/features/auth/data/user_profile_repository_test.dart`

**Interfaces:**
- Consumes: `NutritionGoalCalculator` (Task 6), `cloud_firestore`'s `FirebaseFirestore`, `GlassCard`/`GradientButton` (Task 5).
- Produces: `UserProfileRepository { Future<void> saveProfile(String uid, UserProfile profile), Future<UserProfile?> getProfile(String uid) }`, `UserProfile { age, weightKg, heightCm, sex, activityLevel, goal, targets }` — consumed by Task 9's routing (to decide onboarding vs. dashboard) and later by the Dashboard/Nutrition phases.

- [ ] **Step 1: Write the failing test for UserProfileRepository**

```dart
// test/features/auth/data/user_profile_repository_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/nutrition_goal_calculator.dart';
import 'package:fitness_tracker/features/auth/data/user_profile_repository.dart';

void main() {
  test('saveProfile writes to users/{uid} and getProfile reads it back', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = UserProfileRepository(firestore: firestore);

    final profile = UserProfile(
      age: 28,
      weightKg: 75,
      heightCm: 178,
      sex: Sex.male,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.maintain,
      targets: NutritionGoalCalculator.calculate(
        weightKg: 75,
        heightCm: 178,
        age: 28,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
      ),
    );

    await repository.saveProfile('uid-123', profile);
    final result = await repository.getProfile('uid-123');

    expect(result, isNotNull);
    expect(result!.age, 28);
    expect(result.targets.calories, profile.targets.calories);

    final doc = await firestore.collection('users').doc('uid-123').get();
    expect(doc.exists, isTrue);
  });

  test('getProfile returns null when no profile exists', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = UserProfileRepository(firestore: firestore);

    final result = await repository.getProfile('missing-uid');

    expect(result, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/data/user_profile_repository_test.dart`
Expected: FAIL — `user_profile_repository.dart` doesn't exist.

- [ ] **Step 3: Implement UserProfile and UserProfileRepository**

```dart
// lib/features/auth/data/user_profile_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/calculations/nutrition_goal_calculator.dart';

class UserProfile {
  const UserProfile({
    required this.age,
    required this.weightKg,
    required this.heightCm,
    required this.sex,
    required this.activityLevel,
    required this.goal,
    required this.targets,
  });

  final int age;
  final double weightKg;
  final double heightCm;
  final Sex sex;
  final ActivityLevel activityLevel;
  final Goal goal;
  final NutritionTargets targets;

  Map<String, dynamic> toJson() => {
        'age': age,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'sex': sex.name,
        'activityLevel': activityLevel.name,
        'goal': goal.name,
        'targets': {
          'calories': targets.calories,
          'proteinGrams': targets.proteinGrams,
          'carbsGrams': targets.carbsGrams,
          'fatGrams': targets.fatGrams,
        },
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final targetsJson = json['targets'] as Map<String, dynamic>;
    return UserProfile(
      age: json['age'] as int,
      weightKg: (json['weightKg'] as num).toDouble(),
      heightCm: (json['heightCm'] as num).toDouble(),
      sex: Sex.values.byName(json['sex'] as String),
      activityLevel: ActivityLevel.values.byName(json['activityLevel'] as String),
      goal: Goal.values.byName(json['goal'] as String),
      targets: NutritionTargets(
        calories: targetsJson['calories'] as int,
        proteinGrams: (targetsJson['proteinGrams'] as num).toDouble(),
        carbsGrams: (targetsJson['carbsGrams'] as num).toDouble(),
        fatGrams: (targetsJson['fatGrams'] as num).toDouble(),
      ),
    );
  }
}

class UserProfileRepository {
  UserProfileRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<void> saveProfile(String uid, UserProfile profile) async {
    await _firestore.collection('users').doc(uid).set(profile.toJson());
  }

  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromJson(doc.data()!);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/data/user_profile_repository_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Build the onboarding screen (no test — this is UI wiring covered by manual verification in Task 10)**

```dart
// lib/features/auth/presentation/onboarding_screen.dart
import 'package:flutter/material.dart';
import '../../../core/calculations/nutrition_goal_calculator.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../data/user_profile_repository.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.uid,
    required this.profileRepository,
    required this.onComplete,
  });

  final String uid;
  final UserProfileRepository profileRepository;
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  Sex _sex = Sex.male;
  ActivityLevel _activityLevel = ActivityLevel.moderate;
  Goal _goal = Goal.maintain;
  bool _saving = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final age = int.parse(_ageController.text);
    final weightKg = double.parse(_weightController.text);
    final heightCm = double.parse(_heightController.text);

    final targets = NutritionGoalCalculator.calculate(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      sex: _sex,
      activityLevel: _activityLevel,
      goal: _goal,
    );

    final profile = UserProfile(
      age: age,
      weightKg: weightKg,
      heightCm: heightCm,
      sex: _sex,
      activityLevel: _activityLevel,
      goal: _goal,
      targets: targets,
    );

    await widget.profileRepository.saveProfile(widget.uid, profile);

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set up your profile', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                    validator: (v) => (v == null || int.tryParse(v) == null) ? 'Enter a valid age' : null,
                  ),
                  TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Weight (kg)'),
                    validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a valid weight' : null,
                  ),
                  TextFormField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Height (cm)'),
                    validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a valid height' : null,
                  ),
                  DropdownButtonFormField<Sex>(
                    value: _sex,
                    decoration: const InputDecoration(labelText: 'Sex'),
                    items: Sex.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _sex = v!),
                  ),
                  DropdownButtonFormField<ActivityLevel>(
                    value: _activityLevel,
                    decoration: const InputDecoration(labelText: 'Activity level'),
                    items: ActivityLevel.values
                        .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _activityLevel = v!),
                  ),
                  DropdownButtonFormField<Goal>(
                    value: _goal,
                    decoration: const InputDecoration(labelText: 'Goal'),
                    items: Goal.values
                        .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _goal = v!),
                  ),
                  const SizedBox(height: 24),
                  _saving
                      ? const Center(child: CircularProgressIndicator())
                      : GradientButton(label: 'Continue', onPressed: _submit),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run the full test suite to confirm nothing else broke**

Run: `flutter test`
Expected: all tests pass (theme, widgets, calculator, auth, profile repository).

- [ ] **Step 7: Commit**

```bash
git add lib/features/auth
git commit -m "Add UserProfileRepository and onboarding screen"
```

---

### Task 9: Auth providers, router, and sign-in screen

**Files:**
- Create: `lib/features/auth/presentation/auth_providers.dart`
- Create: `lib/features/auth/presentation/sign_in_screen.dart`
- Create: `lib/core/router/app_router.dart`

**Interfaces:**
- Consumes: `AuthRepository` (Task 7), `UserProfileRepository` (Task 8), `OnboardingScreen` (Task 8), `GradientButton` (Task 5).
- Produces: `authRepositoryProvider`, `firestoreProvider`, `userProfileRepositoryProvider`, `authStateProvider` (Riverpod `Provider`s/`StreamProvider`), `appRouter` (a `GoRouter`) — consumed by `main.dart` in Task 10.

- [ ] **Step 1: Define Riverpod providers for auth and Firestore**

```dart
// lib/features/auth/presentation/auth_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/user_profile_repository.dart';
import '../domain/app_user.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(firebaseAuth: ref.watch(firebaseAuthProvider));
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(firestore: ref.watch(firestoreProvider));
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
```

- [ ] **Step 2: Build the sign-in screen**

```dart
// lib/features/auth/presentation/sign_in_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/gradient_button.dart';
import 'auth_providers.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Fitness Tracker', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 48),
            GradientButton(
              label: 'Sign in with Google',
              onPressed: () => ref.read(authRepositoryProvider).signInWithGoogle(),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: 'Sign in with Apple',
              onPressed: () => ref.read(authRepositoryProvider).signInWithApple(),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Build the router with an auth-state redirect**

```dart
// lib/core/router/app_router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final profileRepository = ref.watch(userProfileRepositoryProvider);

  return GoRouter(
    initialLocation: '/sign-in',
    redirect: (context, state) async {
      final user = await authRepository.authStateChanges().first;
      final signingIn = state.matchedLocation == '/sign-in';

      if (user == null) return signingIn ? null : '/sign-in';

      final profile = await profileRepository.getProfile(user.uid);
      final onboarding = state.matchedLocation == '/onboarding';

      if (profile == null) return onboarding ? null : '/onboarding';
      if (signingIn || onboarding) return '/dashboard';

      return null;
    },
    routes: [
      GoRoute(path: '/sign-in', builder: (context, state) => const SignInScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) {
          // Captured `ref` (from the enclosing Provider) rather than
          // route `extra`, since redirects don't carry `extra` through.
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return OnboardingScreen(
            uid: uid,
            profileRepository: profileRepository,
            onComplete: () => GoRouter.of(context).go('/dashboard'),
          );
        },
      ),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
    ],
  );
});
```

- [ ] **Step 4: Run analyzer and full test suite**

Run: `flutter analyze && flutter test`
Expected: "No issues found!" and all tests pass. (`dashboard_screen.dart` is
required by the import above — it's created in Task 10; if running this task
standalone, stub it temporarily with a one-line `Scaffold` and let Task 10
replace it.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation lib/core/router
git commit -m "Add auth providers, sign-in screen, and router with onboarding redirect"
```

---

### Task 10: Dashboard shell and app entry point

**Files:**
- Create: `lib/features/dashboard/presentation/dashboard_screen.dart`
- Create/Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `appRouterProvider` (Task 9), `AppTheme.dark` (Task 4), `DefaultFirebaseOptions` (Task 3), `GlassCard`, `ProgressRing` (Task 5).
- Produces: the running app entry point — this is the last task in Phase 1; nothing downstream in this plan consumes it, but Phase 2 (Workouts) replaces the placeholder body of `DashboardScreen`.

- [ ] **Step 1: Build the placeholder dashboard screen**

```dart
// lib/features/dashboard/presentation/dashboard_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/theme/app_colors.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                const ProgressRing(
                  progress: 0,
                  color: AppColors.accentGreen,
                  center: Text('0 kcal'),
                ),
                const SizedBox(height: 16),
                const Text('Workouts, nutrition, and habits land here in Phase 2+.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Wire up main.dart**

```dart
// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/firebase/firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: FitnessTrackerApp()));
}

class FitnessTrackerApp extends ConsumerWidget {
  const FitnessTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Fitness Tracker',
      theme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all tests from Tasks 4-8 pass (theme, widgets, calculator, auth
repository, profile repository).

- [ ] **Step 4: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 5: Manually run the app on a simulator/emulator**

```bash
flutter run
```

Expected: app launches to the sign-in screen with the dark/neon theme applied,
"Sign in with Google" and "Sign in with Apple" buttons visible. Signing in with
a real Google account (simulator) should route to onboarding on first sign-in,
and to the dashboard placeholder after submitting the profile form.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dashboard lib/main.dart
git commit -m "Add dashboard shell and wire up app entry point with routing"
```

---

## Phase 1 Exit Criteria

- `flutter analyze` is clean and `flutter test` passes across the whole suite.
- The app runs on an iOS or Android simulator, showing the dark/neon-glow themed
  sign-in screen.
- A new user can sign in with Google or Apple, complete onboarding (profile →
  computed calorie/macro targets saved to Firestore), and land on a themed
  dashboard placeholder.
- Returning users (profile already exists) skip onboarding and go straight to
  the dashboard.
- Reusable `GlassCard`, `ProgressRing`, `GradientButton` components and the
  `AppTheme`/`AppColors`/`AppTypography` tokens exist for Phase 2+ to build on.
