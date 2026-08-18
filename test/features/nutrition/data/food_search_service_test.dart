import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/features/nutrition/data/custom_food_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/food_search_service.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_entry.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

void main() {
  group('FoodSearchService', () {
    late MockFirebaseFunctions functions;
    late FakeFirebaseFirestore firestore;
    late CustomFoodRepository customFoodRepository;
    late FoodSearchService service;

    setUp(() {
      functions = MockFirebaseFunctions();
      firestore = FakeFirebaseFirestore();
      customFoodRepository = CustomFoodRepository(firestore: firestore);
      service = FoodSearchService(functions: functions, customFoodRepository: customFoodRepository);
    });

    test('search merges Cloud Function results with matching custom foods', () async {
      await customFoodRepository.addCustom(
        'uid-1', name: 'Amma\'s Sambar', caloriesPer100g: 80,
        proteinPer100g: 4, carbsPer100g: 12, fatPer100g: 2);

      final callable = MockHttpsCallable();
      final result = MockHttpsCallableResult<Map<String, dynamic>>();
      when(() => functions.httpsCallable('searchFood')).thenReturn(callable);
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
      when(() => result.data).thenReturn({
        'results': [
          {
            'name': 'Sambar (canned)',
            'source': 'openFoodFacts',
            'caloriesPer100g': 70,
            'proteinPer100g': 3,
            'carbsPer100g': 10,
            'fatPer100g': 1,
          },
        ],
      });

      final results = await service.search('uid-1', 'sambar');

      expect(results, hasLength(2));
      expect(results.map((r) => r.name), containsAll(['Sambar (canned)', 'Amma\'s Sambar']));
      expect(
        results.firstWhere((r) => r.name == 'Amma\'s Sambar').source,
        FoodSource.custom,
      );
    });

    test('parseText calls parseFoodText and returns structured items', () async {
      final callable = MockHttpsCallable();
      final result = MockHttpsCallableResult<Map<String, dynamic>>();
      when(() => functions.httpsCallable('parseFoodText')).thenReturn(callable);
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
      when(() => result.data).thenReturn({
        'items': [
          {'foodName': 'Idli', 'estimatedQuantityGrams': 150},
        ],
      });

      final items = await service.parseText('2 idlis');

      expect(items, hasLength(1));
      expect(items.first.foodName, 'Idli');
      expect(items.first.estimatedQuantityGrams, 150);
    });

    test('estimateNutrition calls estimateNutrition and tags the result as llmEstimated', () async {
      final callable = MockHttpsCallable();
      final result = MockHttpsCallableResult<Map<String, dynamic>>();
      when(() => functions.httpsCallable('estimateNutrition')).thenReturn(callable);
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
      when(() => result.data).thenReturn({
        'caloriesPer100g': 195,
        'proteinPer100g': 6,
        'carbsPer100g': 40,
        'fatPer100g': 1.5,
      });

      final estimate = await service.estimateNutrition('Idli');

      expect(estimate.name, 'Idli');
      expect(estimate.source, FoodSource.llmEstimated);
      expect(estimate.caloriesPer100g, 195);
    });
  });
}
