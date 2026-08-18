import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/food_search_service.dart';
import '../data/nutrition_repository.dart';
import '../domain/food_entry.dart';
import 'log_food_screen.dart';

class NutritionHomeScreen extends StatefulWidget {
  const NutritionHomeScreen({
    super.key,
    required this.uid,
    required this.nutritionRepository,
    required this.searchService,
  });

  final String uid;
  final NutritionRepository nutritionRepository;
  final FoodSearchService searchService;

  @override
  State<NutritionHomeScreen> createState() => _NutritionHomeScreenState();
}

class _NutritionHomeScreenState extends State<NutritionHomeScreen> {
  DateTime _selectedDate = DateTime.now();
  late Future<List<FoodEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _entriesFuture = widget.nutritionRepository.listFoodLog(widget.uid);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _openLogFood() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogFoodScreen(
          uid: widget.uid,
          nutritionRepository: widget.nutritionRepository,
          searchService: widget.searchService,
          onSaved: () {
            Navigator.of(context).pop();
            _refresh();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() =>
                _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() =>
                _selectedDate = _selectedDate.add(const Duration(days: 1))),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Log food',
        onPressed: _openLogFood,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<List<FoodEntry>>(
            future: _entriesFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = snapshot.data!
                  .where((e) => _isSameDay(e.date, _selectedDate))
                  .toList();
              if (entries.isEmpty) {
                return const Center(child: Text('No food logged yet today.'));
              }

              final totalCalories = entries.fold<double>(0, (sum, e) => sum + e.calories);

              return ListView(
                children: [
                  GlassCard(child: Text('Total: ${totalCalories.toStringAsFixed(0)} kcal')),
                  const SizedBox(height: 16),
                  for (final mealType in MealType.values) ...[
                    for (final entry in entries.where((e) => e.mealType == mealType))
                      GlassCard(
                        child: ListTile(
                          title: Text(entry.foodName),
                          subtitle: Text(
                            '${mealType.name} · ${entry.quantityGrams.toStringAsFixed(0)}g · ${entry.calories.toStringAsFixed(0)} kcal',
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
