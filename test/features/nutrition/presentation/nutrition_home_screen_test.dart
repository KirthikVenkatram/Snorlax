import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/features/auth/data/user_profile_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/custom_food_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/food_search_service.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/recipe_repository.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_entry.dart';
import 'package:fitness_tracker/features/nutrition/presentation/nutrition_home_screen.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

void main() {
  testWidgets('shows today\'s food log grouped by meal with a day total', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
          recipeRepository: RecipeRepository(firestore: firestore),
          userProfileRepository: UserProfileRepository(firestore: firestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Idli'), findsOneWidget);
    expect(find.textContaining('195'), findsWidgets);
  });

  testWidgets('shows an empty state with no entries today', (tester) async {

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
          recipeRepository: RecipeRepository(firestore: firestore),
          userProfileRepository: UserProfileRepository(firestore: firestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No food logged yet today.'), findsOneWidget);
  });

  testWidgets('shows macro totals against macro goals', (tester) async {

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final firestore = FakeFirebaseFirestore();
    final nutritionRepository = NutritionRepository(firestore: firestore);
    final searchService = FoodSearchService(
      functions: MockFirebaseFunctions(),
      customFoodRepository: CustomFoodRepository(firestore: firestore),
    );

    await nutritionRepository.setGoals(
      'uid-1',
      const NutritionGoals(dailyCalories: 2000, proteinG: 150, carbsG: 200, fatG: 60),
    );
    await nutritionRepository.logFood(
      uid: 'uid-1', date: DateTime.now(), mealType: MealType.breakfast,
      foodName: 'Idli', quantityGrams: 150, calories: 195, proteinG: 45,
      carbsG: 120, fatG: 30, source: FoodSource.custom);

    await tester.pumpWidget(
      MaterialApp(
        home: NutritionHomeScreen(
          uid: 'uid-1',
          nutritionRepository: nutritionRepository,
          searchService: searchService,
          recipeRepository: RecipeRepository(firestore: firestore),
          userProfileRepository: UserProfileRepository(firestore: firestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Goal: 2000 kcal'), findsOneWidget);
    // Macro totals now render as labelled rings rather than text rows.
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('Carbs'), findsOneWidget);
    expect(find.text('Fat'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    // Per-entry macros are shown too.
    expect(find.textContaining('P 45g · C 120g · F 30g'), findsOneWidget);
  });

  testWidgets('goal progress shows even with zero entries logged', (tester) async {

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final firestore = FakeFirebaseFirestore();
    final nutritionRepository = NutritionRepository(firestore: firestore);
    final searchService = FoodSearchService(
      functions: MockFirebaseFunctions(),
      customFoodRepository: CustomFoodRepository(firestore: firestore),
    );

    await nutritionRepository.setGoals(
      'uid-1',
      const NutritionGoals(dailyCalories: 2000, proteinG: 150, carbsG: 200, fatG: 60),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NutritionHomeScreen(
          uid: 'uid-1',
          nutritionRepository: nutritionRepository,
          searchService: searchService,
          recipeRepository: RecipeRepository(firestore: firestore),
          userProfileRepository: UserProfileRepository(firestore: firestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Goal: 2000 kcal'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('Carbs'), findsOneWidget);
    expect(find.text('Fat'), findsOneWidget);
    // All three macro rings show 0 (water renders as a combined "0 / X ml" string, not a bare "0").
    expect(find.text('0'), findsNWidgets(3));
    expect(find.text('0 kcal'), findsOneWidget);
    // ...and the empty-state message sits below the card, not instead of it.
    expect(find.text('No food logged yet today.'), findsOneWidget);
  });

  testWidgets('empty-state copy drops "today" when viewing another day', (tester) async {

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
          recipeRepository: RecipeRepository(firestore: firestore),
          userProfileRepository: UserProfileRepository(firestore: firestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('No food logged yet.'), findsOneWidget);
    expect(find.text('No food logged yet today.'), findsNothing);
  });
}
