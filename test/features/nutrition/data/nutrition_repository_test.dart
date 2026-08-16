// test/features/nutrition/data/nutrition_repository_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_entry.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';

void main() {
  group('NutritionRepository', () {
    test('logFood writes a food entry with scaled macros', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = NutritionRepository(firestore: firestore);

      final id = await repository.logFood(
        uid: 'uid-1',
        date: DateTime(2026, 8, 15),
        mealType: MealType.breakfast,
        foodName: 'Idli',
        quantityGrams: 150,
        calories: 195,
        proteinG: 6,
        carbsG: 40,
        fatG: 1.5,
        source: FoodSource.custom,
      );

      final entries = await repository.listFoodLog('uid-1');

      expect(entries, hasLength(1));
      expect(entries.first.id, id);
      expect(entries.first.mealType, MealType.breakfast);
      expect(entries.first.foodName, 'Idli');
      expect(entries.first.quantityGrams, 150);
      expect(entries.first.calories, 195);
      expect(entries.first.source, FoodSource.custom);
    });

    test('listFoodLog returns entries newest-first', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = NutritionRepository(firestore: firestore);

      await repository.logFood(
        uid: 'uid-1', date: DateTime(2026, 8, 1), mealType: MealType.breakfast,
        foodName: 'first', quantityGrams: 100, calories: 100, proteinG: 1,
        carbsG: 1, fatG: 1, source: FoodSource.custom);
      await repository.logFood(
        uid: 'uid-1', date: DateTime(2026, 8, 3), mealType: MealType.breakfast,
        foodName: 'third', quantityGrams: 100, calories: 100, proteinG: 1,
        carbsG: 1, fatG: 1, source: FoodSource.custom);
      await repository.logFood(
        uid: 'uid-1', date: DateTime(2026, 8, 2), mealType: MealType.breakfast,
        foodName: 'second', quantityGrams: 100, calories: 100, proteinG: 1,
        carbsG: 1, fatG: 1, source: FoodSource.custom);

      final entries = await repository.listFoodLog('uid-1');

      expect(entries.map((e) => e.foodName), ['third', 'second', 'first']);
    });

    test('updateFoodEntry modifies quantity and recomputed macros', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = NutritionRepository(firestore: firestore);

      final id = await repository.logFood(
        uid: 'uid-1', date: DateTime(2026, 8, 1), mealType: MealType.lunch,
        foodName: 'Rice', quantityGrams: 100, calories: 130, proteinG: 2.7,
        carbsG: 28, fatG: 0.3, source: FoodSource.usda);

      await repository.updateFoodEntry(
        uid: 'uid-1', entryId: id, mealType: MealType.dinner,
        quantityGrams: 200, calories: 260, proteinG: 5.4, carbsG: 56, fatG: 0.6);

      final entries = await repository.listFoodLog('uid-1');
      expect(entries.first.mealType, MealType.dinner);
      expect(entries.first.quantityGrams, 200);
      expect(entries.first.calories, 260);
    });

    test('deleteFoodEntry removes the entry', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = NutritionRepository(firestore: firestore);

      final id = await repository.logFood(
        uid: 'uid-1', date: DateTime(2026, 8, 1), mealType: MealType.snack,
        foodName: 'to delete', quantityGrams: 50, calories: 50, proteinG: 1,
        carbsG: 1, fatG: 1, source: FoodSource.custom);

      await repository.deleteFoodEntry('uid-1', id);

      final entries = await repository.listFoodLog('uid-1');
      expect(entries, isEmpty);
    });

    test('setGoals and getGoals round-trip', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = NutritionRepository(firestore: firestore);

      expect(await repository.getGoals('uid-1'), isNull);

      await repository.setGoals(
        'uid-1',
        const NutritionGoals(dailyCalories: 2000, proteinG: 150, carbsG: 200, fatG: 60));

      final goals = await repository.getGoals('uid-1');
      expect(goals!.dailyCalories, 2000);
      expect(goals.proteinG, 150);
    });
  });
}
