import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../auth/data/user_profile_repository.dart';
import '../data/food_search_service.dart';
import '../data/nutrition_repository.dart';
import '../domain/food_entry.dart';
import 'food_entry_detail_screen.dart';
import 'log_food_screen.dart';
import 'nutrition_goals_screen.dart';

class NutritionHomeScreen extends StatefulWidget {
  const NutritionHomeScreen({
    super.key,
    required this.uid,
    required this.nutritionRepository,
    required this.searchService,
    required this.userProfileRepository,
  });

  final String uid;
  final NutritionRepository nutritionRepository;
  final FoodSearchService searchService;

  /// Used only to pre-fill the nutrition goals screen from the targets
  /// computed during onboarding when the user has not saved goals yet.
  final UserProfileRepository userProfileRepository;

  @override
  State<NutritionHomeScreen> createState() => _NutritionHomeScreenState();
}

class _NutritionHomeScreenState extends State<NutritionHomeScreen> {
  DateTime _selectedDate = DateTime.now();
  late Future<List<FoodEntry>> _entriesFuture;
  late Future<NutritionGoals?> _goalsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _entriesFuture = widget.nutritionRepository.listFoodLog(widget.uid);
      _goalsFuture = widget.nutritionRepository.getGoals(widget.uid);
    });
  }

  /// One line of the macro summary, e.g. `Protein: 45 / 150 g`.
  Widget _macroRow(BuildContext context, String label, double total, double goal) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '$label: ${total.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} g',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
      ),
    );
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
          date: _selectedDate,
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
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Goals',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NutritionGoalsScreen(
                    uid: widget.uid,
                    nutritionRepository: widget.nutritionRepository,
                    userProfileRepository: widget.userProfileRepository,
                    onSaved: () => Navigator.of(context).pop(),
                  ),
                ),
              );
              _refresh();
            },
          ),
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
              final textTheme = Theme.of(context).textTheme;
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load food log.',
                    style: textTheme.bodyLarge?.copyWith(color: AppColors.error),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = snapshot.data!
                  .where((e) => _isSameDay(e.date, _selectedDate))
                  .toList();
              // Totals fold over an empty list to zero, so the summary card
              // below renders goal progress even on a day with nothing
              // logged yet — the empty-state message is content under the
              // card rather than a replacement for the whole screen.
              final totalCalories = entries.fold<double>(0, (sum, e) => sum + e.calories);
              final totalProtein = entries.fold<double>(0, (sum, e) => sum + e.proteinG);
              final totalCarbs = entries.fold<double>(0, (sum, e) => sum + e.carbsG);
              final totalFat = entries.fold<double>(0, (sum, e) => sum + e.fatG);

              return ListView(
                children: [
                  FutureBuilder<NutritionGoals?>(
                    future: _goalsFuture,
                    builder: (context, goalsSnapshot) {
                      final goals = goalsSnapshot.data;
                      final progress = goals == null || goals.dailyCalories == 0
                          ? 0.0
                          : (totalCalories / goals.dailyCalories).clamp(0.0, 1.0);
                      return GlassCard(
                        child: Column(
                          children: [
                            ProgressRing(
                              progress: progress,
                              color: AppColors.accentGreen,
                              center: Text(
                                '${totalCalories.toStringAsFixed(0)} kcal',
                                style: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                              ),
                            ),
                            if (goals != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Goal: ${goals.dailyCalories.toStringAsFixed(0)} kcal',
                                style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              _macroRow(context, 'Protein', totalProtein, goals.proteinG),
                              _macroRow(context, 'Carbs', totalCarbs, goals.carbsG),
                              _macroRow(context, 'Fat', totalFat, goals.fatG),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text(
                          _isSameDay(_selectedDate, DateTime.now())
                              ? 'No food logged yet today.'
                              : 'No food logged yet.',
                          style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  for (final mealType in MealType.values) ...[
                    if (entries.any((e) => e.mealType == mealType)) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          mealType.name,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      for (final entry in entries.where((e) => e.mealType == mealType))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                title: Text(
                                  entry.foodName,
                                  style: textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
                                ),
                                subtitle: Text(
                                  '${entry.quantityGrams.toStringAsFixed(0)}g · '
                                  '${entry.calories.toStringAsFixed(0)} kcal\n'
                                  'P ${entry.proteinG.toStringAsFixed(0)}g · '
                                  'C ${entry.carbsG.toStringAsFixed(0)}g · '
                                  'F ${entry.fatG.toStringAsFixed(0)}g',
                                  style: textTheme.bodyMedium,
                                ),
                                isThreeLine: true,
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FoodEntryDetailScreen(
                                        uid: widget.uid,
                                        entry: entry,
                                        nutritionRepository: widget.nutritionRepository,
                                        onChanged: _refresh,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
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
