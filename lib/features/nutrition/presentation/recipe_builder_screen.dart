import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
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
      appBar: AppBar(title: const Text('Build a recipe'), backgroundColor: Colors.transparent),
      body: AmbientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const Key('recipeNameField'),
                      controller: _nameController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Recipe name',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text(
                          'Servings',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        IconButton(
                          key: const Key('servingsDecrement'),
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary),
                          onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
                        ),
                        Text(
                          '$_servings',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          key: const Key('servingsIncrement'),
                          icon: const Icon(Icons.add_circle_outline, color: AppColors.accentGreen),
                          onPressed: () => setState(() => _servings++),
                        ),
                      ],
                    ),
                    const Text(
                      'Macros below are per serving',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Ingredients · ${_selected.length} added',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              GlassCard(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ingredient in _ingredientChecklist)
                      _IngredientChip(
                        label: ingredient,
                        selected: _selected.contains(ingredient),
                        loading: _loading.contains(ingredient),
                        onTap: () => _toggle(ingredient),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
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

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({
    required this.label,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentGreen.withValues(alpha: 0.18) : AppColors.glassFill,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.accentGreen.withValues(alpha: 0.45) : AppColors.glassStroke,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.accentGreen : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
