import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/nutrition_repository.dart';
import '../domain/food_entry.dart';

class FoodEntryDetailScreen extends StatefulWidget {
  const FoodEntryDetailScreen({
    super.key,
    required this.uid,
    required this.entry,
    required this.nutritionRepository,
    required this.onChanged,
  });

  final String uid;
  final FoodEntry entry;
  final NutritionRepository nutritionRepository;
  final VoidCallback onChanged;

  @override
  State<FoodEntryDetailScreen> createState() => _FoodEntryDetailScreenState();
}

class _FoodEntryDetailScreenState extends State<FoodEntryDetailScreen> {
  late final _quantityController =
      TextEditingController(text: widget.entry.quantityGrams.toStringAsFixed(0));
  late MealType _mealType = widget.entry.mealType;

  /// Per-gram nutrition rate derived from the entry as originally logged,
  /// so editing quantity rescales macros consistently without needing to
  /// re-query the original food source.
  ///
  /// Guarded against a zero (or negative) `quantityGrams` on the original
  /// entry, which would otherwise divide out to Infinity/NaN and persist
  /// that into Firestore on save. Such an entry shouldn't be logged in the
  /// first place (see the `<= 0` guards in log_food_screen.dart), but this
  /// keeps editing a pre-existing bad entry safe as defense in depth.
  double get _caloriesPerGram =>
      widget.entry.quantityGrams <= 0 ? 0 : widget.entry.calories / widget.entry.quantityGrams;
  double get _proteinPerGram =>
      widget.entry.quantityGrams <= 0 ? 0 : widget.entry.proteinG / widget.entry.quantityGrams;
  double get _carbsPerGram =>
      widget.entry.quantityGrams <= 0 ? 0 : widget.entry.carbsG / widget.entry.quantityGrams;
  double get _fatPerGram =>
      widget.entry.quantityGrams <= 0 ? 0 : widget.entry.fatG / widget.entry.quantityGrams;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final grams = double.tryParse(_quantityController.text);
    if (grams == null || grams <= 0) return;

    widget.nutritionRepository
        .updateFoodEntry(
          uid: widget.uid,
          entryId: widget.entry.id,
          mealType: _mealType,
          quantityGrams: grams,
          calories: _caloriesPerGram * grams,
          proteinG: _proteinPerGram * grams,
          carbsG: _carbsPerGram * grams,
          fatG: _fatPerGram * grams,
        )
        .then((_) {}, onError: (Object error) => debugPrint('Failed to update food entry: $error'));
    if (!mounted) return;
    widget.onChanged();
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    widget.nutritionRepository
        .deleteFoodEntry(widget.uid, widget.entry.id)
        .then((_) {}, onError: (Object error) => debugPrint('Failed to delete food entry: $error'));
    if (!mounted) return;
    widget.onChanged();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.foodName),
        actions: [IconButton(icon: const Icon(Icons.delete), onPressed: _delete)],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButton<MealType>(
                  value: _mealType,
                  items: MealType.values
                      .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                      .toList(),
                  onChanged: (m) => setState(() => _mealType = m ?? _mealType),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('quantityGramsField'),
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity (grams)'),
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Save changes', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
