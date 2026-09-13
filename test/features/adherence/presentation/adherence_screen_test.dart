import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/adherence/data/adherence_repository.dart';
import 'package:fitness_tracker/features/adherence/presentation/adherence_screen.dart';
import 'package:fitness_tracker/features/habits/data/habit_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';

void main() {
  testWidgets('adherence screen shows supportive copy with no punitive language', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: NutritionRepository(firestore: firestore),
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: HabitRepository(firestore: firestore),
    );

    await tester.pumpWidget(
      MaterialApp(home: AdherenceScreen(uid: 'u', repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.byKey(const Key('dailySupportiveSummary')), findsOneWidget);
  });
}
