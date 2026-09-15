import 'food_entry.dart';
import 'recipe.dart';

/// A row in Log food's "FREQUENT FOODS" catalog — a display-only shape that
/// unifies three sources: the user's own recent food-log entries, their
/// saved recipes, and a static seed catalog (see [kIndianCatalogSeed]).
class CatalogItem {
  const CatalogItem({
    required this.name,
    required this.tag,
    required this.servingLabel,
    required this.quantityGrams,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.source,
  });

  final String name;

  /// "Recipe" / "Scanned" per the handoff, or null for a plain catalog/recent
  /// item.
  final String? tag;
  final String servingLabel;
  final double quantityGrams;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final FoodSource source;

  factory CatalogItem.fromFoodEntry(FoodEntry entry) => CatalogItem(
        name: entry.foodName,
        tag: entry.source == FoodSource.recipe
            ? 'Recipe'
            : entry.source == FoodSource.openFoodFactsScanned
                ? 'Scanned'
                : null,
        servingLabel: '${entry.quantityGrams.toStringAsFixed(0)}g',
        quantityGrams: entry.quantityGrams,
        calories: entry.calories,
        proteinG: entry.proteinG,
        carbsG: entry.carbsG,
        fatG: entry.fatG,
        source: entry.source,
      );

  factory CatalogItem.fromRecipe(Recipe recipe) => CatalogItem(
        name: recipe.name,
        tag: 'Recipe',
        servingLabel: '1 serving',
        quantityGrams: 0,
        calories: recipe.caloriesPerServing,
        proteinG: recipe.proteinPerServing,
        carbsG: recipe.carbsPerServing,
        fatG: recipe.fatPerServing,
        source: FoodSource.recipe,
      );
}

/// Indian-first seed catalog from the design handoff (Screen 7). Macros
/// beyond the handoff's kcal figures are reasonable estimates, not verified
/// nutrition data — see docs/superpowers/ISSUES.md.
const kIndianCatalogSeed = [
  CatalogItem(
    name: 'Idli',
    tag: null,
    servingLabel: '2 pcs',
    quantityGrams: 80,
    calories: 156,
    proteinG: 4,
    carbsG: 30,
    fatG: 1,
    source: FoodSource.custom,
  ),
  CatalogItem(
    name: 'Sambar',
    tag: null,
    servingLabel: '1 bowl',
    quantityGrams: 150,
    calories: 120,
    proteinG: 5,
    carbsG: 15,
    fatG: 3,
    source: FoodSource.custom,
  ),
  CatalogItem(
    name: 'Filter coffee',
    tag: null,
    servingLabel: '1 cup',
    quantityGrams: 150,
    calories: 90,
    proteinG: 2,
    carbsG: 10,
    fatG: 4,
    source: FoodSource.custom,
  ),
  CatalogItem(
    name: 'Whey shake',
    tag: null,
    servingLabel: '1 scoop',
    quantityGrams: 300,
    calories: 122,
    proteinG: 24,
    carbsG: 4,
    fatG: 1,
    source: FoodSource.custom,
  ),
  CatalogItem(
    name: 'Curd rice',
    tag: null,
    servingLabel: '1 bowl',
    quantityGrams: 200,
    calories: 210,
    proteinG: 6,
    carbsG: 35,
    fatG: 5,
    source: FoodSource.custom,
  ),
  CatalogItem(
    name: 'Chicken curry',
    tag: null,
    servingLabel: '1 serving',
    quantityGrams: 200,
    calories: 280,
    proteinG: 22,
    carbsG: 8,
    fatG: 18,
    source: FoodSource.custom,
  ),
  CatalogItem(
    name: 'Masala dosa',
    tag: null,
    servingLabel: '1 pc',
    quantityGrams: 120,
    calories: 168,
    proteinG: 4,
    carbsG: 25,
    fatG: 6,
    source: FoodSource.custom,
  ),
  CatalogItem(
    name: 'Egg bhurji',
    tag: null,
    servingLabel: '1 serving',
    quantityGrams: 150,
    calories: 245,
    proteinG: 14,
    carbsG: 4,
    fatG: 19,
    source: FoodSource.custom,
  ),
];

/// Builds the "FREQUENT FOODS" list: the user's most-recently-logged
/// distinct foods first (real usage beats a static guess), then their saved
/// recipes, then the static seed catalog to fill out the section — deduped
/// by name (case-insensitive, first occurrence wins) and capped at [limit].
///
/// [recentLogNewestFirst] must already be sorted newest first (as
/// `NutritionRepository.listFoodLog` returns it) — this function does not
/// re-sort, it only dedupes and caps.
List<CatalogItem> buildFrequentFoods({
  required List<FoodEntry> recentLogNewestFirst,
  required List<Recipe> recipes,
  int limit = 8,
}) {
  final seen = <String>{};
  final result = <CatalogItem>[];

  void addIfNew(CatalogItem item) {
    final key = item.name.toLowerCase();
    if (seen.add(key)) result.add(item);
  }

  for (final entry in recentLogNewestFirst) {
    if (result.length >= limit) break;
    addIfNew(CatalogItem.fromFoodEntry(entry));
  }
  for (final recipe in recipes) {
    if (result.length >= limit) break;
    addIfNew(CatalogItem.fromRecipe(recipe));
  }
  for (final seed in kIndianCatalogSeed) {
    if (result.length >= limit) break;
    addIfNew(seed);
  }
  return result;
}
