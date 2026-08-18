import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/features/nutrition/data/custom_food_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/food_search_service.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_entry.dart';
import 'package:fitness_tracker/features/nutrition/presentation/nutrition_home_screen.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

void main() {
  testWidgets('shows today\'s food log grouped by meal with a day total', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final nutritionRepository = NutritionRepository(firestore: firestore);
    final searchService = FoodSearchService(
      functions: MockFirebaseFunctions(),
      customFoodRepository: CustomFoodRepository(firestore: firestore),
    );

    final today = DateTime.now();
    await nutritionRepository.logFood(
      uid: 'uid-1', date: today, mealType: MealType.breakfast,
      foodName: 'Idli', quantityGrams: 150, calories: 195, proteinG: 6,
      carbsG: 40, fatG: 1.5, source: FoodSource.custom);

    await tester.pumpWidget(
      MaterialApp(
        home: NutritionHomeScreen(
          uid: 'uid-1',
          nutritionRepository: nutritionRepository,
          searchService: searchService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Idli'), findsOneWidget);
    expect(find.textContaining('195'), findsWidgets);
  });

  testWidgets('shows an empty state with no entries today', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final nutritionRepository = NutritionRepository(firestore: firestore);
    final searchService = FoodSearchService(
      functions: MockFirebaseFunctions(),
      customFoodRepository: CustomFoodRepository(firestore: firestore),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NutritionHomeScreen(
          uid: 'uid-1',
          nutritionRepository: nutritionRepository,
          searchService: searchService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No food logged yet today.'), findsOneWidget);
  });
}
