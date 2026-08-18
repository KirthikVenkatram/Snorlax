import 'package:flutter/material.dart';
import '../data/food_search_service.dart';
import '../domain/food_entry.dart';
import '../domain/food_search_result.dart';

class FoodPicker extends StatefulWidget {
  const FoodPicker({
    super.key,
    required this.uid,
    required this.searchService,
    required this.onSelected,
  });

  final String uid;
  final FoodSearchService searchService;
  final ValueChanged<FoodSearchResult> onSelected;

  @override
  State<FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<FoodPicker> {
  final _controller = TextEditingController();
  List<FoodSearchResult> _results = [];

  /// Incremented per search; a response is only applied if it belongs to
  /// the most recent request, so a slow early query can't clobber a newer one.
  int _searchToken = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final token = ++_searchToken;
    try {
      final results = await widget.searchService.search(widget.uid, query);
      if (!mounted || token != _searchToken) return;
      setState(() => _results = results);
    } catch (error) {
      debugPrint('Food search failed: $error');
    }
  }

  Future<void> _addCustom(String name) async {
    // A custom food's macros are entered on the dedicated add-custom form
    // this picker navigates to, not inline here, since the form needs
    // several numeric fields.
    final repository = widget.searchService.customFoodRepository;
    final macros = await Navigator.of(context).push<Map<String, double>>(
      MaterialPageRoute(builder: (_) => _AddCustomFoodForm(name: name)),
    );
    if (macros == null) return;
    final food = await repository.addCustom(
      widget.uid,
      name: name,
      caloriesPer100g: macros['calories']!,
      proteinPer100g: macros['protein']!,
      carbsPer100g: macros['carbs']!,
      fatPer100g: macros['fat']!,
    );
    widget.onSelected(FoodSearchResult(
      name: food.name,
      source: FoodSource.custom,
      caloriesPer100g: food.caloriesPer100g,
      proteinPer100g: food.proteinPer100g,
      carbsPer100g: food.carbsPer100g,
      fatPer100g: food.fatPer100g,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();

    return Material(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(labelText: 'Search foods'),
            onChanged: _search,
          ),
          Expanded(
            child: ListView(
              children: [
                for (final result in _results)
                  ListTile(
                    title: Text(result.name),
                    subtitle: Text('${result.caloriesPer100g.toStringAsFixed(0)} kcal/100g'),
                    onTap: () => widget.onSelected(result),
                  ),
                if (query.isNotEmpty)
                  ListTile(
                    title: Text('Add "$query"'),
                    onTap: () => _addCustom(query),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCustomFoodForm extends StatefulWidget {
  const _AddCustomFoodForm({required this.name});

  final String name;

  @override
  State<_AddCustomFoodForm> createState() => _AddCustomFoodFormState();
}

class _AddCustomFoodFormState extends State<_AddCustomFoodForm> {
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _save() {
    final calories = double.tryParse(_caloriesController.text);
    final protein = double.tryParse(_proteinController.text);
    final carbs = double.tryParse(_carbsController.text);
    final fat = double.tryParse(_fatController.text);
    if (calories == null || protein == null || carbs == null || fat == null) return;
    Navigator.of(context).pop({
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add "${widget.name}"')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calories per 100g'),
            ),
            TextField(
              controller: _proteinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Protein (g) per 100g'),
            ),
            TextField(
              controller: _carbsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Carbs (g) per 100g'),
            ),
            TextField(
              controller: _fatController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Fat (g) per 100g'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
