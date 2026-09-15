import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/adherence/data/adherence_repository.dart';
import 'package:fitness_tracker/features/dashboard/presentation/home_tab.dart';
import 'package:fitness_tracker/features/habits/data/habit_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/readiness/data/readiness_repository.dart';
import 'package:fitness_tracker/features/sleep/data/sleep_repository.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';

void main() {
  Widget buildHome({required ValueChanged<int> onNavigateToTab, String? displayName}) {
    final firestore = FakeFirebaseFirestore();
    final nutritionRepository = NutritionRepository(firestore: firestore);
    final workoutRepository = WorkoutRepository(firestore: firestore);
    final habitRepository = HabitRepository(firestore: firestore);
    final adherenceRepository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: nutritionRepository,
      workoutRepository: workoutRepository,
      habitRepository: habitRepository,
      readinessRepository: ReadinessRepository(firestore: firestore),
    );

    return MaterialApp(
      home: HomeTab(
        uid: 'u1',
        displayName: displayName,
        nutritionRepository: nutritionRepository,
        adherenceRepository: adherenceRepository,
        workoutRepository: workoutRepository,
        sleepRepository: SleepRepository(firestore: firestore),
        habitRepository: habitRepository,
        onNavigateToTab: onNavigateToTab,
      ),
    );
  }

  testWidgets('shows a placeholder instead of a fake zero when no calorie goal is set', (tester) async {
    await tester.pumpWidget(buildHome(onNavigateToTab: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsWidgets);
  });

  testWidgets('greets with the real display name, falling back to no name', (tester) async {
    await tester.pumpWidget(buildHome(onNavigateToTab: (_) {}, displayName: 'Kirthik Venkatram'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kirthik'), findsOneWidget);
  });

  testWidgets('tapping the hero card switches to the Nutrition tab', (tester) async {
    int? navigatedTo;
    await tester.pumpWidget(buildHome(onNavigateToTab: (i) => navigatedTo = i));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('todayHeroCard')));
    await tester.pumpAndSettle();

    expect(navigatedTo, 1);
  });
}
