# Phase 2: Workouts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add workout tracking to the fitness tracker: manual strength/general workout logging with a curated + custom exercise library, per-exercise progress charts, and automatic cardio logging via Strava OAuth + webhook sync.

**Architecture:** Two new Flutter features (`lib/features/workouts/`, `lib/features/strava/`) following the `{data,domain,presentation}` shape established in Phase 1's `auth` feature, plus a new Firebase Cloud Functions project (`functions/`, TypeScript) handling Strava's OAuth token exchange and webhook — the Strava client secret lives only there, never in the client app.

**Tech Stack:** Flutter/Dart (existing), `fl_chart` (progress charts), `flutter_web_auth_2` (OAuth redirect capture), `cloud_functions` (calling the Cloud Functions from Flutter), Node.js/TypeScript + `firebase-functions`/`firebase-admin` (Cloud Functions runtime), `jest`/`ts-jest` (Cloud Functions tests), `fake_cloud_firestore`/`mocktail` (existing Flutter test tooling).

## Global Constraints

- Weight units are kg only — no unit toggle. (Spec: Scope Decisions)
- Strength workouts store sets as `{reps, weightKg}` in an `exercises` subcollection; cardio and general workouts store their fields inline on the workout document, no subcollection. (Spec: Data Model)
- Cardio workouts are always `source: 'strava'` and read-only in the app; strength/general workouts are always `source: 'manual'` and fully editable/deletable. (Spec: Scope Decisions, Screens)
- No manual cardio entry exists in this phase — cardio only ever arrives via Strava sync. (Spec: Scope Decisions)
- The Strava client secret must never be embedded in the Flutter app — it is used only inside Cloud Functions. (Spec: Strava Connection Flow)
- Existing Firestore security rules (`match /users/{uid}/{document=**}`) already cover every path this phase adds — no rule changes needed. (Spec: Data Model)
- Visual direction inherited from Phase 1: dark, near-black base with neon-glow accents and glassmorphic cards for everyday screens; use the existing `GlassCard`/`PrimaryButton`/`AppColors`/`AppTypography` design-system pieces, not raw Material widgets or the celebratory `GradientButton`. (Phase 1 spec: UI/Design Direction, carried into this phase's screens)
- Firestore offline persistence (already enabled app-wide) must keep working for manual workout logging. (Phase 1 spec: Error Handling & Offline Behavior)

---

### Task 1: Exercise domain model and ExerciseLibraryRepository

**Files:**
- Create: `lib/features/workouts/domain/exercise.dart`
- Create: `lib/features/workouts/data/exercise_library_repository.dart`
- Test: `test/features/workouts/data/exercise_library_repository_test.dart`

**Interfaces:**
- Produces: `Exercise { id, name, isCustom }`, `ExerciseLibraryRepository { Future<void> seedDefaultsIfEmpty(String uid), Future<List<Exercise>> search(String uid, String query), Future<Exercise> addCustom(String uid, String name), Stream<List<Exercise>> watchAll(String uid) }` — consumed by Task 4's exercise picker.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/workouts/data/exercise_library_repository_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/workouts/data/exercise_library_repository.dart';

void main() {
  group('ExerciseLibraryRepository', () {
    test('seedDefaultsIfEmpty populates the curated list when empty', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = ExerciseLibraryRepository(firestore: firestore);

      await repository.seedDefaultsIfEmpty('uid-1');

      final all = await repository.watchAll('uid-1').first;
      expect(all, isNotEmpty);
      expect(all.every((e) => !e.isCustom), isTrue);
    });

    test('seedDefaultsIfEmpty does nothing if exercises already exist', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = ExerciseLibraryRepository(firestore: firestore);

      await repository.addCustom('uid-1', 'My Weird Exercise');
      await repository.seedDefaultsIfEmpty('uid-1');

      final all = await repository.watchAll('uid-1').first;
      expect(all.length, 1);
      expect(all.first.name, 'My Weird Exercise');
    });

    test('addCustom writes a custom exercise and search finds it by name', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = ExerciseLibraryRepository(firestore: firestore);

      final added = await repository.addCustom('uid-1', 'Nordic Curl');

      expect(added.isCustom, isTrue);
      expect(added.name, 'Nordic Curl');

      final results = await repository.search('uid-1', 'nordic');
      expect(results.map((e) => e.name), contains('Nordic Curl'));
    });

    test('search is case-insensitive and matches substrings', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = ExerciseLibraryRepository(firestore: firestore);
      await repository.seedDefaultsIfEmpty('uid-1');

      final results = await repository.search('uid-1', 'bench');

      expect(results, isNotEmpty);
      expect(results.every((e) => e.name.toLowerCase().contains('bench')), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/workouts/data/exercise_library_repository_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement the Exercise model**

```dart
// lib/features/workouts/domain/exercise.dart
class Exercise {
  const Exercise({required this.id, required this.name, required this.isCustom});

  final String id;
  final String name;
  final bool isCustom;

  Map<String, dynamic> toJson() => {'name': name, 'isCustom': isCustom};

  factory Exercise.fromJson(String id, Map<String, dynamic> json) {
    return Exercise(
      id: id,
      name: json['name'] as String,
      isCustom: json['isCustom'] as bool,
    );
  }
}
```

- [ ] **Step 4: Implement ExerciseLibraryRepository**

```dart
// lib/features/workouts/data/exercise_library_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/exercise.dart';

const _defaultExerciseNames = [
  'Bench Press',
  'Incline Bench Press',
  'Squat',
  'Front Squat',
  'Deadlift',
  'Romanian Deadlift',
  'Overhead Press',
  'Barbell Row',
  'Pull-up',
  'Chin-up',
  'Lat Pulldown',
  'Bicep Curl',
  'Tricep Pushdown',
  'Leg Press',
  'Leg Curl',
  'Calf Raise',
  'Dumbbell Shoulder Press',
  'Dumbbell Lateral Raise',
  'Plank',
  'Hip Thrust',
];

class ExerciseLibraryRepository {
  ExerciseLibraryRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('exerciseLibrary');

  Future<void> seedDefaultsIfEmpty(String uid) async {
    final existing = await _collection(uid).limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    for (final name in _defaultExerciseNames) {
      final doc = _collection(uid).doc();
      batch.set(doc, Exercise(id: doc.id, name: name, isCustom: false).toJson());
    }
    await batch.commit();
  }

  Future<Exercise> addCustom(String uid, String name) async {
    final doc = _collection(uid).doc();
    final exercise = Exercise(id: doc.id, name: name, isCustom: true);
    await doc.set(exercise.toJson());
    return exercise;
  }

  Future<List<Exercise>> search(String uid, String query) async {
    final all = await watchAll(uid).first;
    final normalizedQuery = query.toLowerCase();
    return all.where((e) => e.name.toLowerCase().contains(normalizedQuery)).toList();
  }

  Stream<List<Exercise>> watchAll(String uid) {
    return _collection(uid).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Exercise.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/workouts/data/exercise_library_repository_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/workouts/domain/exercise.dart lib/features/workouts/data/exercise_library_repository.dart test/features/workouts/data/exercise_library_repository_test.dart
git commit -m "Add Exercise model and ExerciseLibraryRepository with curated defaults"
```

---

### Task 2: Workout domain models and WorkoutRepository

**Files:**
- Create: `lib/features/workouts/domain/workout.dart`
- Create: `lib/features/workouts/data/workout_repository.dart`
- Test: `test/features/workouts/data/workout_repository_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1 directly (exercise names are passed in as strings by the caller).
- Produces: `WorkoutType` (strength/cardio/general), `WorkoutSource` (manual/strava), `SetEntry { reps, weightKg }`, `ExerciseEntry { exerciseName, sets: List<SetEntry> }`, `Workout { id, type, source, date, durationMinutes, exercises (for strength), distanceKm/paceMinPerKm/stravaActivityId (for cardio), notes (for general) }`, `WorkoutRepository { Future<String> createStrengthWorkout(...), Future<String> createGeneralWorkout(...), Future<List<Workout>> listWorkouts(String uid), Future<Workout?> getWorkout(String uid, String workoutId), Future<void> updateGeneralWorkout(...), Future<void> deleteWorkout(String uid, String workoutId) }` — consumed by Tasks 5, 6, 7, 8.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/workouts/data/workout_repository_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/workouts/domain/workout.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';

void main() {
  group('WorkoutRepository', () {
    test('createStrengthWorkout writes the workout and its exercises subcollection', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = WorkoutRepository(firestore: firestore);

      final id = await repository.createStrengthWorkout(
        uid: 'uid-1',
        date: DateTime(2026, 8, 1),
        durationMinutes: 45,
        exercises: [
          ExerciseEntry(exerciseName: 'Bench Press', sets: [
            SetEntry(reps: 5, weightKg: 80),
            SetEntry(reps: 5, weightKg: 80),
          ]),
        ],
      );

      final workout = await repository.getWorkout('uid-1', id);

      expect(workout, isNotNull);
      expect(workout!.type, WorkoutType.strength);
      expect(workout.source, WorkoutSource.manual);
      expect(workout.durationMinutes, 45);
      expect(workout.exercises, hasLength(1));
      expect(workout.exercises!.first.exerciseName, 'Bench Press');
      expect(workout.exercises!.first.sets, hasLength(2));
      expect(workout.exercises!.first.sets.first.weightKg, 80);
    });

    test('createGeneralWorkout writes notes inline with no exercises subcollection', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = WorkoutRepository(firestore: firestore);

      final id = await repository.createGeneralWorkout(
        uid: 'uid-1',
        date: DateTime(2026, 8, 2),
        durationMinutes: 30,
        notes: 'Easy mobility session',
      );

      final workout = await repository.getWorkout('uid-1', id);

      expect(workout!.type, WorkoutType.general);
      expect(workout.notes, 'Easy mobility session');
      expect(workout.exercises, isNull);
    });

    test('listWorkouts returns workouts newest-first', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = WorkoutRepository(firestore: firestore);

      await repository.createGeneralWorkout(
        uid: 'uid-1', date: DateTime(2026, 8, 1), durationMinutes: 10, notes: 'first');
      await repository.createGeneralWorkout(
        uid: 'uid-1', date: DateTime(2026, 8, 3), durationMinutes: 10, notes: 'third');
      await repository.createGeneralWorkout(
        uid: 'uid-1', date: DateTime(2026, 8, 2), durationMinutes: 10, notes: 'second');

      final workouts = await repository.listWorkouts('uid-1');

      expect(workouts.map((w) => w.notes), ['third', 'second', 'first']);
    });

    test('updateGeneralWorkout modifies an existing manual workout', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = WorkoutRepository(firestore: firestore);

      final id = await repository.createGeneralWorkout(
        uid: 'uid-1', date: DateTime(2026, 8, 1), durationMinutes: 10, notes: 'original');

      await repository.updateGeneralWorkout(
        uid: 'uid-1', workoutId: id, durationMinutes: 20, notes: 'updated');

      final workout = await repository.getWorkout('uid-1', id);
      expect(workout!.durationMinutes, 20);
      expect(workout.notes, 'updated');
    });

    test('deleteWorkout removes the workout document', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = WorkoutRepository(firestore: firestore);

      final id = await repository.createGeneralWorkout(
        uid: 'uid-1', date: DateTime(2026, 8, 1), durationMinutes: 10, notes: 'to delete');

      await repository.deleteWorkout('uid-1', id);

      final workout = await repository.getWorkout('uid-1', id);
      expect(workout, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/workouts/data/workout_repository_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement the Workout domain models**

```dart
// lib/features/workouts/domain/workout.dart

enum WorkoutType { strength, cardio, general }

enum WorkoutSource { manual, strava }

class SetEntry {
  const SetEntry({required this.reps, required this.weightKg});

  final int reps;
  final double weightKg;

  Map<String, dynamic> toJson() => {'reps': reps, 'weightKg': weightKg};

  factory SetEntry.fromJson(Map<String, dynamic> json) => SetEntry(
        reps: json['reps'] as int,
        weightKg: (json['weightKg'] as num).toDouble(),
      );
}

class ExerciseEntry {
  const ExerciseEntry({required this.exerciseName, required this.sets});

  final String exerciseName;
  final List<SetEntry> sets;

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseEntry.fromJson(Map<String, dynamic> json) => ExerciseEntry(
        exerciseName: json['exerciseName'] as String,
        sets: (json['sets'] as List)
            .map((s) => SetEntry.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class Workout {
  const Workout({
    required this.id,
    required this.type,
    required this.source,
    required this.date,
    required this.durationMinutes,
    this.exercises,
    this.distanceKm,
    this.paceMinPerKm,
    this.stravaActivityId,
    this.notes,
  });

  final String id;
  final WorkoutType type;
  final WorkoutSource source;
  final DateTime date;
  final int durationMinutes;

  /// Populated only for [WorkoutType.strength].
  final List<ExerciseEntry>? exercises;

  /// Populated only for [WorkoutType.cardio].
  final double? distanceKm;
  final double? paceMinPerKm;
  final String? stravaActivityId;

  /// Populated only for [WorkoutType.general].
  final String? notes;
}
```

- [ ] **Step 4: Implement WorkoutRepository**

```dart
// lib/features/workouts/data/workout_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/workout.dart';

class WorkoutRepository {
  WorkoutRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _workouts(String uid) =>
      _firestore.collection('users').doc(uid).collection('workouts');

  Future<String> createStrengthWorkout({
    required String uid,
    required DateTime date,
    required int durationMinutes,
    required List<ExerciseEntry> exercises,
  }) async {
    final doc = _workouts(uid).doc();
    await doc.set({
      'type': WorkoutType.strength.name,
      'source': WorkoutSource.manual.name,
      'date': Timestamp.fromDate(date),
      'durationMinutes': durationMinutes,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    });
    return doc.id;
  }

  Future<String> createGeneralWorkout({
    required String uid,
    required DateTime date,
    required int durationMinutes,
    required String notes,
  }) async {
    final doc = _workouts(uid).doc();
    await doc.set({
      'type': WorkoutType.general.name,
      'source': WorkoutSource.manual.name,
      'date': Timestamp.fromDate(date),
      'durationMinutes': durationMinutes,
      'notes': notes,
    });
    return doc.id;
  }

  Future<List<Workout>> listWorkouts(String uid) async {
    final snapshot = await _workouts(uid).orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) => _fromDoc(doc.id, doc.data())).toList();
  }

  Future<Workout?> getWorkout(String uid, String workoutId) async {
    final doc = await _workouts(uid).doc(workoutId).get();
    if (!doc.exists) return null;
    return _fromDoc(doc.id, doc.data()!);
  }

  Future<void> updateGeneralWorkout({
    required String uid,
    required String workoutId,
    required int durationMinutes,
    required String notes,
  }) async {
    await _workouts(uid).doc(workoutId).update({
      'durationMinutes': durationMinutes,
      'notes': notes,
    });
  }

  Future<void> deleteWorkout(String uid, String workoutId) async {
    await _workouts(uid).doc(workoutId).delete();
  }

  Workout _fromDoc(String id, Map<String, dynamic> json) {
    final exercisesJson = json['exercises'] as List?;
    return Workout(
      id: id,
      type: WorkoutType.values.byName(json['type'] as String),
      source: WorkoutSource.values.byName(json['source'] as String),
      date: (json['date'] as Timestamp).toDate(),
      durationMinutes: json['durationMinutes'] as int,
      exercises: exercisesJson
          ?.map((e) => ExerciseEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      paceMinPerKm: (json['paceMinPerKm'] as num?)?.toDouble(),
      stravaActivityId: json['stravaActivityId'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/workouts/data/workout_repository_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/workouts/domain/workout.dart lib/features/workouts/data/workout_repository.dart test/features/workouts/data/workout_repository_test.dart
git commit -m "Add Workout domain models and WorkoutRepository"
```

---

### Task 3: ProgressChart widget

**Files:**
- Create: `lib/core/widgets/progress_chart.dart`
- Test: `test/core/widgets/progress_chart_test.dart`

**Interfaces:**
- Consumes: `AppColors` (Phase 1).
- Produces: `ProgressChart({required List<ProgressPoint> points})`, `ProgressPoint { date, value }` — consumed by Task 8's exercise progress screen.

- [ ] **Step 1: Add fl_chart dependency**

```bash
flutter pub add fl_chart
```

- [ ] **Step 2: Write the failing test**

```dart
// test/core/widgets/progress_chart_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fitness_tracker/core/widgets/progress_chart.dart';

void main() {
  testWidgets('ProgressChart renders a LineChart with one point per entry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProgressChart(
          points: [
            ProgressPoint(date: DateTime(2026, 1, 1), value: 80),
            ProgressPoint(date: DateTime(2026, 1, 8), value: 82.5),
            ProgressPoint(date: DateTime(2026, 1, 15), value: 85),
          ],
        ),
      ),
    );

    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('ProgressChart shows an empty state with no points', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProgressChart(points: [])),
    );

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('No data yet'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/widgets/progress_chart_test.dart`
Expected: FAIL — `progress_chart.dart` doesn't exist.

- [ ] **Step 4: Implement ProgressChart**

```dart
// lib/core/widgets/progress_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_colors.dart';

class ProgressPoint {
  const ProgressPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

/// A line chart of a single metric (e.g. top-set weight) over time.
class ProgressChart extends StatelessWidget {
  const ProgressChart({super.key, required this.points});

  final List<ProgressPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text('No data yet', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final spots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value),
    ];

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.accentGreen,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accentGreen.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/widgets/progress_chart_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/progress_chart.dart test/core/widgets/progress_chart_test.dart pubspec.yaml pubspec.lock
git commit -m "Add ProgressChart widget using fl_chart"
```

---

### Task 4: Exercise picker widget

**Files:**
- Create: `lib/features/workouts/presentation/exercise_picker.dart`
- Test: `test/features/workouts/presentation/exercise_picker_test.dart`

**Interfaces:**
- Consumes: `Exercise`, `ExerciseLibraryRepository` (Task 1), `GlassCard`/`PrimaryButton` (Phase 1).
- Produces: `ExercisePicker({required String uid, required ExerciseLibraryRepository repository, required ValueChanged<Exercise> onSelected})` — consumed by Task 5's strength-logging screen.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/workouts/presentation/exercise_picker_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/workouts/data/exercise_library_repository.dart';
import 'package:fitness_tracker/features/workouts/domain/exercise.dart';
import 'package:fitness_tracker/features/workouts/presentation/exercise_picker.dart';

void main() {
  testWidgets('ExercisePicker shows search results and calls onSelected on tap', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = ExerciseLibraryRepository(firestore: firestore);
    await repository.seedDefaultsIfEmpty('uid-1');

    Exercise? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: ExercisePicker(
          uid: 'uid-1',
          repository: repository,
          onSelected: (e) => selected = e,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pumpAndSettle();

    expect(find.textContaining('Bench Press'), findsWidgets);

    await tester.tap(find.text('Bench Press').first);
    await tester.pumpAndSettle();

    expect(selected?.name, 'Bench Press');
  });

  testWidgets('ExercisePicker offers to add a custom exercise when search has no match', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = ExerciseLibraryRepository(firestore: firestore);
    await repository.seedDefaultsIfEmpty('uid-1');

    Exercise? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: ExercisePicker(
          uid: 'uid-1',
          repository: repository,
          onSelected: (e) => selected = e,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Nordic Curl');
    await tester.pumpAndSettle();

    expect(find.textContaining('Add "Nordic Curl"'), findsOneWidget);

    await tester.tap(find.textContaining('Add "Nordic Curl"'));
    await tester.pumpAndSettle();

    expect(selected?.name, 'Nordic Curl');
    expect(selected?.isCustom, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/workouts/presentation/exercise_picker_test.dart`
Expected: FAIL — `exercise_picker.dart` doesn't exist.

- [ ] **Step 3: Implement ExercisePicker**

```dart
// lib/features/workouts/presentation/exercise_picker.dart
import 'package:flutter/material.dart';
import '../data/exercise_library_repository.dart';
import '../domain/exercise.dart';

class ExercisePicker extends StatefulWidget {
  const ExercisePicker({
    super.key,
    required this.uid,
    required this.repository,
    required this.onSelected,
  });

  final String uid;
  final ExerciseLibraryRepository repository;
  final ValueChanged<Exercise> onSelected;

  @override
  State<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<ExercisePicker> {
  final _controller = TextEditingController();
  List<Exercise> _results = [];

  Future<void> _search(String query) async {
    final results = await widget.repository.search(widget.uid, query);
    if (!mounted) return;
    setState(() => _results = results);
  }

  Future<void> _addCustom(String name) async {
    final exercise = await widget.repository.addCustom(widget.uid, name);
    widget.onSelected(exercise);
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final hasExactMatch =
        _results.any((e) => e.name.toLowerCase() == query.toLowerCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(labelText: 'Search exercises'),
          onChanged: _search,
        ),
        Expanded(
          child: ListView(
            children: [
              for (final exercise in _results)
                ListTile(
                  title: Text(exercise.name),
                  onTap: () => widget.onSelected(exercise),
                ),
              if (query.isNotEmpty && !hasExactMatch)
                ListTile(
                  title: Text('Add "$query"'),
                  onTap: () => _addCustom(query),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/workouts/presentation/exercise_picker_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/workouts/presentation/exercise_picker.dart test/features/workouts/presentation/exercise_picker_test.dart
git commit -m "Add ExercisePicker widget with search and add-custom flow"
```

---

### Task 5: Log Strength workout screen

**Files:**
- Create: `lib/features/workouts/presentation/log_strength_screen.dart`
- Test: `test/features/workouts/presentation/log_strength_screen_test.dart`

**Interfaces:**
- Consumes: `ExercisePicker` (Task 4), `WorkoutRepository`, `ExerciseEntry`, `SetEntry` (Task 2), `GlassCard`/`PrimaryButton` (Phase 1).
- Produces: `LogStrengthScreen({required String uid, required WorkoutRepository workoutRepository, required ExerciseLibraryRepository exerciseRepository, required VoidCallback onSaved})` — consumed by Task 7's workouts home screen (navigation target).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/workouts/presentation/log_strength_screen_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/widgets/primary_button.dart';
import 'package:fitness_tracker/features/workouts/data/exercise_library_repository.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';
import 'package:fitness_tracker/features/workouts/presentation/log_strength_screen.dart';

void main() {
  testWidgets('Save is disabled until an exercise is added, then saves the workout', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final workoutRepository = WorkoutRepository(firestore: firestore);
    final exerciseRepository = ExerciseLibraryRepository(firestore: firestore);
    await exerciseRepository.seedDefaultsIfEmpty('uid-1');

    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: LogStrengthScreen(
          uid: 'uid-1',
          workoutRepository: workoutRepository,
          exerciseRepository: exerciseRepository,
          onSaved: () => saved = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButtonBefore = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(saveButtonBefore.onPressed, isNull);

    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press').first);
    await tester.pumpAndSettle();

    final saveButtonAfter = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(saveButtonAfter.onPressed, isNotNull);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    final workouts = await workoutRepository.listWorkouts('uid-1');
    expect(workouts, hasLength(1));
    expect(workouts.first.exercises!.first.exerciseName, 'Bench Press');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/workouts/presentation/log_strength_screen_test.dart`
Expected: FAIL — `log_strength_screen.dart` doesn't exist.

- [ ] **Step 3: Implement LogStrengthScreen**

```dart
// lib/features/workouts/presentation/log_strength_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/exercise_library_repository.dart';
import '../data/workout_repository.dart';
import '../domain/exercise.dart';
import '../domain/workout.dart';
import 'exercise_picker.dart';

class LogStrengthScreen extends StatefulWidget {
  const LogStrengthScreen({
    super.key,
    required this.uid,
    required this.workoutRepository,
    required this.exerciseRepository,
    required this.onSaved,
  });

  final String uid;
  final WorkoutRepository workoutRepository;
  final ExerciseLibraryRepository exerciseRepository;
  final VoidCallback onSaved;

  @override
  State<LogStrengthScreen> createState() => _LogStrengthScreenState();
}

class _LogStrengthScreenState extends State<LogStrengthScreen> {
  final _durationController = TextEditingController(text: '45');
  final List<_ExerciseDraft> _exercises = [];
  bool _saving = false;

  void _addExercise(Exercise exercise) {
    Navigator.of(context).pop();
    setState(() => _exercises.add(_ExerciseDraft(exerciseName: exercise.name)));
  }

  void _openExercisePicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Add exercise')),
          body: ExercisePicker(
            uid: widget.uid,
            repository: widget.exerciseRepository,
            onSelected: _addExercise,
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final exercises = [
      for (final draft in _exercises)
        ExerciseEntry(
          exerciseName: draft.exerciseName,
          sets: draft.sets
              .map((s) => SetEntry(reps: s.reps, weightKg: s.weightKg))
              .toList(),
        ),
    ];

    await widget.workoutRepository.createStrengthWorkout(
      uid: widget.uid,
      date: DateTime.now(),
      durationMinutes: int.parse(_durationController.text),
      exercises: exercises,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log strength workout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duration (minutes)'),
            ),
            const SizedBox(height: 16),
            for (final draft in _exercises)
              GlassCard(
                child: _ExerciseDraftEditor(
                  draft: draft,
                  onChanged: () => setState(() {}),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _openExercisePicker,
              child: const Text('Add exercise'),
            ),
            const SizedBox(height: 24),
            _saving
                ? const Center(child: CircularProgressIndicator())
                : PrimaryButton(
                    label: 'Save workout',
                    onPressed: _exercises.isEmpty ? null : _save,
                  ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseDraft {
  _ExerciseDraft({required this.exerciseName});

  final String exerciseName;
  final List<_SetDraft> sets = [_SetDraft()];
}

class _SetDraft {
  int reps = 5;
  double weightKg = 20;
}

class _ExerciseDraftEditor extends StatelessWidget {
  const _ExerciseDraftEditor({required this.draft, required this.onChanged});

  final _ExerciseDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(draft.exerciseName, style: Theme.of(context).textTheme.headlineMedium),
        for (final set in draft.sets)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: set.reps.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps'),
                  onChanged: (v) {
                    set.reps = int.tryParse(v) ?? set.reps;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: set.weightKg.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  onChanged: (v) {
                    set.weightKg = double.tryParse(v) ?? set.weightKg;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
        TextButton(
          onPressed: () {
            draft.sets.add(_SetDraft());
            onChanged();
          },
          child: const Text('Add set'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/workouts/presentation/log_strength_screen_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/features/workouts/presentation/log_strength_screen.dart test/features/workouts/presentation/log_strength_screen_test.dart
git commit -m "Add Log Strength workout screen"
```

---

### Task 6: Log General workout screen

**Files:**
- Create: `lib/features/workouts/presentation/log_general_screen.dart`

**Interfaces:**
- Consumes: `WorkoutRepository` (Task 2), `GlassCard`/`PrimaryButton` (Phase 1).
- Produces: `LogGeneralScreen({required String uid, required WorkoutRepository workoutRepository, required VoidCallback onSaved})` — consumed by Task 7. No automated test, same rationale as Task 5.

- [ ] **Step 1: Implement LogGeneralScreen**

```dart
// lib/features/workouts/presentation/log_general_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/workout_repository.dart';

class LogGeneralScreen extends StatefulWidget {
  const LogGeneralScreen({
    super.key,
    required this.uid,
    required this.workoutRepository,
    required this.onSaved,
  });

  final String uid;
  final WorkoutRepository workoutRepository;
  final VoidCallback onSaved;

  @override
  State<LogGeneralScreen> createState() => _LogGeneralScreenState();
}

class _LogGeneralScreenState extends State<LogGeneralScreen> {
  final _durationController = TextEditingController(text: '30');
  final _notesController = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);

    await widget.workoutRepository.createGeneralWorkout(
      uid: widget.uid,
      date: DateTime.now(),
      durationMinutes: int.parse(_durationController.text),
      notes: _notesController.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log workout')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 24),
                _saving
                    ? const Center(child: CircularProgressIndicator())
                    : PrimaryButton(label: 'Save workout', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/features/workouts/presentation/log_general_screen.dart
git commit -m "Add Log General workout screen"
```

---

### Task 7: Workouts home/history screen

**Files:**
- Create: `lib/features/workouts/presentation/workouts_home_screen.dart`
- Test: `test/features/workouts/presentation/workouts_home_screen_test.dart`

**Interfaces:**
- Consumes: `WorkoutRepository`, `Workout`, `WorkoutType` (Task 2), `LogStrengthScreen` (Task 5), `LogGeneralScreen` (Task 6), `GlassCard` (Phase 1).
- Produces: `WorkoutsHomeScreen({required String uid, required WorkoutRepository workoutRepository, required ExerciseLibraryRepository exerciseRepository})` — the entry point this feature will be reached from (wired into the app's navigation in Task 11, once Strava's connect banner exists; until then this screen is reachable only via direct construction in manual testing).

Note: the Strava "Connect Strava" banner described in the spec is added in Task 11, once
`StravaConnection`/the connect flow exist — this task builds the screen with a placeholder
`Container` where that banner will go, marked with a comment, so Task 11 has an obvious
insertion point. Task 11 also adds a required `stravaRepository` constructor parameter to this
screen — when that happens, the test below must be updated to pass one (Task 11 has an explicit
step for this).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/workouts/presentation/workouts_home_screen_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/workouts/data/exercise_library_repository.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';
import 'package:fitness_tracker/features/workouts/presentation/workouts_home_screen.dart';

void main() {
  testWidgets('lists previously logged workouts', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final workoutRepository = WorkoutRepository(firestore: firestore);
    final exerciseRepository = ExerciseLibraryRepository(firestore: firestore);

    await workoutRepository.createGeneralWorkout(
      uid: 'uid-1',
      date: DateTime(2026, 8, 1),
      durationMinutes: 30,
      notes: 'Morning mobility',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutsHomeScreen(
          uid: 'uid-1',
          workoutRepository: workoutRepository,
          exerciseRepository: exerciseRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Morning mobility'), findsOneWidget);
  });

  testWidgets('shows an empty state with no workouts', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final workoutRepository = WorkoutRepository(firestore: firestore);
    final exerciseRepository = ExerciseLibraryRepository(firestore: firestore);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutsHomeScreen(
          uid: 'uid-1',
          workoutRepository: workoutRepository,
          exerciseRepository: exerciseRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No workouts logged yet.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/workouts/presentation/workouts_home_screen_test.dart`
Expected: FAIL — `workouts_home_screen.dart` doesn't exist.

- [ ] **Step 3: Implement WorkoutsHomeScreen**

```dart
// lib/features/workouts/presentation/workouts_home_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/exercise_library_repository.dart';
import '../data/workout_repository.dart';
import '../domain/workout.dart';
import 'log_general_screen.dart';
import 'log_strength_screen.dart';

class WorkoutsHomeScreen extends StatefulWidget {
  const WorkoutsHomeScreen({
    super.key,
    required this.uid,
    required this.workoutRepository,
    required this.exerciseRepository,
  });

  final String uid;
  final WorkoutRepository workoutRepository;
  final ExerciseLibraryRepository exerciseRepository;

  @override
  State<WorkoutsHomeScreen> createState() => _WorkoutsHomeScreenState();
}

class _WorkoutsHomeScreenState extends State<WorkoutsHomeScreen> {
  late Future<List<Workout>> _workoutsFuture;

  @override
  void initState() {
    super.initState();
    widget.exerciseRepository.seedDefaultsIfEmpty(widget.uid);
    _refresh();
  }

  void _refresh() {
    setState(() {
      _workoutsFuture = widget.workoutRepository.listWorkouts(widget.uid);
    });
  }

  Future<void> _openLogStrength() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogStrengthScreen(
          uid: widget.uid,
          workoutRepository: widget.workoutRepository,
          exerciseRepository: widget.exerciseRepository,
          onSaved: () {
            Navigator.of(context).pop();
            _refresh();
          },
        ),
      ),
    );
  }

  Future<void> _openLogGeneral() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogGeneralScreen(
          uid: widget.uid,
          workoutRepository: widget.workoutRepository,
          onSaved: () {
            Navigator.of(context).pop();
            _refresh();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      floatingActionButton: PopupMenuButton<String>(
        icon: const Icon(Icons.add),
        onSelected: (value) {
          if (value == 'strength') _openLogStrength();
          if (value == 'general') _openLogGeneral();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'strength', child: Text('Log strength workout')),
          PopupMenuItem(value: 'general', child: Text('Log general workout')),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Strava "Connect Strava" banner is inserted here by Task 11.
              const SizedBox.shrink(),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Workout>>(
                  future: _workoutsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final workouts = snapshot.data!;
                    if (workouts.isEmpty) {
                      return const Center(child: Text('No workouts logged yet.'));
                    }
                    return ListView.separated(
                      itemCount: workouts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final workout = workouts[index];
                        return GlassCard(
                          child: ListTile(
                            title: Text(_titleFor(workout)),
                            subtitle: Text(
                              '${workout.date.year}-${workout.date.month.toString().padLeft(2, '0')}-${workout.date.day.toString().padLeft(2, '0')} · ${workout.durationMinutes} min',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor(Workout workout) {
    switch (workout.type) {
      case WorkoutType.strength:
        return 'Strength · ${workout.exercises?.length ?? 0} exercises';
      case WorkoutType.cardio:
        return 'Cardio (Strava)';
      case WorkoutType.general:
        return workout.notes?.isNotEmpty == true ? workout.notes! : 'Workout';
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/workouts/presentation/workouts_home_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/features/workouts/presentation/workouts_home_screen.dart test/features/workouts/presentation/workouts_home_screen_test.dart
git commit -m "Add Workouts home/history screen"
```

---

### Task 8: Workout detail screen and exercise progress screen

**Files:**
- Create: `lib/features/workouts/presentation/workout_detail_screen.dart`
- Create: `lib/features/workouts/presentation/exercise_progress_screen.dart`

**Interfaces:**
- Consumes: `Workout`, `WorkoutRepository`, `WorkoutSource` (Task 2), `ProgressChart`, `ProgressPoint` (Task 3), `GlassCard`/`PrimaryButton` (Phase 1).
- Produces: `WorkoutDetailScreen({required String uid, required Workout workout, required WorkoutRepository workoutRepository, required VoidCallback onChanged})`, `ExerciseProgressScreen({required String uid, required String exerciseName, required WorkoutRepository workoutRepository})` — both are navigation leaves reached from `WorkoutsHomeScreen` (wiring the actual navigation taps is part of this task, extending Task 7's list). No automated test for the screens themselves, same rationale as Task 5; the progress-computation logic is tested below.

- [ ] **Step 1: Write the failing test for the progress-point extraction logic**

```dart
// test/features/workouts/presentation/exercise_progress_screen_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/workouts/domain/workout.dart';
import 'package:fitness_tracker/features/workouts/presentation/exercise_progress_screen.dart';

void main() {
  test('topSetProgressPoints extracts the heaviest set per session for the named exercise', () {
    final workouts = [
      Workout(
        id: 'w1',
        type: WorkoutType.strength,
        source: WorkoutSource.manual,
        date: DateTime(2026, 1, 1),
        durationMinutes: 45,
        exercises: [
          ExerciseEntry(exerciseName: 'Bench Press', sets: [
            SetEntry(reps: 5, weightKg: 70),
            SetEntry(reps: 5, weightKg: 75),
          ]),
        ],
      ),
      Workout(
        id: 'w2',
        type: WorkoutType.strength,
        source: WorkoutSource.manual,
        date: DateTime(2026, 1, 8),
        durationMinutes: 45,
        exercises: [
          ExerciseEntry(exerciseName: 'Squat', sets: [SetEntry(reps: 5, weightKg: 100)]),
          ExerciseEntry(exerciseName: 'Bench Press', sets: [SetEntry(reps: 3, weightKg: 80)]),
        ],
      ),
      Workout(
        id: 'w3',
        type: WorkoutType.general,
        source: WorkoutSource.manual,
        date: DateTime(2026, 1, 10),
        durationMinutes: 20,
        notes: 'not a strength workout',
      ),
    ];

    final points = topSetProgressPoints(workouts, 'Bench Press');

    expect(points, hasLength(2));
    expect(points[0].date, DateTime(2026, 1, 1));
    expect(points[0].value, 75);
    expect(points[1].date, DateTime(2026, 1, 8));
    expect(points[1].value, 80);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/workouts/presentation/exercise_progress_screen_test.dart`
Expected: FAIL — `exercise_progress_screen.dart` doesn't exist.

- [ ] **Step 3: Implement ExerciseProgressScreen with the progress-extraction function**

```dart
// lib/features/workouts/presentation/exercise_progress_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/progress_chart.dart';
import '../data/workout_repository.dart';
import '../domain/workout.dart';

/// Extracts one [ProgressPoint] per workout session that includes [exerciseName],
/// using the heaviest set logged for that exercise in that session, sorted
/// oldest-first (chart reading order).
List<ProgressPoint> topSetProgressPoints(List<Workout> workouts, String exerciseName) {
  final sessions = workouts.where((w) => w.type == WorkoutType.strength).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  final points = <ProgressPoint>[];
  for (final workout in sessions) {
    final entry = workout.exercises?.where((e) => e.exerciseName == exerciseName);
    if (entry == null || entry.isEmpty) continue;

    final topWeight = entry.first.sets.map((s) => s.weightKg).reduce((a, b) => a > b ? a : b);
    points.add(ProgressPoint(date: workout.date, value: topWeight));
  }
  return points;
}

class ExerciseProgressScreen extends StatelessWidget {
  const ExerciseProgressScreen({
    super.key,
    required this.uid,
    required this.exerciseName,
    required this.workoutRepository,
  });

  final String uid;
  final String exerciseName;
  final WorkoutRepository workoutRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exerciseName)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<List<Workout>>(
            future: workoutRepository.listWorkouts(uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final points = topSetProgressPoints(snapshot.data!, exerciseName);
              return GlassCard(
                child: SizedBox(height: 240, child: ProgressChart(points: points)),
              );
            },
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/workouts/presentation/exercise_progress_screen_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Implement WorkoutDetailScreen**

```dart
// lib/features/workouts/presentation/workout_detail_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/workout_repository.dart';
import '../domain/workout.dart';

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({
    super.key,
    required this.uid,
    required this.workout,
    required this.workoutRepository,
    required this.onChanged,
  });

  final String uid;
  final Workout workout;
  final WorkoutRepository workoutRepository;
  final VoidCallback onChanged;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late final _durationController =
      TextEditingController(text: widget.workout.durationMinutes.toString());
  late final _notesController = TextEditingController(text: widget.workout.notes ?? '');

  bool get _isEditable => widget.workout.source == WorkoutSource.manual;

  Future<void> _save() async {
    if (widget.workout.type == WorkoutType.general) {
      await widget.workoutRepository.updateGeneralWorkout(
        uid: widget.uid,
        workoutId: widget.workout.id,
        durationMinutes: int.parse(_durationController.text),
        notes: _notesController.text,
      );
    }
    if (!mounted) return;
    widget.onChanged();
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await widget.workoutRepository.deleteWorkout(widget.uid, widget.workout.id);
    if (!mounted) return;
    widget.onChanged();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout detail'),
        actions: [
          if (_isEditable)
            IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${workout.type.name} · ${workout.source.name}'),
                const SizedBox(height: 12),
                TextField(
                  controller: _durationController,
                  enabled: _isEditable,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                ),
                if (workout.type == WorkoutType.general) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    enabled: _isEditable,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
                if (workout.type == WorkoutType.strength)
                  for (final exercise in workout.exercises ?? [])
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${exercise.exerciseName}: ${exercise.sets.map((s) => '${s.reps}x${s.weightKg}kg').join(', ')}',
                      ),
                    ),
                if (workout.type == WorkoutType.cardio) ...[
                  const SizedBox(height: 12),
                  Text('Distance: ${workout.distanceKm ?? '-'} km'),
                  Text('Pace: ${workout.paceMinPerKm ?? '-'} min/km'),
                ],
                if (_isEditable) ...[
                  const SizedBox(height: 24),
                  PrimaryButton(label: 'Save changes', onPressed: _save),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Wire navigation from WorkoutsHomeScreen's list to WorkoutDetailScreen**

Modify `lib/features/workouts/presentation/workouts_home_screen.dart`: change the `GlassCard(child: ListTile(...))` in the `ListView.separated` `itemBuilder` to wrap the `ListTile` with an `onTap` that pushes `WorkoutDetailScreen`:

```dart
                        return GlassCard(
                          child: ListTile(
                            title: Text(_titleFor(workout)),
                            subtitle: Text(
                              '${workout.date.year}-${workout.date.month.toString().padLeft(2, '0')}-${workout.date.day.toString().padLeft(2, '0')} · ${workout.durationMinutes} min',
                            ),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WorkoutDetailScreen(
                                    uid: widget.uid,
                                    workout: workout,
                                    workoutRepository: widget.workoutRepository,
                                    onChanged: _refresh,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
```

Add the import at the top of `workouts_home_screen.dart`:
```dart
import 'workout_detail_screen.dart';
```

- [ ] **Step 7: Run the full test suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests pass, "No issues found!"

- [ ] **Step 8: Commit**

```bash
git add lib/features/workouts/presentation/workout_detail_screen.dart lib/features/workouts/presentation/exercise_progress_screen.dart lib/features/workouts/presentation/workouts_home_screen.dart test/features/workouts/presentation/exercise_progress_screen_test.dart
git commit -m "Add workout detail and exercise progress screens; wire history list navigation"
```

---

### Task 9: Cloud Functions project scaffold and exchangeStravaToken function

**Files:**
- Create: `functions/package.json`
- Create: `functions/tsconfig.json`
- Create: `functions/jest.config.js`
- Create: `functions/src/stravaClient.ts`
- Create: `functions/src/exchangeStravaToken.ts`
- Create: `functions/src/index.ts`
- Test: `functions/src/exchangeStravaToken.test.ts`

**Interfaces:**
- Produces: `exchangeStravaToken` (a Firebase `onCall` function taking `{ code: string }`, returning `{ connected: true }`), `stravaClient.exchangeCode(code: string): Promise<StravaTokenResponse>` — the webhook function in Task 10 shares `stravaClient.ts`'s token-refresh helper.

- [ ] **Step 1: Scaffold the Functions project**

```bash
firebase init functions
```

When prompted: choose TypeScript, do NOT overwrite anything if prompted (this is a fresh
`functions/` directory), decline ESLint if you want to keep this minimal (either choice is fine),
and skip installing dependencies immediately if prompted — Step 2 installs what's needed
explicitly.

Confirm `functions/package.json`, `functions/tsconfig.json`, and `functions/src/index.ts` now
exist. If `firebase init functions` produces different file contents than assumed below (CLI
versions vary), treat this step's output as the starting point and adapt Steps 3+ to fit rather
than fighting the generated scaffold.

- [ ] **Step 2: Add dependencies and test tooling**

```bash
cd functions
npm install firebase-admin firebase-functions
npm install --save-dev jest ts-jest @types/jest firebase-functions-test
cd ..
```

- [ ] **Step 3: Configure Jest**

```javascript
// functions/jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
};
```

Add a `test` script to `functions/package.json`'s `"scripts"` section:
```json
"test": "jest"
```

- [ ] **Step 4: Write the failing test for exchangeStravaToken**

```typescript
// functions/src/exchangeStravaToken.test.ts
import * as admin from 'firebase-admin';
import { exchangeCodeHandler } from './exchangeStravaToken';
import * as stravaClient from './stravaClient';

jest.mock('./stravaClient');
jest.mock('firebase-admin', () => {
  const firestoreMock = {
    collection: jest.fn().mockReturnThis(),
    doc: jest.fn().mockReturnThis(),
    set: jest.fn().mockResolvedValue(undefined),
  };
  return {
    firestore: () => firestoreMock,
    apps: [],
    initializeApp: jest.fn(),
  };
});

describe('exchangeCodeHandler', () => {
  it('exchanges the code, stores the refresh token, and returns connected: true', async () => {
    (stravaClient.exchangeCode as jest.Mock).mockResolvedValue({
      athlete: { id: 12345 },
      refresh_token: 'refresh-abc',
      access_token: 'access-abc',
      expires_at: 1893456000,
    });

    const result = await exchangeCodeHandler('uid-1', 'auth-code-xyz');

    expect(stravaClient.exchangeCode).toHaveBeenCalledWith('auth-code-xyz');
    expect(result).toEqual({ connected: true });

    const firestoreMock = admin.firestore() as unknown as {
      collection: jest.Mock;
      doc: jest.Mock;
      set: jest.Mock;
    };
    expect(firestoreMock.collection).toHaveBeenCalledWith('users');
    expect(firestoreMock.doc).toHaveBeenCalledWith('uid-1');
    expect(firestoreMock.set).toHaveBeenCalledWith(
      expect.objectContaining({
        athleteId: 12345,
        refreshToken: 'refresh-abc',
      }),
      expect.anything(),
    );
  });

  it('throws if the Strava token exchange fails', async () => {
    (stravaClient.exchangeCode as jest.Mock).mockRejectedValue(new Error('bad code'));

    await expect(exchangeCodeHandler('uid-1', 'bad-code')).rejects.toThrow('bad code');
  });
});
```

- [ ] **Step 5: Run test to verify it fails**

Run: `cd functions && npm test -- exchangeStravaToken.test.ts`
Expected: FAIL — `exchangeStravaToken.ts`/`stravaClient.ts` don't exist.

- [ ] **Step 6: Implement stravaClient.ts**

```typescript
// functions/src/stravaClient.ts
const STRAVA_CLIENT_ID = process.env.STRAVA_CLIENT_ID ?? '';
const STRAVA_CLIENT_SECRET = process.env.STRAVA_CLIENT_SECRET ?? '';

export interface StravaTokenResponse {
  athlete: { id: number };
  access_token: string;
  refresh_token: string;
  expires_at: number;
}

export async function exchangeCode(code: string): Promise<StravaTokenResponse> {
  const response = await fetch('https://www.strava.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: STRAVA_CLIENT_ID,
      client_secret: STRAVA_CLIENT_SECRET,
      code,
      grant_type: 'authorization_code',
    }),
  });

  if (!response.ok) {
    throw new Error(`Strava token exchange failed: ${response.status}`);
  }

  return (await response.json()) as StravaTokenResponse;
}

export async function refreshAccessToken(refreshToken: string): Promise<StravaTokenResponse> {
  const response = await fetch('https://www.strava.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: STRAVA_CLIENT_ID,
      client_secret: STRAVA_CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }),
  });

  if (!response.ok) {
    throw new Error(`Strava token refresh failed: ${response.status}`);
  }

  return (await response.json()) as StravaTokenResponse;
}
```

- [ ] **Step 7: Implement exchangeStravaToken.ts**

```typescript
// functions/src/exchangeStravaToken.ts
import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as stravaClient from './stravaClient';

export async function exchangeCodeHandler(uid: string, code: string) {
  const tokenResponse = await stravaClient.exchangeCode(code);

  await admin
    .firestore()
    .collection('users')
    .doc(uid)
    .collection('meta')
    .doc('stravaConnection')
    .set({
      athleteId: tokenResponse.athlete.id,
      refreshToken: tokenResponse.refresh_token,
      connectedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  return { connected: true };
}

export const exchangeStravaToken = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }

  const code = request.data?.code as string | undefined;
  if (!code) {
    throw new HttpsError('invalid-argument', 'Missing authorization code.');
  }

  return exchangeCodeHandler(uid, code);
});
```

Note: this stores the Strava connection at `users/{uid}/meta/stravaConnection` (a `meta`
subcollection with a fixed-id document) rather than a top-level `stravaConnection` field
directly on the user document, to avoid colliding with the existing `UserProfile` fields already
written there by Phase 1's `UserProfileRepository`. This still matches the spec's data model
intent (a single doc holding `athleteId`/`refreshToken`/`connectedAt`, scoped under `users/{uid}`
and covered by the existing security rule) — just nested one level for collision-safety. Task 11
(client-side `StravaConnectionRepository`) reads from this same path.

- [ ] **Step 8: Wire the function into index.ts**

```typescript
// functions/src/index.ts
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export { exchangeStravaToken } from './exchangeStravaToken';
```

- [ ] **Step 9: Run test to verify it passes**

Run: `cd functions && npm test -- exchangeStravaToken.test.ts`
Expected: PASS (2 tests).

- [ ] **Step 10: Run TypeScript compilation to catch type errors**

Run: `cd functions && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 11: Commit**

```bash
git add functions/
git commit -m "Scaffold Cloud Functions project and add exchangeStravaToken function"
```

---

### Task 10: stravaWebhook function and Firebase Hosting redirect page

**Files:**
- Create: `functions/src/stravaWebhook.ts`
- Test: `functions/src/stravaWebhook.test.ts`
- Modify: `functions/src/index.ts`
- Modify: `functions/src/stravaClient.ts`
- Create: `public/strava-callback.html`
- Modify: `firebase.json`

**Interfaces:**
- Consumes: `stravaClient.refreshAccessToken` (Task 9).
- Produces: `stravaWebhook` (an `onRequest` HTTPS function handling both Strava's webhook subscription-validation `GET` handshake and `POST` activity events), `stravaClient.getActivity(accessToken, activityId)` — no other task in this plan consumes these directly, but they are the last piece needed for cardio workouts to ever appear in Firestore.

- [ ] **Step 1: Write the failing test for the webhook's event-handling logic**

```typescript
// functions/src/stravaWebhook.test.ts
import * as admin from 'firebase-admin';
import { handleActivityEvent } from './stravaWebhook';
import * as stravaClient from './stravaClient';

jest.mock('./stravaClient');
jest.mock('firebase-admin', () => {
  const workoutDocRef = { set: jest.fn().mockResolvedValue(undefined) };
  const workoutsCollection = { doc: jest.fn().mockReturnValue(workoutDocRef) };
  const connectionDocRef = {
    get: jest.fn().mockResolvedValue({
      exists: true,
      data: () => ({ refreshToken: 'refresh-abc' }),
    }),
  };
  const metaCollection = { doc: jest.fn().mockReturnValue(connectionDocRef) };
  const userDocRef = {
    collection: jest.fn((name: string) =>
      name === 'workouts' ? workoutsCollection : metaCollection,
    ),
  };
  const usersCollection = { doc: jest.fn().mockReturnValue(userDocRef) };

  const queryMock = {
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    get: jest.fn().mockResolvedValue({
      empty: false,
      docs: [{ ref: userDocRef, id: 'uid-1' }],
    }),
  };

  const firestoreMock = {
    collectionGroup: jest.fn().mockReturnValue(queryMock),
    collection: jest.fn().mockReturnValue(usersCollection),
  };

  return {
    firestore: Object.assign(() => firestoreMock, {
      FieldValue: { serverTimestamp: jest.fn() },
    }),
    apps: [],
    initializeApp: jest.fn(),
  };
});

describe('handleActivityEvent', () => {
  it('resolves the user by athlete id, refreshes the token, fetches the activity, and writes a cardio workout', async () => {
    (stravaClient.refreshAccessToken as jest.Mock).mockResolvedValue({
      access_token: 'fresh-access-token',
    });
    (stravaClient.getActivity as jest.Mock).mockResolvedValue({
      id: 999,
      type: 'Run',
      distance: 5000,
      moving_time: 1500,
      start_date: '2026-08-10T06:00:00Z',
    });

    await handleActivityEvent({ object_type: 'activity', owner_id: 12345, object_id: 999 });

    expect(stravaClient.refreshAccessToken).toHaveBeenCalledWith('refresh-abc');
    expect(stravaClient.getActivity).toHaveBeenCalledWith('fresh-access-token', 999);
  });

  it('drops the event silently if no user matches the athlete id', async () => {
    const firestoreModule = jest.requireMock('firebase-admin').firestore();
    firestoreModule.collectionGroup().get.mockResolvedValueOnce({ empty: true, docs: [] });

    await expect(
      handleActivityEvent({ object_type: 'activity', owner_id: 99999999, object_id: 1 }),
    ).resolves.toBeUndefined();

    expect(stravaClient.getActivity).not.toHaveBeenCalled();
  });

  it('ignores non-activity event types', async () => {
    await handleActivityEvent({ object_type: 'athlete', owner_id: 12345, object_id: 1 });

    expect(stravaClient.refreshAccessToken).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd functions && npm test -- stravaWebhook.test.ts`
Expected: FAIL — `stravaWebhook.ts` doesn't exist, and `stravaClient.getActivity` doesn't exist yet.

- [ ] **Step 3: Add getActivity to stravaClient.ts**

Add to `functions/src/stravaClient.ts` (do not remove existing `exchangeCode`/`refreshAccessToken`):

```typescript
export interface StravaActivity {
  id: number;
  type: string;
  distance: number; // meters
  moving_time: number; // seconds
  start_date: string; // ISO 8601
}

export async function getActivity(accessToken: string, activityId: number): Promise<StravaActivity> {
  const response = await fetch(`https://www.strava.com/api/v3/activities/${activityId}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok) {
    throw new Error(`Strava getActivity failed: ${response.status}`);
  }

  return (await response.json()) as StravaActivity;
}
```

- [ ] **Step 4: Implement stravaWebhook.ts**

```typescript
// functions/src/stravaWebhook.ts
import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import * as stravaClient from './stravaClient';

const STRAVA_VERIFY_TOKEN = process.env.STRAVA_WEBHOOK_VERIFY_TOKEN ?? '';

interface StravaWebhookEvent {
  object_type: string;
  owner_id: number;
  object_id: number;
}

/**
 * Resolves which Firebase user owns the given Strava athlete id, refreshes
 * their access token, fetches the full activity, and writes it as a cardio
 * workout. Silently drops events that don't map to a known user or that
 * aren't activity-creation events — Strava does not usefully retry on our
 * behalf for either case, so throwing would only cause noisy redelivery.
 */
export async function handleActivityEvent(event: StravaWebhookEvent): Promise<void> {
  if (event.object_type !== 'activity') return;

  const firestore = admin.firestore();

  const matches = await firestore
    .collectionGroup('meta')
    .where('athleteId', '==', event.owner_id)
    .limit(1)
    .get();

  if (matches.empty) return;

  const userDocRef = matches.docs[0].ref.parent.parent!;
  const connectionSnapshot = await userDocRef.collection('meta').doc('stravaConnection').get();
  const refreshToken = connectionSnapshot.data()?.refreshToken as string;

  const { access_token: accessToken } = await stravaClient.refreshAccessToken(refreshToken);
  const activity = await stravaClient.getActivity(accessToken, event.object_id);

  const distanceKm = activity.distance / 1000;
  const durationMinutes = Math.round(activity.moving_time / 60);
  const paceMinPerKm = distanceKm > 0 ? durationMinutes / distanceKm : 0;

  await userDocRef.collection('workouts').doc().set({
    type: 'cardio',
    source: 'strava',
    date: admin.firestore.Timestamp.fromDate(new Date(activity.start_date)),
    durationMinutes,
    distanceKm,
    paceMinPerKm,
    stravaActivityId: String(activity.id),
  });
}

export const stravaWebhook = onRequest((req, res) => {
  if (req.method === 'GET') {
    // Strava's one-time webhook subscription validation handshake.
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    if (mode === 'subscribe' && token === STRAVA_VERIFY_TOKEN) {
      res.status(200).json({ 'hub.challenge': challenge });
      return;
    }
    res.status(403).send('Verification failed');
    return;
  }

  if (req.method === 'POST') {
    handleActivityEvent(req.body as StravaWebhookEvent)
      .then(() => res.status(200).send('EVENT_RECEIVED'))
      .catch((error) => {
        console.error('stravaWebhook error', error);
        res.status(200).send('EVENT_RECEIVED'); // ack anyway; error is logged, not retried
      });
    return;
  }

  res.status(405).send('Method not allowed');
});
```

Note on the `meta` collection-group query: this task deliberately reuses the same
`users/{uid}/meta/stravaConnection` path introduced in Task 9, and queries it via
`collectionGroup('meta')` filtered on `athleteId` to resolve the owning user without needing a
separate athlete-id-to-uid lookup table.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd functions && npm test -- stravaWebhook.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 6: Wire the function into index.ts**

```typescript
// functions/src/index.ts
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export { exchangeStravaToken } from './exchangeStravaToken';
export { stravaWebhook } from './stravaWebhook';
```

- [ ] **Step 7: Create the Firebase Hosting OAuth redirect page**

Strava requires an "Authorization Callback Domain" (a bare domain, not a custom URL scheme).
This static page is hosted on Firebase Hosting at that domain and immediately redirects into the
app's custom URL scheme, which `flutter_web_auth_2` (Task 11) captures.

```html
<!-- public/strava-callback.html -->
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Connecting to Strava…</title></head>
<body>
  <script>
    // Forward the full query string (contains ?code=... or ?error=...)
    // into the app's custom URL scheme deep link.
    window.location.replace('fitnesstracker://strava-callback' + window.location.search);
  </script>
  <p>Redirecting back to the app…</p>
</body>
</html>
```

- [ ] **Step 8: Add hosting config to firebase.json**

Read the current `firebase.json` first, then add a `"hosting"` key alongside the existing
`"firestore"` and `"flutter"` keys (do not remove either):

```json
{
  "firestore": {
    "rules": "firestore.rules"
  },
  "hosting": {
    "public": "public",
    "ignore": ["firebase.json", "**/.*"]
  },
  "flutter": {
    "...": "... (unchanged, keep the existing content exactly as-is)"
  }
}
```

- [ ] **Step 9: Set the Strava secrets as Cloud Functions environment config**

This step requires the Strava Client ID/Secret from the user (registered at
https://www.strava.com/settings/api) and a self-chosen random string for
`STRAVA_WEBHOOK_VERIFY_TOKEN`. If these haven't been provided yet, STOP here and report
NEEDS_CONTEXT — do not fabricate placeholder values and deploy with them.

```bash
firebase functions:secrets:set STRAVA_CLIENT_ID
firebase functions:secrets:set STRAVA_CLIENT_SECRET
firebase functions:secrets:set STRAVA_WEBHOOK_VERIFY_TOKEN
```

Then update `functions/src/exchangeStravaToken.ts`'s and `functions/src/stravaWebhook.ts`'s
`onCall`/`onRequest` declarations to declare the secrets they need, e.g.:
```typescript
export const exchangeStravaToken = onCall({ secrets: ['STRAVA_CLIENT_ID', 'STRAVA_CLIENT_SECRET'] }, async (request) => {
```
```typescript
export const stravaWebhook = onRequest({ secrets: ['STRAVA_WEBHOOK_VERIFY_TOKEN'] }, (req, res) => {
```
(`stravaClient.ts`'s `exchangeCode`/`refreshAccessToken` also need `STRAVA_CLIENT_ID`/
`STRAVA_CLIENT_SECRET` — since they read `process.env` at call time, declaring the secrets on
both functions that transitively call into `stravaClient.ts` is sufficient; no separate
declaration needed on `stravaClient.ts` itself since it isn't a Cloud Function.)

- [ ] **Step 10: Deploy functions and hosting**

```bash
firebase deploy --only functions,hosting
```

Expected: both deploy successfully. Note the deployed `stravaWebhook` HTTPS URL from the output —
it's needed when registering the webhook subscription (done via a one-time `curl` call in
Task 11's manual verification, using the Strava API's
`POST https://www.strava.com/api/v3/push_subscriptions` endpoint with that URL as
`callback_url`).

- [ ] **Step 11: Run TypeScript compilation and full functions test suite**

Run: `cd functions && npx tsc --noEmit && npm test`
Expected: no compile errors, all tests pass (5 total: 2 from Task 9, 3 from this task).

- [ ] **Step 12: Commit**

```bash
git add functions/src/stravaWebhook.ts functions/src/stravaWebhook.test.ts functions/src/index.ts functions/src/stravaClient.ts public/strava-callback.html firebase.json
git commit -m "Add stravaWebhook function and Firebase Hosting OAuth redirect page"
```

---

### Task 11: StravaConnection client repository and connect UI

**Files:**
- Create: `lib/features/strava/domain/strava_connection.dart`
- Create: `lib/features/strava/data/strava_connection_repository.dart`
- Create: `lib/features/strava/presentation/strava_connect_banner.dart`
- Test: `test/features/strava/data/strava_connection_repository_test.dart`
- Modify: `lib/features/workouts/presentation/workouts_home_screen.dart`
- Modify: `ios/Runner/Info.plist`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `GlassCard`/`PrimaryButton` (Phase 1), `cloud_functions`'s `FirebaseFunctions`.
- Produces: `StravaConnection { athleteId, connectedAt }`, `StravaConnectionRepository { Stream<StravaConnection?> watchConnection(String uid), Future<void> connect(String authorizationCode), Future<void> disconnect(String uid) }`, `StravaConnectBanner({required String uid, required StravaConnectionRepository repository})` — this is the final piece; nothing downstream in this plan consumes it.

- [ ] **Step 1: Add dependencies**

```bash
flutter pub add cloud_functions flutter_web_auth_2
```

- [ ] **Step 2: Write the failing test for StravaConnectionRepository**

```dart
// test/features/strava/data/strava_connection_repository_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/strava/data/strava_connection_repository.dart';

void main() {
  group('StravaConnectionRepository', () {
    test('watchConnection emits null when not connected', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = StravaConnectionRepository(firestore: firestore);

      final connection = await repository.watchConnection('uid-1').first;

      expect(connection, isNull);
    });

    test('watchConnection emits a StravaConnection once the doc exists', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = StravaConnectionRepository(firestore: firestore);

      await firestore
          .collection('users')
          .doc('uid-1')
          .collection('meta')
          .doc('stravaConnection')
          .set({'athleteId': 12345, 'refreshToken': 'unused-by-client'});

      final connection = await repository.watchConnection('uid-1').first;

      expect(connection, isNotNull);
      expect(connection!.athleteId, 12345);
    });

    test('disconnect deletes the connection document', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = StravaConnectionRepository(firestore: firestore);

      await firestore
          .collection('users')
          .doc('uid-1')
          .collection('meta')
          .doc('stravaConnection')
          .set({'athleteId': 12345, 'refreshToken': 'x'});

      await repository.disconnect('uid-1');

      final doc = await firestore
          .collection('users')
          .doc('uid-1')
          .collection('meta')
          .doc('stravaConnection')
          .get();
      expect(doc.exists, isFalse);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/strava/data/strava_connection_repository_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 4: Implement StravaConnection model**

```dart
// lib/features/strava/domain/strava_connection.dart
class StravaConnection {
  const StravaConnection({required this.athleteId, required this.connectedAt});

  final int athleteId;
  final DateTime? connectedAt;
}
```

- [ ] **Step 5: Implement StravaConnectionRepository**

Note: `connect()` calls the `exchangeStravaToken` Cloud Function (from Task 9/10) rather than
writing to Firestore directly — the client never has a refresh token to write, by design (the
token exchange and storage both happen server-side).

```dart
// lib/features/strava/data/strava_connection_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../domain/strava_connection.dart';

class StravaConnectionRepository {
  StravaConnectionRepository({
    required FirebaseFirestore firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> _connectionDoc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('meta')
      .doc('stravaConnection');

  Stream<StravaConnection?> watchConnection(String uid) {
    return _connectionDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      final connectedAt = data['connectedAt'] as Timestamp?;
      return StravaConnection(
        athleteId: data['athleteId'] as int,
        connectedAt: connectedAt?.toDate(),
      );
    });
  }

  Future<void> connect(String authorizationCode) async {
    await _functions.httpsCallable('exchangeStravaToken').call({'code': authorizationCode});
  }

  Future<void> disconnect(String uid) async {
    await _connectionDoc(uid).delete();
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/strava/data/strava_connection_repository_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Implement StravaConnectBanner**

Replace `YOUR_STRAVA_CLIENT_ID` below with the real Strava Client ID once provided (same value
used in Task 10's `firebase functions:secrets:set STRAVA_CLIENT_ID`); the callback domain must
match exactly what's registered in the Strava API application settings and what Task 10 deployed
to Firebase Hosting.

```dart
// lib/features/strava/presentation/strava_connect_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/strava_connection_repository.dart';
import '../domain/strava_connection.dart';

const _stravaClientId = 'YOUR_STRAVA_CLIENT_ID';
const _stravaCallbackDomain = 'snorlax-d2f99.web.app';
const _stravaAuthUrl =
    'https://www.strava.com/oauth/mobile/authorize'
    '?client_id=$_stravaClientId'
    '&redirect_uri=https://$_stravaCallbackDomain/strava-callback.html'
    '&response_type=code'
    '&approval_prompt=auto'
    '&scope=activity:read_all';

class StravaConnectBanner extends StatefulWidget {
  const StravaConnectBanner({super.key, required this.uid, required this.repository});

  final String uid;
  final StravaConnectionRepository repository;

  @override
  State<StravaConnectBanner> createState() => _StravaConnectBannerState();
}

class _StravaConnectBannerState extends State<StravaConnectBanner> {
  bool _connecting = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: _stravaAuthUrl,
        callbackUrlScheme: 'fitnesstracker',
      );
      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) {
        throw StateError('Strava did not return an authorization code.');
      }
      await widget.repository.connect(code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not connect to Strava. Please try again.');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    await widget.repository.disconnect(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StravaConnection?>(
      stream: widget.repository.watchConnection(widget.uid),
      builder: (context, snapshot) {
        final connected = snapshot.data != null;

        return GlassCard(
          child: Row(
            children: [
              Expanded(
                child: Text(connected ? 'Strava connected' : 'Connect Strava to sync your runs and rides'),
              ),
              if (_connecting)
                const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (connected)
                TextButton(onPressed: _disconnect, child: const Text('Disconnect'))
              else
                PrimaryButton(label: 'Connect', onPressed: _connect),
              if (_error != null) ...[
                const SizedBox(width: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 8: Wire StravaConnectBanner into WorkoutsHomeScreen**

Modify `lib/features/workouts/presentation/workouts_home_screen.dart`: replace the placeholder
comment/`SizedBox.shrink()` left by Task 7 with the real banner. Add a
`StravaConnectionRepository` field to the widget's constructor and state, then:

```dart
              // Was: "Strava "Connect Strava" banner is inserted here by Task 11."
              StravaConnectBanner(uid: widget.uid, repository: widget.stravaRepository),
```

Add the constructor parameter `required this.stravaRepository` (type `StravaConnectionRepository`)
to `WorkoutsHomeScreen`, and the import:
```dart
import '../../strava/data/strava_connection_repository.dart';
import '../../strava/presentation/strava_connect_banner.dart';
```

- [ ] **Step 9: Update Task 7's WorkoutsHomeScreen test for the new required parameter**

`test/features/workouts/presentation/workouts_home_screen_test.dart` (written in Task 7)
constructs `WorkoutsHomeScreen` without a `stravaRepository`, which now fails to compile since
Step 8 made it required. Add a `StravaConnectionRepository` (backed by the same
`FakeFirebaseFirestore` instance already used in each test) to both test cases' setup and pass it
to the constructor:

```dart
// Add this import at the top of the test file:
import 'package:fitness_tracker/features/strava/data/strava_connection_repository.dart';

// In each test, after creating `firestore`, add:
final stravaRepository = StravaConnectionRepository(firestore: firestore);

// And add `stravaRepository: stravaRepository,` to each WorkoutsHomeScreen(...) construction.
```

- [ ] **Step 10: Register the custom URL scheme on iOS**

Add to `ios/Runner/Info.plist`, inside the existing `<dict>` (read the file first to place this
correctly alongside existing keys, not duplicating the outer `<dict>`):

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>fitnesstracker</string>
    </array>
  </dict>
</array>
```

- [ ] **Step 11: Register the custom URL scheme on Android**

Add an intent filter inside the existing `<activity>` element in
`android/app/src/main/AndroidManifest.xml` (read the file first — add alongside the existing
`MAIN`/`LAUNCHER` intent filter, not replacing it):

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="fitnesstracker" />
</intent-filter>
```

- [ ] **Step 12: Run the full test suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests pass, "No issues found!"

- [ ] **Step 13: Manual verification**

This step requires the real Strava Client ID (already used in Step 7) and requires the
`stravaWebhook` function to already be deployed (Task 10, Step 10) so its URL is known. If the
Strava app credentials weren't available when this task was reached, STOP and report
NEEDS_CONTEXT rather than skipping verification silently.

1. Register the webhook subscription once (project-level, not per-run):
   ```bash
   curl -X POST https://www.strava.com/api/v3/push_subscriptions \
     -F client_id=YOUR_STRAVA_CLIENT_ID \
     -F client_secret=YOUR_STRAVA_CLIENT_SECRET \
     -F callback_url=<the stravaWebhook URL from Task 10's deploy output> \
     -F verify_token=<the value set as STRAVA_WEBHOOK_VERIFY_TOKEN in Task 10>
   ```
   Expected: Strava responds with a subscription id (200 OK); this confirms the `GET` handshake
   in `stravaWebhook` works correctly against Strava's real validation request.
2. Run the app on a simulator/device (`flutter run`), sign in, navigate to the Workouts tab, and
   tap "Connect" on the Strava banner. Confirm the OAuth browser flow opens, and after
   authorizing, the banner flips to "Strava connected".
3. Log a strength workout and a general workout manually; confirm both appear in the history
   list and their detail screens show correct data, with edit/delete working.
4. If convenient, record a short activity in Strava (or use an existing recent one) and confirm
   it eventually appears in the app's workout history as a read-only cardio entry (webhook
   delivery can take a short while — this isn't instant).

- [ ] **Step 14: Commit**

```bash
git add lib/features/strava lib/features/workouts/presentation/workouts_home_screen.dart test/features/workouts/presentation/workouts_home_screen_test.dart ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml test/features/strava pubspec.yaml pubspec.lock
git commit -m "Add StravaConnectionRepository, connect banner, and deep-link platform config"
```

---

## Phase 2 Exit Criteria

- `flutter analyze` clean and `flutter test` passes across the whole suite; `cd functions && npx tsc --noEmit && npm test` passes for the Cloud Functions.
- A user can log a strength workout (search/add exercises, enter sets), a general workout
  (duration + notes), see both in a history list, open a detail view, edit/delete manual entries.
- A user can view a line chart of an exercise's top-set weight over logged sessions.
- A user can connect their Strava account; once connected, new Strava activities appear
  automatically as read-only cardio workouts via the webhook, with no manual cardio entry path.
- The Strava client secret and webhook verify token exist only as Cloud Functions secrets, never
  in the Flutter app or committed to git.
