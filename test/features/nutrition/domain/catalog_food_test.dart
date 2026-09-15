import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/nutrition/domain/catalog_food.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_entry.dart';
import 'package:fitness_tracker/features/nutrition/domain/recipe.dart';

FoodEntry _entry(String name, {FoodSource source = FoodSource.custom}) => FoodEntry(
      id: name,
      date: DateTime(2026, 9, 1),
      mealType: MealType.snack,
      foodName: name,
      quantityGrams: 100,
      calories: 100,
      proteinG: 10,
      carbsG: 10,
      fatG: 10,
      source: source,
    );

void main() {
  test('recent log entries come first, deduped by name', () {
    final result = buildFrequentFoods(
      recentLogNewestFirst: [_entry('Dosa'), _entry('Dosa'), _entry('Idli')],
      recipes: [],
    );

    expect(
      result.map((e) => e.name),
      ['Dosa', 'Idli', ...kIndianCatalogSeed.skip(1).map((c) => c.name).take(6)],
    );
  });

  test('recipes are tagged "Recipe" and included after recent entries', () {
    final result = buildFrequentFoods(
      recentLogNewestFirst: [],
      recipes: [
        const Recipe(
          id: 'r1',
          name: 'Sambar',
          servings: 4,
          ingredientNames: [],
          totalCalories: 800,
          totalProteinG: 40,
          totalCarbsG: 100,
          totalFatG: 20,
        ),
      ],
    );

    // Sambar is also in the seed catalog — the recipe wins since it's added
    // first and the seed entry is deduped away.
    final sambar = result.firstWhere((e) => e.name == 'Sambar');
    expect(sambar.tag, 'Recipe');
    expect(sambar.calories, 200); // 800 / 4 servings
  });

  test('result is capped at limit', () {
    final result = buildFrequentFoods(
      recentLogNewestFirst: [_entry('A'), _entry('B'), _entry('C')],
      recipes: [],
      limit: 2,
    );

    expect(result, hasLength(2));
    expect(result.map((e) => e.name), ['A', 'B']);
  });

  test('scanned entries are tagged "Scanned"', () {
    final result = buildFrequentFoods(
      recentLogNewestFirst: [_entry('Protein Bar', source: FoodSource.openFoodFactsScanned)],
      recipes: [],
    );

    expect(result.first.tag, 'Scanned');
  });
}
