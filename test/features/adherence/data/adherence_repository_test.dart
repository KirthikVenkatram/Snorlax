import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/adherence_calculator.dart';
import 'package:fitness_tracker/features/adherence/data/adherence_repository.dart';
import 'package:fitness_tracker/features/habits/data/habit_repository.dart';
import 'package:fitness_tracker/features/habits/domain/habit.dart';
import 'package:fitness_tracker/features/habits/domain/habit_completion.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_entry.dart';
import 'package:fitness_tracker/features/readiness/data/readiness_repository.dart';
import 'package:fitness_tracker/features/readiness/domain/readiness_entry.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';

AdherenceRepository _repo(FakeFirebaseFirestore firestore) => AdherenceRepository(
      firestore: firestore,
      nutritionRepository: NutritionRepository(firestore: firestore),
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: HabitRepository(firestore: firestore),
    );

void main() {
  final day = DateTime(2026, 9, 10);

  test('weights default to the spec values and are persisted when set', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);

    final defaults = await repository.getWeights('u');
    expect(defaults.nutrition, 0.40);
    expect(defaults.training, 0.25);
    expect(defaults.habits, 0.20);
    expect(defaults.recovery, 0.15);

    await repository.setWeights('u', const AdherenceWeights(nutrition: 0.5, training: 0.2, habits: 0.2, recovery: 0.1));
    final updated = await repository.getWeights('u');
    expect(updated.nutrition, 0.5);
  });

  test('computeAndCacheDaily excludes nutrition and recovery when neither has data', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);

    final summary = await repository.computeAndCacheDaily('u', day);

    expect(summary.excludedComponents, contains(AdherenceComponent.nutrition));
    expect(summary.excludedComponents, contains(AdherenceComponent.recovery));
  });

  test('computeAndCacheDaily scores recovery from the day\'s readiness check-in', () async {
    final firestore = FakeFirebaseFirestore();
    final readinessRepository = ReadinessRepository(firestore: firestore);
    await readinessRepository.recordCheckIn(
      'u',
      day,
      const ReadinessInputs(
        sleepHours: 8,
        sleepConsistency: 1.0,
        soreness: 0.0,
        fatigue: 0.0,
        energy: 1.0,
        recentTrainingLoad: 0.0,
      ),
    );

    final repository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: NutritionRepository(firestore: firestore),
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: HabitRepository(firestore: firestore),
      readinessRepository: readinessRepository,
    );

    final summary = await repository.computeAndCacheDaily('u', day);

    expect(summary.excludedComponents, isNot(contains(AdherenceComponent.recovery)));
    expect(summary.componentScores[AdherenceComponent.recovery], closeTo(1.0, 1e-9));
  });

  test('computeAndCacheDaily excludes recovery (not zero) when no readiness check-in exists for the date', () async {
    final firestore = FakeFirebaseFirestore();
    final readinessRepository = ReadinessRepository(firestore: firestore);
    // Check in for a different date only.
    await readinessRepository.recordCheckIn(
      'u',
      day.subtract(const Duration(days: 1)),
      const ReadinessInputs(
        sleepHours: 8,
        sleepConsistency: 1.0,
        soreness: 0.0,
        fatigue: 0.0,
        energy: 1.0,
        recentTrainingLoad: 0.0,
      ),
    );

    final repository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: NutritionRepository(firestore: firestore),
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: HabitRepository(firestore: firestore),
      readinessRepository: readinessRepository,
    );

    final summary = await repository.computeAndCacheDaily('u', day);

    expect(summary.excludedComponents, contains(AdherenceComponent.recovery));
    expect(summary.componentScores.containsKey(AdherenceComponent.recovery), isFalse);
  });

  test('computeAndCacheDaily scores nutrition against the goal and logged entries', () async {
    final firestore = FakeFirebaseFirestore();
    final nutritionRepository = NutritionRepository(firestore: firestore);
    await nutritionRepository.setGoals(
      'u',
      const NutritionGoals(dailyCalories: 2000, proteinG: 150, carbsG: 200, fatG: 60),
    );
    await nutritionRepository.logFood(
      uid: 'u',
      date: day,
      mealType: MealType.lunch,
      foodName: 'Chicken bowl',
      quantityGrams: 400,
      calories: 2000,
      proteinG: 150,
      carbsG: 200,
      fatG: 60,
      source: FoodSource.custom,
    );

    final repository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: nutritionRepository,
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: HabitRepository(firestore: firestore),
    );

    final summary = await repository.computeAndCacheDaily('u', day);

    expect(summary.componentScores[AdherenceComponent.nutrition], closeTo(1.0, 1e-9));
  });

  test('computeAndCacheDaily scores training based on whether a workout was logged', () async {
    final firestore = FakeFirebaseFirestore();
    final workoutRepository = WorkoutRepository(firestore: firestore);
    await workoutRepository.createGeneralWorkout(
      uid: 'u',
      date: day,
      durationMinutes: 30,
      notes: 'Run',
    );

    final repository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: NutritionRepository(firestore: firestore),
      workoutRepository: workoutRepository,
      habitRepository: HabitRepository(firestore: firestore),
    );

    final summary = await repository.computeAndCacheDaily('u', day);
    expect(summary.componentScores[AdherenceComponent.training], 1.0);
  });

  test('computeAndCacheDaily scores habits as a fraction, excluding excluded habits from the denominator', () async {
    final firestore = FakeFirebaseFirestore();
    final habitRepository = HabitRepository(firestore: firestore);
    await habitRepository.createHabit(
      'u',
      Habit(id: 'h1', name: 'Water', cadence: HabitCadence.daily, createdAt: day),
    );
    await habitRepository.createHabit(
      'u',
      Habit(id: 'h2', name: 'Stretch', cadence: HabitCadence.daily, createdAt: day),
    );
    await habitRepository.createHabit(
      'u',
      Habit(id: 'h3', name: 'Run', cadence: HabitCadence.daily, createdAt: day),
    );
    await habitRepository.completeHabit('u', day, 'h1', completed: true);
    await habitRepository.completeHabit('u', day, 'h2', completed: false);
    await habitRepository.completeHabit(
      'u',
      day,
      'h3',
      completed: false,
      excluded: true,
      reason: ExclusionReason.illness,
    );

    final repository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: NutritionRepository(firestore: firestore),
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: habitRepository,
    );

    final summary = await repository.computeAndCacheDaily('u', day);

    // h3 excluded -> denominator is 2 (h1, h2), numerator 1 (h1 completed).
    expect(summary.componentScores[AdherenceComponent.habits], closeTo(0.5, 1e-9));
  });

  test('a habit created today does not retroactively affect the habits component score for a past day', () async {
    final firestore = FakeFirebaseFirestore();
    final habitRepository = HabitRepository(firestore: firestore);
    // A habit that already existed on `day` and `day - 1`.
    await habitRepository.createHabit(
      'u',
      Habit(id: 'h1', name: 'Water', cadence: HabitCadence.daily, createdAt: day.subtract(const Duration(days: 2))),
    );
    await habitRepository.completeHabit('u', day.subtract(const Duration(days: 1)), 'h1', completed: true);
    await habitRepository.completeHabit('u', day, 'h1', completed: true);

    final repository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: NutritionRepository(firestore: firestore),
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: habitRepository,
    );

    // Both past days score 1.0 with just h1 completed.
    final before = await repository.computeAndCacheDaily('u', day.subtract(const Duration(days: 1)));
    expect(before.componentScores[AdherenceComponent.habits], closeTo(1.0, 1e-9));
    final today = await repository.computeAndCacheDaily('u', day);
    expect(today.componentScores[AdherenceComponent.habits], closeTo(1.0, 1e-9));

    // Now a brand-new habit is created "today" (createdAt = day) and never
    // marked completed for the two prior days (it didn't exist then).
    await habitRepository.createHabit(
      'u',
      Habit(id: 'h2', name: 'New habit', cadence: HabitCadence.daily, createdAt: day),
    );

    // Re-scoring the prior days must be unaffected by h2's existence: h2
    // didn't exist on day-1 or day-2, so it must not count as an
    // uncompleted habit there and drag the score down.
    final beforeAfterCreate =
        await repository.computeAndCacheDaily('u', day.subtract(const Duration(days: 1)));
    expect(beforeAfterCreate.componentScores[AdherenceComponent.habits], closeTo(1.0, 1e-9));

    // "Today" (day == h2.createdAt) does include h2 in the denominator,
    // uncompleted, dragging the score down to 0.5.
    final todayAfterCreate = await repository.computeAndCacheDaily('u', day);
    expect(todayAfterCreate.componentScores[AdherenceComponent.habits], closeTo(0.5, 1e-9));
  });

  test('getDaily reads back a cached summary', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);

    await repository.computeAndCacheDaily('u', day);
    final fetched = await repository.getDaily('u', day);

    expect(fetched, isNotNull);
  });

  test('computeAndCacheWeekly rolls up 7 days and skips future days', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);

    final summary = await repository.computeAndCacheWeekly('u', DateTime.now());

    expect(summary.dailyScores, hasLength(7));
    final fetched = await repository.getWeekly('u', summary.weekId);
    expect(fetched, isNotNull);
  });
}
