// lib/core/calculations/nutrition_goal_calculator.dart

enum Sex { male, female }

enum ActivityLevel {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  active(1.725),
  veryActive(1.9);

  const ActivityLevel(this.multiplier);
  final double multiplier;
}

enum Goal { lose, maintain, gain }

class NutritionTargets {
  const NutritionTargets({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
  });

  final int calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
}

/// Computes daily calorie/macro targets using the Mifflin-St Jeor equation
/// for BMR, scaled by activity level to get TDEE, then adjusted for the
/// user's goal. Macros are split protein-first (2g/kg bodyweight), then
/// fat at 25% of total calories, with the remainder as carbs.
class NutritionGoalCalculator {
  NutritionGoalCalculator._();

  static NutritionTargets calculate({
    required double weightKg,
    required double heightCm,
    required int age,
    required Sex sex,
    required ActivityLevel activityLevel,
    required Goal goal,
  }) {
    final sexOffset = sex == Sex.male ? 5 : -161;
    final bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + sexOffset;
    final tdee = bmr * activityLevel.multiplier;

    final goalAdjustment = switch (goal) {
      Goal.lose => -500,
      Goal.maintain => 0,
      Goal.gain => 500,
    };

    final calories = (tdee + goalAdjustment).round();

    final proteinGrams = weightKg * 2;
    final fatGrams = (calories * 0.25) / 9;
    final proteinCalories = proteinGrams * 4;
    final fatCalories = fatGrams * 9;
    final carbsGrams = (calories - proteinCalories - fatCalories) / 4;

    return NutritionTargets(
      calories: calories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
    );
  }
}
