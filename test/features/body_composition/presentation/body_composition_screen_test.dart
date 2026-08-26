import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/nutrition_goal_calculator.dart';
import 'package:fitness_tracker/features/auth/data/user_profile_repository.dart';
import 'package:fitness_tracker/features/body_composition/data/body_composition_repository.dart';
import 'package:fitness_tracker/features/body_composition/domain/body_measurement.dart';
import 'package:fitness_tracker/features/body_composition/presentation/body_composition_screen.dart';

const maleProfile = UserProfile(
  age: 30,
  weightKg: 80,
  heightCm: 178,
  sex: Sex.male,
  activityLevel: ActivityLevel.moderate,
  goal: Goal.maintain,
  targets: NutritionTargets(
    calories: 2600,
    proteinGrams: 150,
    carbsGrams: 300,
    fatGrams: 70,
  ),
);

const femaleProfile = UserProfile(
  age: 28,
  weightKg: 65,
  heightCm: 165,
  sex: Sex.female,
  activityLevel: ActivityLevel.light,
  goal: Goal.lose,
  targets: NutritionTargets(
    calories: 1800,
    proteinGrams: 120,
    carbsGrams: 180,
    fatGrams: 55,
  ),
);

void main() {
  testWidgets('body screen records a measurement and displays an estimate disclaimer', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = BodyCompositionRepository(firestore: firestore);

    await tester.pumpWidget(
      MaterialApp(
        home: BodyCompositionScreen(
          uid: 'u',
          profile: maleProfile,
          repository: repository,
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('estimate'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('weightField')), '80');
    await tester.enterText(find.byKey(const Key('waistField')), '90');
    await tester.enterText(find.byKey(const Key('neckField')), '38');
    await tester.ensureVisible(find.text('Save check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    expect(await repository.listMeasurements('u', BodyMetric.weight), isNotEmpty);
  });

  testWidgets('creates a body-composition estimate when enough inputs are supplied for a male profile',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = BodyCompositionRepository(firestore: firestore);

    await tester.pumpWidget(
      MaterialApp(
        home: BodyCompositionScreen(
          uid: 'u',
          profile: maleProfile,
          repository: repository,
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('weightField')), '80');
    await tester.enterText(find.byKey(const Key('waistField')), '90');
    await tester.enterText(find.byKey(const Key('neckField')), '38');
    await tester.ensureVisible(find.text('Save check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    expect(await repository.listEstimates('u'), isNotEmpty);
  });

  testWidgets(
      'does not create an estimate (and does not throw) for a female profile missing hip circumference',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = BodyCompositionRepository(firestore: firestore);

    await tester.pumpWidget(
      MaterialApp(
        home: BodyCompositionScreen(
          uid: 'u',
          profile: femaleProfile,
          repository: repository,
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('weightField')), '65');
    await tester.enterText(find.byKey(const Key('waistField')), '75');
    await tester.enterText(find.byKey(const Key('neckField')), '32');
    await tester.ensureVisible(find.text('Save check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    expect(await repository.listMeasurements('u', BodyMetric.weight), isNotEmpty);
    expect(await repository.listEstimates('u'), isEmpty);
  });
}
