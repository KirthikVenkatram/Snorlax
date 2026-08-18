import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/food_search_service.dart';
import '../data/nutrition_repository.dart';
import '../domain/food_entry.dart';
import '../domain/food_search_result.dart';
import 'food_picker.dart';

class LogFoodScreen extends StatefulWidget {
  const LogFoodScreen({
    super.key,
    required this.uid,
    required this.nutritionRepository,
    required this.searchService,
    required this.onSaved,
  });

  final String uid;
  final NutritionRepository nutritionRepository;
  final FoodSearchService searchService;
  final VoidCallback onSaved;

  @override
  State<LogFoodScreen> createState() => _LogFoodScreenState();
}

class _LogFoodScreenState extends State<LogFoodScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final _quantityController = TextEditingController(text: '100');
  final _naturalLanguageController = TextEditingController();

  MealType _mealType = MealType.breakfast;
  FoodSearchResult? _selectedFood;
  List<ParsedFoodItem> _parsedItems = [];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _tabController.dispose();
    _quantityController.dispose();
    _naturalLanguageController.dispose();
    super.dispose();
  }

  Future<void> _parseNaturalLanguage() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final items = await widget.searchService.parseText(_naturalLanguageController.text);
      if (!mounted) return;
      setState(() => _parsedItems = items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not parse that. Try again or use search instead.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveSelectedFood() async {
    final food = _selectedFood;
    final grams = double.tryParse(_quantityController.text);
    if (food == null || grams == null || grams <= 0) return;

    setState(() => _saving = true);
    final scale = grams / 100;
    widget.nutritionRepository
        .logFood(
          uid: widget.uid,
          date: DateTime.now(),
          mealType: _mealType,
          foodName: food.name,
          quantityGrams: grams,
          calories: food.caloriesPer100g * scale,
          proteinG: food.proteinPer100g * scale,
          carbsG: food.carbsPer100g * scale,
          fatG: food.fatPer100g * scale,
          source: food.source,
        )
        .then((_) {}, onError: (Object error) => debugPrint('Failed to log food: $error'));
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }

  Future<void> _saveParsedItems() async {
    setState(() => _saving = true);
    for (final item in _parsedItems) {
      FoodSearchResult resolved;
      try {
        final matches = await widget.searchService.search(widget.uid, item.foodName);
        resolved = matches.isNotEmpty
            ? matches.first
            : await widget.searchService.estimateNutrition(item.foodName);
      } catch (_) {
        resolved = await widget.searchService.estimateNutrition(item.foodName);
      }
      final scale = item.estimatedQuantityGrams / 100;
      // Fire-and-handle-errors rather than awaited: Firestore's offline
      // persistence updates the local cache immediately but the returned
      // Future doesn't resolve until the server acks, which never happens
      // offline — awaiting it here would hang this loop (and the UI)
      // indefinitely with no connectivity. The resolve-macros calls above
      // are Cloud Function calls and inherently require connectivity
      // already, so only this final write needs the fire-and-forget
      // treatment.
      widget.nutritionRepository
          .logFood(
            uid: widget.uid,
            date: DateTime.now(),
            mealType: _mealType,
            foodName: item.foodName,
            quantityGrams: item.estimatedQuantityGrams,
            calories: resolved.caloriesPer100g * scale,
            proteinG: resolved.proteinPer100g * scale,
            carbsG: resolved.carbsPer100g * scale,
            fatG: resolved.fatPer100g * scale,
            source: resolved.source,
          )
          .then((_) {}, onError: (Object error) => debugPrint('Failed to log food: $error'));
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log food'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Search'), Tab(text: 'Describe')],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildSearchTab(),
            _buildNaturalLanguageTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
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
          const SizedBox(height: 16),
          if (_selectedFood != null) ...[
            GlassCard(child: Text(_selectedFood!.name)),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: FoodPicker(
              uid: widget.uid,
              searchService: widget.searchService,
              onSelected: (result) => setState(() => _selectedFood = result),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('quantityGramsField'),
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity (grams)'),
          ),
          const SizedBox(height: 24),
          _saving
              ? const Center(child: CircularProgressIndicator())
              : PrimaryButton(
                  label: 'Save',
                  onPressed: _selectedFood == null ? null : _saveSelectedFood,
                ),
        ],
      ),
    );
  }

  Widget _buildNaturalLanguageTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        DropdownButton<MealType>(
          value: _mealType,
          items: MealType.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
              .toList(),
          onChanged: (m) => setState(() => _mealType = m ?? _mealType),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _naturalLanguageController,
          decoration: const InputDecoration(labelText: 'Describe what you ate'),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _parseNaturalLanguage, child: const Text('Parse')),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 16),
        for (final item in _parsedItems)
          GlassCard(
            child: Text('${item.foodName} — ${item.estimatedQuantityGrams.toStringAsFixed(0)}g'),
          ),
        const SizedBox(height: 24),
        _saving
            ? const Center(child: CircularProgressIndicator())
            : PrimaryButton(
                label: 'Save all',
                onPressed: _parsedItems.isEmpty ? null : _saveParsedItems,
              ),
      ],
    );
  }
}
