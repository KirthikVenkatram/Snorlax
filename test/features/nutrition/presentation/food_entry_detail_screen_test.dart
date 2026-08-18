import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_entry.dart';
import 'package:fitness_tracker/features/nutrition/presentation/food_entry_detail_screen.dart';

void main() {
  testWidgets('editing quantity recomputes macros and saves', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = NutritionRepository(firestore: firestore);

    final id = await repository.logFood(
      uid: 'uid-1', date: DateTime(2026, 8, 1), mealType: MealType.lunch,
      foodName: 'Rice', quantityGrams: 100, calories: 130, proteinG: 2.7,
      carbsG: 28, fatG: 0.3, source: FoodSource.usda);
    final entry = (await repository.listFoodLog('uid-1')).first;

    var changed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: FoodEntryDetailScreen(
          uid: 'uid-1',
          entry: entry,
          nutritionRepository: repository,
          onChanged: () => changed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quantityGramsField')), '200');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(changed, isTrue);
    final updated = (await repository.listFoodLog('uid-1')).firstWhere((e) => e.id == id);
    expect(updated.quantityGrams, 200);
    // Per-gram rate preserved: 130/100 * 200 = 260.
    expect(updated.calories, 260);
  });

  testWidgets('delete removes the entry', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = NutritionRepository(firestore: firestore);

    await repository.logFood(
      uid: 'uid-1', date: DateTime(2026, 8, 1), mealType: MealType.snack,
      foodName: 'to delete', quantityGrams: 50, calories: 50, proteinG: 1,
      carbsG: 1, fatG: 1, source: FoodSource.custom);
    final entry = (await repository.listFoodLog('uid-1')).first;

    var changed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: FoodEntryDetailScreen(
          uid: 'uid-1',
          entry: entry,
          nutritionRepository: repository,
          onChanged: () => changed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(changed, isTrue);
    expect(await repository.listFoodLog('uid-1'), isEmpty);
  });
}
