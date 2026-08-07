// test/core/calculations/nutrition_goal_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/nutrition_goal_calculator.dart';

void main() {
  group('NutritionGoalCalculator', () {
    test('computes maintenance calories for a moderately active male', () {
      final targets = NutritionGoalCalculator.calculate(
        weightKg: 75,
        heightCm: 178,
        age: 28,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
      );

      // Mifflin-St Jeor BMR = 10*75 + 6.25*178 - 5*28 + 5 = 1737.5
      // TDEE = BMR * 1.55 (moderate) = 2693.125 -> rounds to 2693
      expect(targets.calories, 2693);
      expect(targets.proteinGrams, closeTo(150, 1)); // ~2g/kg bodyweight
    });

    test('applies a 500 calorie deficit for a "lose" goal', () {
      final maintain = NutritionGoalCalculator.calculate(
        weightKg: 75,
        heightCm: 178,
        age: 28,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
      );
      final lose = NutritionGoalCalculator.calculate(
        weightKg: 75,
        heightCm: 178,
        age: 28,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.lose,
      );

      expect(maintain.calories - lose.calories, 500);
    });

    test('applies a 500 calorie surplus for a "gain" goal', () {
      final maintain = NutritionGoalCalculator.calculate(
        weightKg: 75,
        heightCm: 178,
        age: 28,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.maintain,
      );
      final gain = NutritionGoalCalculator.calculate(
        weightKg: 75,
        heightCm: 178,
        age: 28,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.gain,
      );

      expect(gain.calories - maintain.calories, 500);
    });
  });
}
