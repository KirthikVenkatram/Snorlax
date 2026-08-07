import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/nutrition_goal_calculator.dart';
import 'package:fitness_tracker/features/auth/data/user_profile_repository.dart';

void main() {
  test('saveProfile writes to users/{uid} and getProfile reads it back', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = UserProfileRepository(firestore: firestore);

    final profile = UserProfile(
      age: 28,
      weightKg: 75,
      heightCm: 178,
      sex: Sex.male,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.maintain,
      targets: NutritionGoalCalculator.calculate(
        weightKg: 75,
        heightCm: 178,
        age: 28,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
      ),
    );

    await repository.saveProfile('uid-123', profile);
    final result = await repository.getProfile('uid-123');

    expect(result, isNotNull);
    expect(result!.age, 28);
    expect(result.targets.calories, profile.targets.calories);

    final doc = await firestore.collection('users').doc('uid-123').get();
    expect(doc.exists, isTrue);
  });

  test('getProfile returns null when no profile exists', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = UserProfileRepository(firestore: firestore);

    final result = await repository.getProfile('missing-uid');

    expect(result, isNull);
  });
}
