import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/nutrition_goal_calculator.dart';
import 'package:fitness_tracker/features/auth/data/user_profile_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/nutrition/domain/food_entry.dart';
import 'package:fitness_tracker/features/nutrition/presentation/nutrition_goals_screen.dart';

void main() {
  testWidgets('saving valid goals writes them and calls onSaved', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = NutritionRepository(firestore: firestore);

    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: NutritionGoalsScreen(
          uid: 'uid-1',
          nutritionRepository: repository,
          onSaved: () => saved = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('caloriesField')), '2000');
    await tester.enterText(find.byKey(const Key('proteinField')), '150');
    await tester.enterText(find.byKey(const Key('carbsField')), '200');
    await tester.enterText(find.byKey(const Key('fatField')), '60');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save goals'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    final goals = await repository.getGoals('uid-1');
    expect(goals!.dailyCalories, 2000);
    expect(goals.proteinG, 150);
  });

  testWidgets('with no saved goals, pre-fills from onboarding-computed targets',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = NutritionRepository(firestore: firestore);
    final profileRepository = UserProfileRepository(firestore: firestore);

    await profileRepository.saveProfile(
      'uid-1',
      const UserProfile(
        age: 30,
        weightKg: 75,
        heightCm: 180,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
        targets: NutritionTargets(
          calories: 2650,
          proteinGrams: 150,
          carbsGrams: 310,
          fatGrams: 73.6,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NutritionGoalsScreen(
          uid: 'uid-1',
          nutritionRepository: repository,
          userProfileRepository: profileRepository,
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2650'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.text('310'), findsOneWidget);
    expect(find.text('74'), findsOneWidget);
  });

  testWidgets('saved goals win over onboarding-computed targets', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = NutritionRepository(firestore: firestore);
    final profileRepository = UserProfileRepository(firestore: firestore);

    await repository.setGoals(
      'uid-1',
      const NutritionGoals(dailyCalories: 1800, proteinG: 140, carbsG: 180, fatG: 50),
    );
    await profileRepository.saveProfile(
      'uid-1',
      const UserProfile(
        age: 30,
        weightKg: 75,
        heightCm: 180,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
        targets: NutritionTargets(
          calories: 2650,
          proteinGrams: 150,
          carbsGrams: 310,
          fatGrams: 73.6,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NutritionGoalsScreen(
          uid: 'uid-1',
          nutritionRepository: repository,
          userProfileRepository: profileRepository,
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1800'), findsOneWidget);
    expect(find.text('2650'), findsNothing);
  });
}
