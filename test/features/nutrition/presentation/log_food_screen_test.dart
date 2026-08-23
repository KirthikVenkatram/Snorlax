import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/features/nutrition/data/custom_food_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/food_search_service.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/nutrition/presentation/log_food_screen.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

void main() {
  testWidgets('search mode: pick a result, set grams, save logs the entry', (tester) async {
    final functions = MockFirebaseFunctions();
    final firestore = FakeFirebaseFirestore();
    final customFoodRepository = CustomFoodRepository(firestore: firestore);
    final searchService = FoodSearchService(functions: functions, customFoodRepository: customFoodRepository);
    final nutritionRepository = NutritionRepository(firestore: firestore);

    final callable = MockHttpsCallable();
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('searchFood')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({
      'results': [
        {
          'name': 'White Rice',
          'source': 'usda',
          'caloriesPer100g': 130,
          'proteinPer100g': 2.7,
          'carbsPer100g': 28,
          'fatPer100g': 0.3,
        },
      ],
    });

    var saved = false;
    final selectedDate = DateTime(2026, 8, 20);

    await tester.pumpWidget(
      MaterialApp(
        home: LogFoodScreen(
          uid: 'uid-1',
          nutritionRepository: nutritionRepository,
          searchService: searchService,
          date: selectedDate,
          onSaved: () => saved = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('foodSearchField')), 'rice');
    await tester.pumpAndSettle();
    await tester.tap(find.text('White Rice'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quantityGramsField')), '200');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    final entries = await nutritionRepository.listFoodLog('uid-1');
    expect(entries, hasLength(1));
    expect(entries.first.foodName, 'White Rice');
    expect(entries.first.quantityGrams, 200);
    expect(entries.first.date, selectedDate);
    // 130 kcal/100g scaled to 200g = 260.
    expect(entries.first.calories, 260);
  });
}
