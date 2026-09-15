import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/food_search_service.dart';
import '../data/nutrition_repository.dart';
import '../data/recipe_repository.dart';
import '../domain/food_entry.dart';
import '../domain/food_search_result.dart';
import '../domain/recipe.dart';

/// South-Indian-leaning seed ingredient list per the design handoff (Screen
/// 9) — a starting checklist, not an exhaustive ingredient database.
const _ingredientChecklist = [
  'Toor dal',
  'Tamarind pulp',
  'Groundnut oil',
  'Onion',
  'Drumstick',
  'Sambar powder',
  'Curry leaves',
  'Mustard seeds',
  'Tomato',
  'Coconut',
  'Rice',
  'Ghee',
];

/// Recipe builder — Slice A, Screen 9 of the glass-UI handoff. Ingredient
/// macros come from [FoodSearchService.estimateNutrition] (the app's
/// existing LLM nutrition-estimation path); each selected ingredient is
/// assumed to contribute a 100g portion to the batch — there's no per-
/// ingredient quantity input in the handoff's checklist UI, so this is a
/// deliberate simplification (see docs/superpowers/ISSUES.md).
class RecipeBuilderScreen extends StatefulWidget {
  const RecipeBuilderScreen({
    super.key,
    required this.uid,
    required this.date,
    required this.searchService,
    required this.recipeRepository,
    required this.nutritionRepository,
    required this.onSaved,
  });

  final String uid;
  final DateTime date;
  final FoodSearchService searchService;
  final RecipeRepository recipeRepository;
  final NutritionRepository nutritionRepository;
  final VoidCallback onSaved;

  @override
  State<RecipeBuilderScreen> createState() => _RecipeBuilderScreenState();
}

class _RecipeBuilderScreenState extends State<RecipeBuilderScreen> {
  final _nameController = TextEditingController();
  int _servings = 4;
  final Set<String> _selected = {};
  final Map<String, FoodSearchResult> _estimates = {};
  final Set<String> _loading = {};
  bool _saving = false;
  String? _error;

  static const _assumedGramsPerIngredient = 100.0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _toggle(String ingredient) async {
    setState(() {
      if (_selected.contains(ingredient)) {
        _selected.remove(ingredient);
      } else {
        _selected.add(ingredient);
      }
    });
    if (_selected.contains(ingredient) && !_estimates.containsKey(ingredient)) {
      setState(() => _loading.add(ingredient));
      try {
        final estimate = await widget.searchService.estimateNutrition(ingredient);
        if (!mounted) return;
        setState(() => _estimates[ingredient] = estimate);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _selected.remove(ingredient);
          _error = 'Could not look up "$ingredient". Try another ingredient.';
        });
      } finally {
        if (mounted) setState(() => _loading.remove(ingredient));
      }
    }
  }

  ({double calories, double protein, double carbs, double fat}) get _totals {
    var calories = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0;
    for (final ingredient in _selected) {
      final estimate = _estimates[ingredient];
      if (estimate == null) continue;
      final scale = _assumedGramsPerIngredient / 100;
      calories += estimate.caloriesPer100g * scale;
      protein += estimate.proteinPer100g * scale;
      carbs += estimate.carbsPer100g * scale;
      fat += estimate.fatPer100g * scale;
    }
    return (calories: calories, protein: protein, carbs: carbs, fat: fat);
  }

  bool get _isEstimating => _loading.isNotEmpty;

  Future<void> _saveAndLog() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selected.isEmpty || _isEstimating) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final totals = _totals;
      final recipe = await widget.recipeRepository.save(
        widget.uid,
        Recipe(
          id: '',
          name: name,
          servings: _servings,
          ingredientNames: _selected.toList(),
          totalCalories: totals.calories,
          totalProteinG: totals.protein,
          totalCarbsG: totals.carbs,
          totalFatG: totals.fat,
        ),
      );
      await widget.nutritionRepository.logFood(
        uid: widget.uid,
        date: widget.date,
        // No meal-type selector in this screen's design (Screen 9 handoff);
        // Snack is a reasonable default for a single ad-hoc serving — see
        // docs/superpowers/ISSUES.md.
        mealType: MealType.snack,
        foodName: recipe.name,
        quantityGrams: _selected.length * _assumedGramsPerIngredient / _servings,
        calories: recipe.caloriesPerServing,
        proteinG: recipe.proteinPerServing,
        carbsG: recipe.carbsPerServing,
        fatG: recipe.fatPerServing,
        source: FoodSource.recipe,
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save this recipe. Please try again.');
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final totals = _totals;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  Text('Recipe', style: Theme.of(context).textTheme.headlineMedium),
                  const Spacer(),
                  Material(
                    color: AppColors.glassFill,
                    shape: const StadiumBorder(side: BorderSide(color: AppColors.glassStroke)),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        child: Text('Cancel', style: TextStyle(color: AppColors.textPrimary)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Name',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('recipeNameField'),
                      controller: _nameController,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Servings this makes',
                                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Macros below are per serving',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        _ServingStepperButton(
                          key: const Key('servingsDecrement'),
                          icon: Icons.remove,
                          onTap: _servings > 1 ? () => setState(() => _servings--) : null,
                        ),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$_servings',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        _ServingStepperButton(
                          key: const Key('servingsIncrement'),
                          icon: Icons.add,
                          onTap: () => setState(() => _servings++),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'INGREDIENTS · ${_selected.length} ADDED',
                style: AppTypography.mono(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              for (final ingredient in _ingredientChecklist)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _IngredientRow(
                    label: ingredient,
                    selected: _selected.contains(ingredient),
                    loading: _loading.contains(ingredient),
                    caloriesPer100g: _estimates[ingredient]?.caloriesPer100g,
                    onTap: () => _toggle(ingredient),
                  ),
                ),
              const SizedBox(height: 6),
              GlassCard(
                glowColor: AppColors.accentGreen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Per serving',
                      style: TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_servings <= 0 ? totals.calories : totals.calories / _servings).toStringAsFixed(0)} kcal',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'P ${(totals.protein / _servings).toStringAsFixed(0)}g · '
                      'C ${(totals.carbs / _servings).toStringAsFixed(0)}g · '
                      'F ${(totals.fat / _servings).toStringAsFixed(0)}g',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 20),
              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : PrimaryButton(
                      label: 'Save and log one serving',
                      onPressed: _nameController.text.trim().isEmpty ||
                              _selected.isEmpty ||
                              _isEstimating
                          ? null
                          : _saveAndLog,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width ingredient checklist row per Screen 9 of the handoff: name +
/// "{grams}g · {kcal} kcal" detail line on the left, a circular +/− toggle
/// on the right — selected rows tint green. Replaces an earlier Wrap-of-
/// chips layout that didn't match the screenshot's list-of-rows structure.
class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.label,
    required this.selected,
    required this.loading,
    required this.caloriesPer100g,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool loading;

  /// Null until the estimate resolves (or if this ingredient was never
  /// selected) — the detail line shows a placeholder rather than a
  /// fabricated number while it's unknown.
  final double? caloriesPer100g;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentGreen.withValues(alpha: 0.14) : AppColors.glassFill,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caloriesPer100g == null
                          ? (selected ? 'Looking up…' : '100g serving')
                          : '100 g · ${caloriesPer100g!.toStringAsFixed(0)} kcal',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accentGreen : AppColors.glassFillStrong,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    selected ? Icons.remove : Icons.add,
                    size: 18,
                    color: selected ? Colors.black : AppColors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The round +/− buttons on the servings stepper, per Screen 9.
class _ServingStepperButton extends StatelessWidget {
  const _ServingStepperButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: AppColors.glassFillStrong,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 18, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
