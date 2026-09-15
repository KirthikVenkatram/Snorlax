import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/features/nutrition/data/custom_food_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/food_search_service.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/recipe_repository.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_entry.dart';
import 'package:fitness_tracker/features/nutrition/presentation/recipe_builder_screen.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

Future<void> pumpTallSurface(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: widget));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('selecting ingredients, then saving writes a recipe and a food-log entry',
      (tester) async {
    final functions = MockFirebaseFunctions();
    final firestore = FakeFirebaseFirestore();
    final customFoodRepository = CustomFoodRepository(firestore: firestore);
    final searchService = FoodSearchService(functions: functions, customFoodRepository: customFoodRepository);
    final nutritionRepository = NutritionRepository(firestore: firestore);
    final recipeRepository = RecipeRepository(firestore: firestore);

    final callable = MockHttpsCallable();
    when(() => functions.httpsCallable('estimateNutrition')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((invocation) async {
      final result = MockHttpsCallableResult<Map<String, dynamic>>();
      when(() => result.data).thenReturn({
        'caloriesPer100g': 200,
        'proteinPer100g': 10,
        'carbsPer100g': 20,
        'fatPer100g': 5,
      });
      return result;
    });

    var saved = false;
    final date = DateTime(2026, 9, 15);

    await pumpTallSurface(
      tester,
      RecipeBuilderScreen(
        uid: 'uid-1',
        date: date,
        searchService: searchService,
        recipeRepository: recipeRepository,
        nutritionRepository: nutritionRepository,
        onSaved: () => saved = true,
      ),
    );

    await tester.enterText(find.byKey(const Key('recipeNameField')), 'Sambar');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Toor dal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onion'));
    await tester.pumpAndSettle();

    expect(find.text('INGREDIENTS · 2 ADDED'), findsOneWidget);

    await tester.tap(find.text('Save and log one serving'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);

    final recipes = await recipeRepository.list('uid-1');
    expect(recipes, hasLength(1));
    expect(recipes.first.name, 'Sambar');
    // Default 4 servings, 2 ingredients @ 200kcal/100g each = 400 total / 4 = 100.
    expect(recipes.first.caloriesPerServing, 100);

    final entries = await nutritionRepository.listFoodLog('uid-1');
    expect(entries, hasLength(1));
    expect(entries.first.foodName, 'Sambar');
    expect(entries.first.source, FoodSource.recipe);
    expect(entries.first.calories, 100);
  });
}
