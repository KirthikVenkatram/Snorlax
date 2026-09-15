/// A user-built recipe (Slice A recipe builder) — totals are for the whole
/// batch; [servings] divides them for the per-serving figures shown in the
/// UI and used when logging one serving.
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.servings,
    required this.ingredientNames,
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
  });

  final String id;
  final String name;
  final int servings;
  final List<String> ingredientNames;
  final double totalCalories;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;

  double get caloriesPerServing => servings <= 0 ? totalCalories : totalCalories / servings;
  double get proteinPerServing => servings <= 0 ? totalProteinG : totalProteinG / servings;
  double get carbsPerServing => servings <= 0 ? totalCarbsG : totalCarbsG / servings;
  double get fatPerServing => servings <= 0 ? totalFatG : totalFatG / servings;

  Map<String, dynamic> toJson() => {
        'name': name,
        'servings': servings,
        'ingredientNames': ingredientNames,
        'totalCalories': totalCalories,
        'totalProteinG': totalProteinG,
        'totalCarbsG': totalCarbsG,
        'totalFatG': totalFatG,
      };

  factory Recipe.fromJson(String id, Map<String, dynamic> json) => Recipe(
        id: id,
        name: json['name'] as String,
        servings: (json['servings'] as num).toInt(),
        ingredientNames: (json['ingredientNames'] as List).cast<String>(),
        totalCalories: (json['totalCalories'] as num).toDouble(),
        totalProteinG: (json['totalProteinG'] as num).toDouble(),
        totalCarbsG: (json['totalCarbsG'] as num).toDouble(),
        totalFatG: (json['totalFatG'] as num).toDouble(),
      );
}
