import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/features/nutrition/data/custom_food_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/food_search_service.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_search_result.dart';
import 'package:fitness_tracker/features/nutrition/presentation/food_picker.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

void main() {
  testWidgets('FoodPicker shows search results and calls onSelected on tap', (tester) async {
    final functions = MockFirebaseFunctions();
    final firestore = FakeFirebaseFirestore();
    final customFoodRepository = CustomFoodRepository(firestore: firestore);
    final searchService = FoodSearchService(functions: functions, customFoodRepository: customFoodRepository);

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

    FoodSearchResult? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: FoodPicker(
          uid: 'uid-1',
          searchService: searchService,
          onSelected: (r) => selected = r,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'rice');
    await tester.pumpAndSettle();

    expect(find.text('White Rice'), findsOneWidget);

    await tester.tap(find.text('White Rice'));
    await tester.pumpAndSettle();

    expect(selected?.name, 'White Rice');
  });

  testWidgets('FoodPicker offers to add a custom food when search has no results', (tester) async {
    final functions = MockFirebaseFunctions();
    final firestore = FakeFirebaseFirestore();
    final customFoodRepository = CustomFoodRepository(firestore: firestore);
    final searchService = FoodSearchService(functions: functions, customFoodRepository: customFoodRepository);

    final callable = MockHttpsCallable();
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('searchFood')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'results': []});

    await tester.pumpWidget(
      MaterialApp(
        home: FoodPicker(
          uid: 'uid-1',
          searchService: searchService,
          onSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Nordic Curl Stew');
    await tester.pumpAndSettle();

    expect(find.textContaining('Add "Nordic Curl Stew"'), findsOneWidget);
  });
}
