import 'package:flutter/material.dart';
import '../../../core/calculations/nutrition_goal_calculator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/weekly_bar_chart.dart';
import '../../auth/data/user_profile_repository.dart';
import '../data/food_search_service.dart';
import '../data/nutrition_repository.dart';
import '../data/recipe_repository.dart';
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
    required this.recipeRepository,
    required this.userProfileRepository,
  });

  final String uid;
  final NutritionRepository nutritionRepository;
  final FoodSearchService searchService;
  final RecipeRepository recipeRepository;

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
  late Future<int> _waterFuture;
  late Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _entriesFuture = widget.nutritionRepository.listFoodLog(widget.uid);
      _goalsFuture = widget.nutritionRepository.getGoals(widget.uid);
      _waterFuture = widget.nutritionRepository.getWaterMl(widget.uid, _selectedDate);
      _profileFuture = widget.userProfileRepository.getProfile(widget.uid);
    });
  }

  Future<void> _addWater(int deltaMl) async {
    await widget.nutritionRepository.addWater(widget.uid, _selectedDate, deltaMl);
    setState(() {
      _waterFuture = widget.nutritionRepository.getWaterMl(widget.uid, _selectedDate);
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
          recipeRepository: widget.recipeRepository,
          date: _selectedDate,
          onSaved: () {
            Navigator.of(context).pop();
            _refresh();
          },
        ),
      ),
    );
    // Also refresh on manual back-navigation (e.g. the user backed out after
    // a partial-failure message on the Describe tab, where onSaved
    // deliberately isn't called) — some items may have already reached
    // Firestore via the fire-and-forget writes and should show up.
    _refresh();
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
            onPressed: () {
              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              _selectedDate = _selectedDate.add(const Duration(days: 1));
              _refresh();
            },
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
                        hero: true,
                        glowColor: AppColors.accentGreen,
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
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<NutritionGoals?>(
                    future: _goalsFuture,
                    builder: (context, goalsSnapshot) {
                      final goals = goalsSnapshot.data;
                      if (goals == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GlassCard(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _MacroRing(
                                label: 'Protein',
                                total: totalProtein,
                                goal: goals.proteinG,
                                color: AppColors.accentBlue,
                              ),
                              _MacroRing(
                                label: 'Carbs',
                                total: totalCarbs,
                                goal: goals.carbsG,
                                color: AppColors.accentAmber,
                              ),
                              _MacroRing(
                                label: 'Fat',
                                total: totalFat,
                                goal: goals.fatG,
                                color: AppColors.accentViolet,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FutureBuilder<UserProfile?>(
                      future: _profileFuture,
                      builder: (context, profileSnapshot) {
                        final waterTarget = profileSnapshot.data == null
                            ? 2000
                            : NutritionGoalCalculator.waterTargetMl(profileSnapshot.data!.weightKg);
                        return FutureBuilder<int>(
                          future: _waterFuture,
                          builder: (context, waterSnapshot) {
                            final waterMl = waterSnapshot.data ?? 0;
                            return GlassCard(
                              child: Row(
                                children: [
                                  const Icon(Icons.water_drop_outlined, color: AppColors.accentBlue),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Water', style: textTheme.bodyMedium),
                                        Text(
                                          '$waterMl / $waterTarget ml',
                                          style: textTheme.bodyMedium
                                              ?.copyWith(color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    tooltip: 'Remove a glass of water',
                                    onPressed: waterMl <= 0 ? null : () => _addWater(-250),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    tooltip: 'Add a glass of water',
                                    onPressed: () => _addWater(250),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FutureBuilder<NutritionGoals?>(
                      future: _goalsFuture,
                      builder: (context, goalsSnapshot) {
                        return GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Last 7 days', style: textTheme.bodyMedium),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 140,
                                child: WeeklyBarChart(
                                  days: _lastSevenDays(snapshot.data!, _selectedDate),
                                  goal: goalsSnapshot.data?.dailyCalories,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
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

  /// Total calories per day for the 7 days ending on [anchor], oldest first
  /// — the shape [WeeklyBarChart] expects.
  List<DayValue> _lastSevenDays(List<FoodEntry> allEntries, DateTime anchor) {
    return [
      for (var i = 6; i >= 0; i--)
        () {
          final day = anchor.subtract(Duration(days: i));
          final total = allEntries
              .where((e) => _isSameDay(e.date, day))
              .fold<double>(0, (sum, e) => sum + e.calories);
          return DayValue(date: day, value: total);
        }(),
    ];
  }
}

class _MacroRing extends StatelessWidget {
  const _MacroRing({
    required this.label,
    required this.total,
    required this.goal,
    required this.color,
  });

  final String label;
  final double total;
  final double goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = goal == 0 ? 0.0 : (total / goal).clamp(0.0, 1.0);
    return Column(
      children: [
        ProgressRing(
          progress: progress,
          color: color,
          size: 64,
          strokeWidth: 6,
          center: Text(
            total.toStringAsFixed(0),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}
