import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/adherence/data/adherence_repository.dart';
import 'package:fitness_tracker/features/body_composition/data/body_composition_repository.dart';
import 'package:fitness_tracker/features/body_composition/domain/body_measurement.dart';
import 'package:fitness_tracker/features/habits/data/habit_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_entry.dart';
import 'package:fitness_tracker/features/trends/presentation/trends_screen.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';

void main() {
  const uid = 'u1';

  Future<void> pumpTallSurface(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('renders real computed weight delta, nutrition deltas, and session delta', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final bodyCompositionRepository = BodyCompositionRepository(firestore: firestore);
    final nutritionRepository = NutritionRepository(firestore: firestore);
    final workoutRepository = WorkoutRepository(firestore: firestore);
    final adherenceRepository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: nutritionRepository,
      workoutRepository: workoutRepository,
      habitRepository: HabitRepository(firestore: firestore),
    );

    final now = DateTime.now();

    // Weight: ~7 weeks ago 80.0 kg -> today 76.6 kg = a real -3.4 kg delta.
    // (50 days, not the full 56-day window edge, so a few ms of clock drift
    // between this `now` and the one `TrendsScreen` reads in its own
    // `_load` can never push the measurement outside the window.)
    await bodyCompositionRepository.recordMeasurement(
      uid,
      BodyMeasurement(
        metric: BodyMetric.weight,
        value: 80.0,
        unit: 'kg',
        measuredAt: now.subtract(const Duration(days: 50)),
        createdAt: now.subtract(const Duration(days: 50)),
      ),
    );
    await bodyCompositionRepository.recordMeasurement(
      uid,
      BodyMeasurement(
        metric: BodyMetric.weight,
        value: 76.6,
        unit: 'kg',
        measuredAt: now,
        createdAt: now,
      ),
    );

    // Nutrition: 2000 kcal/150g protein logged each of the last 7 days
    // (avg 2000 kcal, 150g protein/day) vs. 1800 kcal/140g protein each of
    // the 7 days before that (avg 1800/140) -> a real +200 kcal, +10g delta.
    for (var d = 0; d < 7; d++) {
      await nutritionRepository.logFood(
        uid: uid,
        date: now.subtract(Duration(days: d)),
        mealType: MealType.lunch,
        foodName: 'Meal',
        quantityGrams: 300,
        calories: 2000,
        proteinG: 150,
        carbsG: 200,
        fatG: 60,
        source: FoodSource.custom,
      );
    }
    for (var d = 7; d < 14; d++) {
      await nutritionRepository.logFood(
        uid: uid,
        date: now.subtract(Duration(days: d)),
        mealType: MealType.lunch,
        foodName: 'Meal',
        quantityGrams: 300,
        calories: 1800,
        proteinG: 140,
        carbsG: 180,
        fatG: 55,
        source: FoodSource.custom,
      );
    }

    // Workouts: 2 sessions in the last 7 days vs. 1 in the 7 days before
    // that -> a real +1.0 sessions/week delta.
    await workoutRepository.createGeneralWorkout(
      uid: uid,
      date: now.subtract(const Duration(days: 1)),
      durationMinutes: 40,
      notes: 'Session A',
    );
    await workoutRepository.createGeneralWorkout(
      uid: uid,
      date: now.subtract(const Duration(days: 3)),
      durationMinutes: 40,
      notes: 'Session B',
    );
    await workoutRepository.createGeneralWorkout(
      uid: uid,
      date: now.subtract(const Duration(days: 9)),
      durationMinutes: 40,
      notes: 'Session C',
    );

    await pumpTallSurface(
      tester,
      MaterialApp(
        home: TrendsScreen(
          uid: uid,
          bodyCompositionRepository: bodyCompositionRepository,
          adherenceRepository: adherenceRepository,
          nutritionRepository: nutritionRepository,
          workoutRepository: workoutRepository,
        ),
      ),
    );

    expect(find.text('-3.4 kg'), findsOneWidget);
    expect(find.text('2000 kcal'), findsOneWidget);
    expect(find.text('+200'), findsOneWidget);
    expect(find.text('150 g'), findsOneWidget);
    expect(find.text('+10g'), findsOneWidget);
    expect(find.text('2.0'), findsOneWidget);
    expect(find.text('+1.0'), findsOneWidget);
    // Sleep has no data source yet (Slice C may not have landed) — stub,
    // never a fabricated number.
    expect(find.text('—'), findsOneWidget);
  });
}
