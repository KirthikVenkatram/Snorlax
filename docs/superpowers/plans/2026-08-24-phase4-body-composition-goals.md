# Phase 4: Body Composition + Goals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add historical body measurements, deterministic and clearly-labelled body-composition estimates, and hierarchical goals without disrupting existing profile, workout, or nutrition data.

**Architecture:** New `body_composition` and `goals` feature modules own their domain models, Firestore repositories, Riverpod providers, and screens. A pure calculator produces U.S. Navy circumference estimates from stored measurements. Existing onboarding intent remains a legacy metabolic input; active goals are stored separately in `users/{uid}/goals`.

**Tech Stack:** Flutter/Dart, Riverpod, Firestore, fake_cloud_firestore, flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-24-fitness-operating-system-architecture.md`

## Global Constraints

- Preserve all Phase 1–3 collections and public constructors unless a backward-compatible optional argument is used.
- Store weight in kilograms and all circumferences in centimetres.
- Add `hip` as an optional circumference metric so the female U.S. Navy estimate is available.
- Label body-fat, fat mass, and lean body mass as estimates; never call lean body mass muscle mass.
- At most one primary goal may have `active` status at any time.
- Use merge semantics for root `users/{uid}` profile saves.
- Do not add AI, Storage, live price providers, habits, or readiness in this phase.
- Every new behavior follows RED → GREEN → REFACTOR and is verified with `flutter test` and `flutter analyze`.

---

## File Structure

- `lib/features/goals/domain/fitness_goal.dart` — goal categories, statuses, value object, JSON codec.
- `lib/features/goals/data/goal_repository.dart` — owner-scoped Firestore CRUD and active-primary guard.
- `lib/features/goals/presentation/goal_providers.dart` — repository provider.
- `lib/features/goals/presentation/goals_screen.dart` — list/create/update goal UI.
- `lib/features/body_composition/domain/body_measurement.dart` — measurement metrics/methods and immutable record.
- `lib/features/body_composition/domain/body_composition_estimate.dart` — labelled derived estimate record.
- `lib/core/calculations/body_composition_calculator.dart` — pure U.S. Navy formula and input validation.
- `lib/features/body_composition/data/body_composition_repository.dart` — measurement/estimate persistence and trends.
- `lib/features/body_composition/presentation/body_composition_providers.dart` — repository provider.
- `lib/features/body_composition/presentation/body_composition_screen.dart` — check-in form and trends UI.
- `lib/core/router/app_router.dart` and `lib/features/dashboard/presentation/dashboard_screen.dart` — navigation only.

### Task 1: Preserve profile data and add the hierarchical goal domain model

**Files:**
- Modify: `lib/features/auth/data/user_profile_repository.dart`
- Create: `lib/features/goals/domain/fitness_goal.dart`
- Modify: `test/features/auth/data/user_profile_repository_test.dart`
- Create: `test/features/goals/domain/fitness_goal_test.dart`

**Interfaces:**
- Produces `GoalCategory { primary, physique, performance, lifestyle }`.
- Produces `GoalStatus { active, paused, completed, archived }`.
- Produces immutable `FitnessGoal` with `toJson()` and `FitnessGoal.fromJson(String id, Map<String, dynamic> json)`.
- `UserProfileRepository.saveProfile` retains unrelated root document fields.

- [ ] **Step 1: Write the failing tests**

```dart
test('saveProfile merges rather than replacing unrelated user data', () async {
  final firestore = FakeFirebaseFirestore();
  final repository = UserProfileRepository(firestore: firestore);
  await firestore.collection('users').doc('u').set({'futureSetting': true});

  await repository.saveProfile('u', profile);

  expect((await firestore.collection('users').doc('u').get()).data()!['futureSetting'], true);
});

test('FitnessGoal JSON round-trip retains optional goal values', () {
  final goal = FitnessGoal(
    id: 'g1', name: 'Reduce waist', category: GoalCategory.physique,
    status: GoalStatus.active, priority: 2, targetValue: 80, unit: 'cm',
    baselineValue: 92, currentValue: 90, targetDate: DateTime(2026, 12, 1),
    createdAt: DateTime(2026, 8, 24), updatedAt: DateTime(2026, 8, 24),
  );
  expect(FitnessGoal.fromJson(goal.id, goal.toJson()).targetValue, 80);
});
```

- [ ] **Step 2: Run tests to verify RED**

Run: `flutter test test/features/auth/data/user_profile_repository_test.dart test/features/goals/domain/fitness_goal_test.dart`

Expected: the merge assertion fails and the missing goal import/type prevents compilation.

- [ ] **Step 3: Implement the minimum production code**

```dart
enum GoalCategory { primary, physique, performance, lifestyle }
enum GoalStatus { active, paused, completed, archived }

class FitnessGoal {
  const FitnessGoal({
    required this.id, required this.name, required this.category,
    required this.status, required this.priority, required this.createdAt,
    required this.updatedAt, this.targetValue, this.unit, this.baselineValue,
    this.currentValue, this.targetDate, this.metadata = const {},
  });
  // Final fields and JSON conversion exactly matching the constructor.
}
```

Change the profile write to `set(profile.toJson(), SetOptions(merge: true))`.

- [ ] **Step 4: Run tests to verify GREEN**

Run: `flutter test test/features/auth/data/user_profile_repository_test.dart test/features/goals/domain/fitness_goal_test.dart`

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/data/user_profile_repository.dart lib/features/goals/domain/fitness_goal.dart test/features/auth/data/user_profile_repository_test.dart test/features/goals/domain/fitness_goal_test.dart
git commit -m "Add hierarchical goal domain model"
```

### Task 2: Add goal persistence with the one-active-primary invariant

**Files:**
- Create: `lib/features/goals/data/goal_repository.dart`
- Create: `lib/features/goals/presentation/goal_providers.dart`
- Create: `test/features/goals/data/goal_repository_test.dart`

**Interfaces:**
- Consumes `FitnessGoal`, `Firestore`, and `firestoreProvider`.
- Produces `Future<String> createGoal(String uid, FitnessGoal goal)`, `Future<List<FitnessGoal>> listGoals(String uid)`, `Future<void> updateGoal(String uid, FitnessGoal goal)`, and `Future<void> archiveGoal(String uid, String id)`.
- Creation or activation of a primary goal archives all other active primary goals in one Firestore batch.

- [ ] **Step 1: Write failing repository tests**

```dart
test('creating a primary goal archives the earlier active primary goal', () async {
  final repository = GoalRepository(firestore: FakeFirebaseFirestore());
  await repository.createGoal('u', fatLossGoal);
  await repository.createGoal('u', recompositionGoal);

  final goals = await repository.listGoals('u');
  expect(goals.where((g) => g.category == GoalCategory.primary && g.status == GoalStatus.active),
      hasLength(1));
  expect(goals.singleWhere((g) => g.id == fatLossGoal.id).status, GoalStatus.archived);
});

test('non-primary goals may remain active together', () async {
  await repository.createGoal('u', waistGoal);
  await repository.createGoal('u', pushupGoal);
  expect((await repository.listGoals('u')).where((g) => g.status == GoalStatus.active), hasLength(2));
});
```

- [ ] **Step 2: Run tests to verify RED**

Run: `flutter test test/features/goals/data/goal_repository_test.dart`

Expected: FAIL because `GoalRepository` is undefined.

- [ ] **Step 3: Implement repository and provider**

Use `_goals(uid) => firestore.collection('users').doc(uid).collection('goals')`. Before creating or updating an active primary goal, query active primary goals and batch-update each different document to `status: 'archived'` and a server-compatible `updatedAt` timestamp; write the requested goal in that same batch. List goals in `updatedAt` descending order. `archiveGoal` updates only status and `updatedAt`.

```dart
final goalRepositoryProvider = Provider<GoalRepository>((ref) =>
    GoalRepository(firestore: ref.watch(firestoreProvider)));
```

- [ ] **Step 4: Run tests to verify GREEN**

Run: `flutter test test/features/goals/data/goal_repository_test.dart`

Expected: all goal repository tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/goals/data/goal_repository.dart lib/features/goals/presentation/goal_providers.dart test/features/goals/data/goal_repository_test.dart
git commit -m "Add goal repository and primary-goal invariant"
```

### Task 3: Add deterministic body-composition models and calculator

**Files:**
- Create: `lib/features/body_composition/domain/body_measurement.dart`
- Create: `lib/features/body_composition/domain/body_composition_estimate.dart`
- Create: `lib/core/calculations/body_composition_calculator.dart`
- Create: `test/core/calculations/body_composition_calculator_test.dart`

**Interfaces:**
- Produces `BodyMetric { weight, waist, neck, hip, chest, thigh, upperArm, forearm }`.
- Produces `BodyMeasurement` with metric, value, unit, measuredAt, optional method/note/supersession ID, and createdAt.
- Produces `BodyCompositionEstimate` with `bodyFatPercent`, `fatMassKg`, `leanBodyMassKg`, `method`, `calculationVersion`, `sourceMeasurementIds`, and `calculatedAt`.
- Produces `BodyCompositionCalculator.estimate({required Sex sex, required double heightCm, required double weightKg, required double waistCm, required double neckCm, double? hipCm})`.

- [ ] **Step 1: Write failing calculator tests**

```dart
test('calculates a labelled male circumference estimate', () {
  final result = BodyCompositionCalculator.estimate(
    sex: Sex.male, heightCm: 178, weightKg: 80, waistCm: 90, neckCm: 38,
  );
  expect(result.method, 'us-navy-circumference');
  expect(result.bodyFatPercent, inInclusiveRange(5, 45));
  expect(result.fatMassKg + result.leanBodyMassKg, closeTo(80, 0.01));
});

test('requires hip circumference for a female circumference estimate', () {
  expect(() => BodyCompositionCalculator.estimate(
    sex: Sex.female, heightCm: 165, weightKg: 65, waistCm: 75, neckCm: 32,
  ), throwsArgumentError);
});

test('rejects impossible circumference geometry', () {
  expect(() => BodyCompositionCalculator.estimate(
    sex: Sex.male, heightCm: 178, weightKg: 80, waistCm: 35, neckCm: 38,
  ), throwsArgumentError);
});
```

- [ ] **Step 2: Run tests to verify RED**

Run: `flutter test test/core/calculations/body_composition_calculator_test.dart`

Expected: FAIL because the calculator does not exist.

- [ ] **Step 3: Implement models and pure calculator**

Convert centimetres to inches before applying U.S. Navy density equations:

```dart
final height = heightCm / 2.54;
final waist = waistCm / 2.54;
final neck = neckCm / 2.54;
final density = sex == Sex.male
  ? 1.0324 - 0.19077 * log(waist - neck) / ln10 + 0.15456 * log(height) / ln10
  : 1.29579 - 0.35004 * log(waist + hip - neck) / ln10 + 0.22100 * log(height) / ln10;
final bodyFatPercent = 495 / density - 450;
```

Reject non-positive values, missing female hip, non-positive log arguments, and body-fat percentages outside 2–75. Derive `fatMassKg = weightKg * bodyFatPercent / 100` and `leanBodyMassKg = weightKg - fatMassKg`. Include the immutable calculation version `1`.

- [ ] **Step 4: Run tests to verify GREEN**

Run: `flutter test test/core/calculations/body_composition_calculator_test.dart`

Expected: all calculator tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/body_composition/domain lib/core/calculations/body_composition_calculator.dart test/core/calculations/body_composition_calculator_test.dart
git commit -m "Add deterministic body composition calculator"
```

### Task 4: Persist measurements, composition records, and historical trends

**Files:**
- Create: `lib/features/body_composition/data/body_composition_repository.dart`
- Create: `lib/features/body_composition/presentation/body_composition_providers.dart`
- Create: `test/features/body_composition/data/body_composition_repository_test.dart`

**Interfaces:**
- `recordMeasurement(String uid, BodyMeasurement measurement)` writes to `bodyMeasurements` and returns its ID.
- `recordEstimate(String uid, BodyCompositionEstimate estimate)` writes to `bodyCompositionRecords` and returns its ID.
- `listMeasurements(String uid, BodyMetric metric)` and `listEstimates(String uid)` return oldest-first trends.

- [ ] **Step 1: Write failing repository tests**

```dart
test('records and lists weight measurements oldest first', () async {
  await repository.recordMeasurement('u', laterWeight);
  await repository.recordMeasurement('u', earlierWeight);
  expect((await repository.listMeasurements('u', BodyMetric.weight))
      .map((m) => m.value), [80, 81]);
});

test('records an estimate independently from raw measurements', () async {
  await repository.recordEstimate('u', estimate);
  final estimates = await repository.listEstimates('u');
  expect(estimates.single.leanBodyMassKg, estimate.leanBodyMassKg);
});
```

- [ ] **Step 2: Run tests to verify RED**

Run: `flutter test test/features/body_composition/data/body_composition_repository_test.dart`

Expected: FAIL because `BodyCompositionRepository` is undefined.

- [ ] **Step 3: Implement repository and provider**

Use `users/{uid}/bodyMeasurements` and `users/{uid}/bodyCompositionRecords`. Persist `Timestamp.fromDate` for all dates. Store measurement `metric` and query it with `where('metric', isEqualTo: metric.name).orderBy('measuredAt')`; add the matching composite index only if the emulator or deployed Firestore requests it. Do not overwrite raw measurements. Persist the estimate’s source IDs, method, and calculation version separately.

```dart
final bodyCompositionRepositoryProvider = Provider<BodyCompositionRepository>((ref) =>
    BodyCompositionRepository(firestore: ref.watch(firestoreProvider)));
```

- [ ] **Step 4: Run tests to verify GREEN**

Run: `flutter test test/features/body_composition/data/body_composition_repository_test.dart`

Expected: all persistence/trend tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/body_composition/data lib/features/body_composition/presentation/body_composition_providers.dart test/features/body_composition/data/body_composition_repository_test.dart firestore.indexes.json
git commit -m "Add body measurement history repository"
```

### Task 5: Add goals and body-composition screens

**Files:**
- Create: `lib/features/goals/presentation/goals_screen.dart`
- Create: `lib/features/body_composition/presentation/body_composition_screen.dart`
- Create: `test/features/goals/presentation/goals_screen_test.dart`
- Create: `test/features/body_composition/presentation/body_composition_screen_test.dart`

**Interfaces:**
- `GoalsScreen` receives `uid`, `GoalRepository`, and `VoidCallback onChanged`.
- `BodyCompositionScreen` receives `uid`, `UserProfile`, `BodyCompositionRepository`, and `VoidCallback onChanged`.
- Both use current `GlassCard`, `PrimaryButton`, `AppColors`, and existing dark theme.

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('goals screen saves a physique goal', (tester) async {
  await tester.pumpWidget(MaterialApp(home: GoalsScreen(uid: 'u', repository: repository, onChanged: () {})));
  await tester.enterText(find.byKey(const Key('goalNameField')), 'Reduce waist');
  await tester.tap(find.text('Save goal'));
  await tester.pumpAndSettle();
  expect((await repository.listGoals('u')).single.name, 'Reduce waist');
});

testWidgets('body screen records a measurement and displays an estimate disclaimer', (tester) async {
  await tester.pumpWidget(MaterialApp(home: BodyCompositionScreen(
    uid: 'u', profile: maleProfile, repository: repository, onChanged: () {},
  )));
  expect(find.textContaining('estimate'), findsOneWidget);
  await tester.enterText(find.byKey(const Key('weightField')), '80');
  await tester.enterText(find.byKey(const Key('waistField')), '90');
  await tester.enterText(find.byKey(const Key('neckField')), '38');
  await tester.tap(find.text('Save check-in'));
  await tester.pumpAndSettle();
  expect(await repository.listMeasurements('u', BodyMetric.weight), isNotEmpty);
});
```

- [ ] **Step 2: Run tests to verify RED**

Run: `flutter test test/features/goals/presentation/goals_screen_test.dart test/features/body_composition/presentation/body_composition_screen_test.dart`

Expected: FAIL because both screens are missing.

- [ ] **Step 3: Implement minimum screens**

`GoalsScreen` lists goals with category/status chips and provides a form for name, category, optional numeric target/unit, priority, and target date. It displays primary-goal replacement as “Making this primary goal active archives the previous primary goal.”

`BodyCompositionScreen` accepts a dated check-in with weight, waist, neck, optional hip/chest/thigh/upper-arm/forearm, and a measurement method. It writes each supplied raw measurement, then creates an estimate only when height/profile sex and required circumference inputs are present. It shows “Body-fat and lean-body-mass values are estimates, not medical measurements.” It renders a simple historical weight and body-fat list; chart work is deferred to dashboard integration.

- [ ] **Step 4: Run tests to verify GREEN**

Run: `flutter test test/features/goals/presentation/goals_screen_test.dart test/features/body_composition/presentation/body_composition_screen_test.dart`

Expected: all widget tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/goals/presentation/goals_screen.dart lib/features/body_composition/presentation/body_composition_screen.dart test/features/goals/presentation/goals_screen_test.dart test/features/body_composition/presentation/body_composition_screen_test.dart
git commit -m "Add goals and body composition screens"
```

### Task 6: Wire navigation and verify regression safety

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/dashboard/presentation/dashboard_screen.dart`
- Create: `test/features/dashboard/presentation/dashboard_screen_test.dart`
- Modify: `docs/ROADMAP.md`

**Interfaces:**
- Routes: `/goals` and `/body` require an authenticated user and pass existing providers/repositories.
- Dashboard adds navigation cards; it does not calculate goals or measurements.
- Clients create their own raw measurements, deterministic estimate records, and goals through the existing owner-scoped rules. Server-owned rules are reserved for the later coaching, adherence, and readiness records.

- [ ] **Step 1: Write failing navigation test**

```dart
testWidgets('dashboard exposes body and goals navigation', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
  expect(find.text('Body composition'), findsOneWidget);
  expect(find.text('Goals'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify RED**

Run: `flutter test test/features/dashboard/presentation/dashboard_screen_test.dart`

Expected: FAIL because the labels are absent.

- [ ] **Step 3: Implement routes, navigation, and rules review**

Add authenticated `/goals` and `/body` routes using the established `/nutrition` route pattern. Fetch the current profile before constructing `BodyCompositionScreen`; show a clear error screen if no profile is present despite router protection. Add two dashboard cards using `GoRouter.of(context).push`. Keep `bodyMeasurements`, `bodyCompositionRecords`, and `goals` owner-scoped under existing rules. Update the roadmap only if implementation status changed during this task.

- [ ] **Step 4: Run focused verification**

Run: `flutter test test/features/dashboard/presentation/dashboard_screen_test.dart test/features/goals test/features/body_composition && flutter analyze`

Expected: all focused tests pass and analyzer reports no issues.

- [ ] **Step 5: Run full regression verification**

Run: `flutter test && cd functions && npx tsc --noEmit && npm test`

Expected: all Flutter and Cloud Functions tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/router/app_router.dart lib/features/dashboard/presentation/dashboard_screen.dart docs/ROADMAP.md test/features/dashboard/presentation/dashboard_screen_test.dart
git commit -m "Integrate body composition and goals"
```

## Plan Self-review

- Existing profile, workouts, nutrition entries, and custom foods are preserved; the only existing write change is safe root-document merge behavior.
- Every Phase 4 requirement maps to a task: goals (Tasks 1–2/5), measurements and estimates (Tasks 3–5), trends (Task 4), optional hip metric (Task 3/5), UI/navigation (Tasks 5–6), and regression/security review (Task 6).
- Habits, readiness, AI Coach, budget-aware plans, Storage photos, and recipe building are intentionally excluded for later dedicated plans.
- No unresolved placeholders or mismatched interfaces remain in this plan.
