import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/adherence/data/adherence_repository.dart';
import 'package:fitness_tracker/features/adherence/domain/adherence_summary.dart';
import 'package:fitness_tracker/features/habits/data/habit_repository.dart';
import 'package:fitness_tracker/features/habits/domain/habit.dart';
import 'package:fitness_tracker/features/habits/presentation/streaks_screen.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';

Future<void> _pumpTallSurface(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the hero streak count from real seeded adherence history', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final habitRepository = HabitRepository(firestore: firestore);
    final adherenceRepository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: NutritionRepository(firestore: firestore),
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: habitRepository,
    );

    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    // Seed a 3-day unbroken streak ending today.
    for (var i = 0; i < 3; i++) {
      final day = todayDay.subtract(Duration(days: i));
      await firestore
          .collection('users')
          .doc('u')
          .collection('adherenceDaily')
          .doc(_docId(day))
          .set(
            DailyAdherenceSummary(
              date: day,
              overallScore: 0.9,
              componentScores: const {},
              excludedComponents: const {},
              calculatedAt: day,
            ).toJson(),
          );
    }

    await _pumpTallSurface(
      tester,
      MaterialApp(
        home: StreaksScreen(
          uid: 'u',
          habitRepository: habitRepository,
          adherenceRepository: adherenceRepository,
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('Longest yet: 3'), findsOneWidget);
  });

  testWidgets('toggling a habit updates its completed-today state', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final habitRepository = HabitRepository(firestore: firestore);
    await habitRepository.createHabit(
      'u',
      Habit(id: 'h1', name: 'Stretch', cadence: HabitCadence.daily, createdAt: DateTime(2026, 1, 1)),
    );
    final adherenceRepository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: NutritionRepository(firestore: firestore),
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: habitRepository,
    );

    await _pumpTallSurface(
      tester,
      MaterialApp(
        home: StreaksScreen(
          uid: 'u',
          habitRepository: habitRepository,
          adherenceRepository: adherenceRepository,
        ),
      ),
    );

    expect(find.text('Stretch'), findsOneWidget);

    await tester.tap(find.byKey(const Key('streakHabitToggle_h1')));
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final completion = await habitRepository.getCompletion('u', DateTime(today.year, today.month, today.day));
    expect(completion?.entries['h1']?.completed, isTrue);
  });
}

String _docId(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
