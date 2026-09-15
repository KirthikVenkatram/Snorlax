import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/nutrition/data/recipe_repository.dart';
import 'package:fitness_tracker/features/nutrition/domain/recipe.dart';

void main() {
  test('save then list round-trips a recipe, including per-serving division', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = RecipeRepository(firestore: firestore);

    final saved = await repository.save(
      'uid-1',
      const Recipe(
        id: '',
        name: 'Sambar',
        servings: 4,
        ingredientNames: ['Toor dal', 'Tamarind pulp', 'Sambar powder'],
        totalCalories: 800,
        totalProteinG: 40,
        totalCarbsG: 100,
        totalFatG: 20,
      ),
    );

    expect(saved.id, isNotEmpty);
    expect(saved.caloriesPerServing, 200);
    expect(saved.proteinPerServing, 10);

    final all = await repository.list('uid-1');
    expect(all, hasLength(1));
    expect(all.first.name, 'Sambar');
    expect(all.first.ingredientNames, ['Toor dal', 'Tamarind pulp', 'Sambar powder']);
  });

  test('search filters by case-insensitive name substring', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = RecipeRepository(firestore: firestore);
    await repository.save(
      'uid-1',
      const Recipe(
        id: '',
        name: 'Chicken Curry',
        servings: 2,
        ingredientNames: [],
        totalCalories: 500,
        totalProteinG: 30,
        totalCarbsG: 20,
        totalFatG: 15,
      ),
    );

    final results = await repository.search('uid-1', 'chicken');
    expect(results, hasLength(1));

    final noMatch = await repository.search('uid-1', 'dosa');
    expect(noMatch, isEmpty);
  });
}
