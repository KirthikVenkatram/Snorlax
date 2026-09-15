enum MealType { breakfast, lunch, dinner, snack }

enum FoodSource {
  usda,
  openFoodFacts,
  nutritionix,
  llmEstimated,
  custom,
  // Added for Slice A (scan food + recipe builder) — distinct from
  // `openFoodFacts` (server-side text search) and `custom` (user-typed
  // macros), since these two are logged through different client flows.
  openFoodFactsScanned,
  recipe,
}

class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.date,
    required this.mealType,
    required this.foodName,
    required this.quantityGrams,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.source,
  });

  final String id;
  final DateTime date;
  final MealType mealType;
  final String foodName;
  final double quantityGrams;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final FoodSource source;
}

class NutritionGoals {
  const NutritionGoals({
    required this.dailyCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final double dailyCalories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  Map<String, dynamic> toJson() => {
        'dailyCalories': dailyCalories,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
      };

  factory NutritionGoals.fromJson(Map<String, dynamic> json) => NutritionGoals(
        dailyCalories: (json['dailyCalories'] as num).toDouble(),
        proteinG: (json['proteinG'] as num).toDouble(),
        carbsG: (json['carbsG'] as num).toDouble(),
        fatG: (json['fatG'] as num).toDouble(),
      );
}
