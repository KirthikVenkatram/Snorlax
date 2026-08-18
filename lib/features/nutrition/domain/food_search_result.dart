import 'food_entry.dart';

class FoodSearchResult {
  const FoodSearchResult({
    required this.name,
    required this.source,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });

  final String name;
  final FoodSource source;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  factory FoodSearchResult.fromCloudFunctionJson(Map<String, dynamic> json) {
    return FoodSearchResult(
      name: json['name'] as String,
      source: FoodSource.values.byName(json['source'] as String),
      caloriesPer100g: (json['caloriesPer100g'] as num).toDouble(),
      proteinPer100g: (json['proteinPer100g'] as num).toDouble(),
      carbsPer100g: (json['carbsPer100g'] as num).toDouble(),
      fatPer100g: (json['fatPer100g'] as num).toDouble(),
    );
  }
}

class ParsedFoodItem {
  const ParsedFoodItem({required this.foodName, required this.estimatedQuantityGrams});

  final String foodName;
  final double estimatedQuantityGrams;

  factory ParsedFoodItem.fromJson(Map<String, dynamic> json) {
    return ParsedFoodItem(
      foodName: json['foodName'] as String,
      estimatedQuantityGrams: (json['estimatedQuantityGrams'] as num).toDouble(),
    );
  }
}
