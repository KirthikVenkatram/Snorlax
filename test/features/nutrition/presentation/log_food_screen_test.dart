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

  testWidgets('describe mode: parse text, save all logs every parsed item', (tester) async {
    final functions = MockFirebaseFunctions();
    final firestore = FakeFirebaseFirestore();
    final customFoodRepository = CustomFoodRepository(firestore: firestore);
    final searchService = FoodSearchService(functions: functions, customFoodRepository: customFoodRepository);
    final nutritionRepository = NutritionRepository(firestore: firestore);

    final parseCallable = MockHttpsCallable();
    final parseResult = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('parseFoodText')).thenReturn(parseCallable);
    when(() => parseCallable.call<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => parseResult);
    when(() => parseResult.data).thenReturn({
      'items': [
        {'foodName': 'Dosa', 'estimatedQuantityGrams': 120},
        {'foodName': 'Sambar', 'estimatedQuantityGrams': 200},
      ],
    });

    // Each parsed item is resolved through searchFood first.
    final searchCallable = MockHttpsCallable();
    final searchResult = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('searchFood')).thenReturn(searchCallable);
    when(() => searchCallable.call<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => searchResult);
    when(() => searchResult.data).thenReturn({
      'results': [
        {
          'name': 'Resolved food',
          'source': 'usda',
          'caloriesPer100g': 100,
          'proteinPer100g': 5,
          'carbsPer100g': 20,
          'fatPer100g': 2,
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

    await tester.tap(find.text('Describe'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'a dosa and some sambar');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Dosa'), findsOneWidget);
    expect(find.textContaining('Sambar'), findsOneWidget);

    await tester.tap(find.text('Save all'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    final entries = await nutritionRepository.listFoodLog('uid-1');
    expect(entries, hasLength(2));

    final dosa = entries.firstWhere((e) => e.foodName == 'Dosa');
    expect(dosa.quantityGrams, 120);
    expect(dosa.date, selectedDate);
    // 100 kcal/100g scaled to 120g = 120.
    expect(dosa.calories, 120);
    expect(dosa.proteinG, 6);

    final sambar = entries.firstWhere((e) => e.foodName == 'Sambar');
    expect(sambar.quantityGrams, 200);
    expect(sambar.calories, 200);
  });

  testWidgets('describe mode: a total lookup failure shows an error, not a stuck spinner',
      (tester) async {
    final functions = MockFirebaseFunctions();
    final firestore = FakeFirebaseFirestore();
    final customFoodRepository = CustomFoodRepository(firestore: firestore);
    final searchService = FoodSearchService(functions: functions, customFoodRepository: customFoodRepository);
    final nutritionRepository = NutritionRepository(firestore: firestore);

    final parseCallable = MockHttpsCallable();
    final parseResult = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('parseFoodText')).thenReturn(parseCallable);
    when(() => parseCallable.call<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => parseResult);
    when(() => parseResult.data).thenReturn({
      'items': [
        {'foodName': 'Dosa', 'estimatedQuantityGrams': 120},
      ],
    });

    // Both the search and the LLM estimate fall over.
    final failingCallable = MockHttpsCallable();
    when(() => functions.httpsCallable('searchFood')).thenReturn(failingCallable);
    when(() => functions.httpsCallable('estimateNutrition')).thenReturn(failingCallable);
    when(() => failingCallable.call<Map<String, dynamic>>(any()))
        .thenThrow(Exception('unavailable'));

    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: LogFoodScreen(
          uid: 'uid-1',
          nutritionRepository: nutritionRepository,
          searchService: searchService,
          date: DateTime(2026, 8, 20),
          onSaved: () => saved = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Describe'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'a dosa');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save all'));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Could not look up nutrition'), findsOneWidget);
    expect(saved, isFalse);
    expect(await nutritionRepository.listFoodLog('uid-1'), isEmpty);
  });

  testWidgets(
      'describe mode: a partial lookup failure saves what it can, stays on screen, and only retries the failed item',
      (tester) async {
    final functions = MockFirebaseFunctions();
    final firestore = FakeFirebaseFirestore();
    final customFoodRepository = CustomFoodRepository(firestore: firestore);
    final searchService = FoodSearchService(functions: functions, customFoodRepository: customFoodRepository);
    final nutritionRepository = NutritionRepository(firestore: firestore);

    final parseCallable = MockHttpsCallable();
    final parseResult = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('parseFoodText')).thenReturn(parseCallable);
    when(() => parseCallable.call<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => parseResult);
    when(() => parseResult.data).thenReturn({
      'items': [
        {'foodName': 'Dosa', 'estimatedQuantityGrams': 120},
        {'foodName': 'Sambar', 'estimatedQuantityGrams': 200},
      ],
    });

    final searchCallable = MockHttpsCallable();
    when(() => functions.httpsCallable('searchFood')).thenReturn(searchCallable);
    final dosaResult = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => dosaResult.data).thenReturn({
      'results': [
        {
          'name': 'Dosa',
          'source': 'usda',
          'caloriesPer100g': 100,
          'proteinPer100g': 5,
          'carbsPer100g': 20,
          'fatPer100g': 2,
        },
      ],
    });
    when(() => searchCallable.call<Map<String, dynamic>>(
          any(that: predicate((Object? a) => (a as Map)['query'] == 'Dosa')),
        )).thenAnswer((_) async => dosaResult);
    when(() => searchCallable.call<Map<String, dynamic>>(
          any(that: predicate((Object? a) => (a as Map)['query'] == 'Sambar')),
        )).thenThrow(Exception('search unavailable'));

    final estimateCallable = MockHttpsCallable();
    when(() => functions.httpsCallable('estimateNutrition')).thenReturn(estimateCallable);
    when(() => estimateCallable.call<Map<String, dynamic>>(any()))
        .thenThrow(Exception('estimate unavailable'));

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

    await tester.tap(find.text('Describe'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'a dosa and some sambar');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save all'));
    await tester.pumpAndSettle();

    // onSaved is NOT called on a partial failure — calling it would pop this
    // screen (via the caller's callback) before the error message below is
    // ever painted, silently discarding the failed item.
    expect(saved, isFalse);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Saved 1 item(s)'), findsOneWidget);

    final entries = await nutritionRepository.listFoodLog('uid-1');
    expect(entries, hasLength(1));
    expect(entries.first.foodName, 'Dosa');

    // The failed item is still on screen, ready to retry — the succeeded
    // item is not, so retrying can't create a duplicate.
    expect(find.textContaining('Dosa'), findsNothing);
    expect(find.textContaining('Sambar'), findsOneWidget);
  });
}
