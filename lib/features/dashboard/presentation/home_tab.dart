import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/calculations/streak_calculator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/section_label.dart';
import '../../adherence/data/adherence_repository.dart';
import '../../habits/data/habit_repository.dart';
import '../../habits/domain/habit.dart';
import '../../habits/domain/habit_completion.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../sleep/data/sleep_repository.dart';
import '../../sleep/domain/sleep_entry.dart';
import '../../workouts/data/workout_repository.dart';
import '../../workouts/domain/workout.dart';

class _DashboardStats {
  const _DashboardStats({
    required this.caloriesConsumed,
    required this.calorieGoal,
    required this.weeklyAdherence,
  });

  final double caloriesConsumed;
  final double? calorieGoal;
  final double? weeklyAdherence;
}

class _HomeExtras {
  const _HomeExtras({
    required this.lastWorkout,
    required this.lastNight,
    required this.habits,
    required this.todayCompletion,
    required this.streak,
  });

  final Workout? lastWorkout;
  final SleepEntry? lastNight;
  final List<Habit> habits;
  final HabitCompletion? todayCompletion;
  final StreakResult streak;
}

/// The Home tab: today's headline stats, training/sleep tiles, a real
/// habits-driven checklist, a streak banner, and quick actions into the
/// other tabs. Everything else lives one tap away in its own tab, or in
/// More.
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.uid,
    required this.nutritionRepository,
    required this.adherenceRepository,
    required this.workoutRepository,
    required this.sleepRepository,
    required this.habitRepository,
    required this.onNavigateToTab,
  });

  final String uid;
  final NutritionRepository nutritionRepository;
  final AdherenceRepository adherenceRepository;
  final WorkoutRepository workoutRepository;
  final SleepRepository sleepRepository;
  final HabitRepository habitRepository;

  /// Switches the enclosing [AppShell] to another tab by index
  /// (0=Home, 1=Nutrition, 2=Train, 3=Coach, 4=More).
  final ValueChanged<int> onNavigateToTab;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  late Future<_DashboardStats> _statsFuture;
  late Future<_HomeExtras> _extrasFuture;
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
    _extrasFuture = _loadExtras();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Fades + slides [child] up into place, staggered by [index] so the
  /// screen reveals in sequence on first load instead of popping in flat.
  Widget _stagger(int index, Widget child) {
    final interval = CurvedAnimation(
      parent: _entrance,
      curve: Interval((index * 0.15).clamp(0.0, 1.0), (index * 0.15 + 0.55).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: interval,
      child: SlideTransition(
        position: interval.drive(Tween(begin: const Offset(0, 0.06), end: Offset.zero)),
        child: child,
      ),
    );
  }

  Future<_DashboardStats> _loadStats() async {
    final now = DateTime.now();
    final entries = await widget.nutritionRepository.listFoodLog(widget.uid);
    final goals = await widget.nutritionRepository.getGoals(widget.uid);
    final weekly = await widget.adherenceRepository.computeAndCacheWeekly(widget.uid, now);

    final todayCalories = entries
        .where((e) => e.date.year == now.year && e.date.month == now.month && e.date.day == now.day)
        .fold<double>(0, (sum, e) => sum + e.calories);

    return _DashboardStats(
      caloriesConsumed: todayCalories,
      calorieGoal: goals?.dailyCalories,
      weeklyAdherence: weekly.overallScore,
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<_HomeExtras> _loadExtras() async {
    final now = DateTime.now();
    final workouts = await widget.workoutRepository.listWorkouts(widget.uid);
    final recentSleep = await widget.sleepRepository.listRecent(widget.uid, 1);
    final habits = await widget.habitRepository.listHabits(widget.uid);
    final todayCompletion = await widget.habitRepository.getCompletion(widget.uid, now);

    // Streak: a decent real-data approximation from two weekly rollups
    // (this week + last week) rather than 14 individual daily fetches —
    // WeeklyAdherenceSummary.dailyScores is Monday-first, so reverse each
    // week before concatenating newest-first for the calculator.
    final thisWeek = await widget.adherenceRepository.computeAndCacheWeekly(widget.uid, now);
    final lastWeek = await widget.adherenceRepository
        .computeAndCacheWeekly(widget.uid, now.subtract(const Duration(days: 7)));
    final qualifying = [
      ...thisWeek.dailyScores.reversed,
      ...lastWeek.dailyScores.reversed,
    ].map((score) => score != null && score >= 0.6).toList();

    return _HomeExtras(
      lastWorkout: workouts.isEmpty ? null : workouts.first,
      lastNight: recentSleep.isEmpty ? null : recentSleep.first,
      habits: habits,
      todayCompletion: todayCompletion,
      streak: StreakCalculator.fromQualifyingDays(qualifying),
    );
  }

  Future<void> _toggleHabit(Habit habit, bool completed) async {
    await widget.habitRepository.completeHabit(widget.uid, DateTime.now(), habit.id, completed: completed);
    setState(() => _extrasFuture = _loadExtras());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _stagger(
                    0,
                    Text(
                      _greeting,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _stagger(
                    1,
                    FutureBuilder<_DashboardStats>(
                      future: _statsFuture,
                      builder: (context, snapshot) => _HeroStatsRow(
                        stats: snapshot.data,
                        onOpenNutrition: () => widget.onNavigateToTab(1),
                        onOpenCoach: () => widget.onNavigateToTab(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _stagger(
                    2,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionLabel('Quick actions'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.restaurant_outlined,
                                label: 'Log food',
                                color: AppColors.accentGreen,
                                onTap: () => widget.onNavigateToTab(1),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.fitness_center_outlined,
                                label: 'Log workout',
                                color: AppColors.accentViolet,
                                onTap: () => widget.onNavigateToTab(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.auto_awesome_outlined,
                                label: 'Ask coach',
                                color: AppColors.accentAmber,
                                onTap: () => widget.onNavigateToTab(3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _stagger(
                    3,
                    FutureBuilder<_HomeExtras>(
                      future: _extrasFuture,
                      builder: (context, snapshot) {
                        final extras = snapshot.data;
                        return Row(
                          children: [
                            Expanded(
                              child: _InfoTile(
                                label: 'TRAINING',
                                title: extras?.lastWorkout == null
                                    ? 'Not yet'
                                    : extras!.lastWorkout!.type.name,
                                subtitle: extras?.lastWorkout == null
                                    ? 'Log a workout →'
                                    : '${extras!.lastWorkout!.durationMinutes} min',
                                color: AppColors.accentViolet,
                                onTap: () => widget.onNavigateToTab(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _InfoTile(
                                label: 'LAST NIGHT',
                                title: extras?.lastNight == null
                                    ? 'No check-in'
                                    : _formatDuration(extras!.lastNight!.timeAsleep),
                                subtitle: extras?.lastNight == null
                                    ? 'Log sleep →'
                                    : '${extras!.lastNight!.score} sleep score',
                                color: AppColors.accentBlue,
                                onTap: () => GoRouter.of(context).push('/sleep'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  _stagger(
                    4,
                    FutureBuilder<_HomeExtras>(
                      future: _extrasFuture,
                      builder: (context, snapshot) {
                        final extras = snapshot.data;
                        if (extras == null) return const SizedBox.shrink();
                        return _ChecklistCard(
                          habits: extras.habits,
                          completion: extras.todayCompletion,
                          onToggle: _toggleHabit,
                          onManageHabits: () => GoRouter.of(context).push('/habits'),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  _stagger(
                    5,
                    FutureBuilder<_HomeExtras>(
                      future: _extrasFuture,
                      builder: (context, snapshot) => _StreakBanner(
                        streak: snapshot.data?.streak,
                        onTap: () => GoRouter.of(context).push('/streaks'),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(Duration d) => '${d.inHours}h ${d.inMinutes % 60}m';

class _HeroStatsRow extends StatelessWidget {
  const _HeroStatsRow({
    required this.stats,
    required this.onOpenNutrition,
    required this.onOpenCoach,
  });

  final _DashboardStats? stats;
  final VoidCallback onOpenNutrition;
  final VoidCallback onOpenCoach;

  @override
  Widget build(BuildContext context) {
    final calorieGoal = stats?.calorieGoal;
    final consumed = stats?.caloriesConsumed ?? 0;
    final calorieProgress = calorieGoal != null && calorieGoal > 0 ? consumed / calorieGoal : 0.0;
    final adherence = stats?.weeklyAdherence;

    return Row(
      children: [
        Expanded(
          child: _HeroStatCard(
            label: 'Today',
            ring: ProgressRing(
              progress: calorieProgress,
              color: AppColors.accentGreen,
              size: 76,
              strokeWidth: 8,
              center: Text(
                calorieGoal == null ? '—' : '${consumed.round()}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
              ),
            ),
            caption: calorieGoal == null ? 'Set a calorie goal' : 'of ${calorieGoal.round()} kcal',
            onTap: onOpenNutrition,
            glowColor: AppColors.accentGreen,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _HeroStatCard(
            label: 'This week',
            ring: ProgressRing(
              progress: adherence ?? 0,
              color: AppColors.accentBlue,
              size: 76,
              strokeWidth: 8,
              center: Text(
                adherence == null ? '—' : '${(adherence * 100).round()}%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
              ),
            ),
            caption: adherence == null ? 'No data yet' : 'adherence',
            onTap: onOpenCoach,
            glowColor: AppColors.accentBlue,
          ),
        ),
      ],
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  const _HeroStatCard({
    required this.label,
    required this.ring,
    required this.caption,
    required this.onTap,
    required this.glowColor,
  });

  final String label;
  final Widget ring;
  final String caption;
  final VoidCallback onTap;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: GlassCard(
          hero: true,
          glowColor: glowColor,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(height: 12),
              ring,
              const SizedBox(height: 12),
              Text(
                caption,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: GlassCard(
          glowColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: GlassCard(
          glowColor: color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.mono(fontSize: 10, color: color)),
              const SizedBox(height: 6),
              Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 17)),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per reconciliation decision #1 in
/// `docs/superpowers/plans/2026-09-15-glass-handoff-new-features.md`: this
/// shows the user's real configured habits due today (not a fake fixed
/// 4-item list). An empty habit list points at `/habits` to add some.
class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.habits,
    required this.completion,
    required this.onToggle,
    required this.onManageHabits,
  });

  final List<Habit> habits;
  final HabitCompletion? completion;
  final void Function(Habit habit, bool completed) onToggle;
  final VoidCallback onManageHabits;

  @override
  Widget build(BuildContext context) {
    final active = habits.where((h) => !h.archived).toList();
    final doneCount = active.where((h) => completion?.entries[h.id]?.completed == true).length;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Daily checklist', style: Theme.of(context).textTheme.bodyLarge)),
              Text(
                '$doneCount/${active.length}',
                style: const TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (active.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No habits configured yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: onManageHabits, child: const Text('Add a habit →')),
                ],
              ),
            )
          else
            for (final habit in active)
              _ChecklistRow(
                habit: habit,
                completed: completion?.entries[habit.id]?.completed == true,
                onToggle: (value) => onToggle(habit, value),
              ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.habit, required this.completed, required this.onToggle});

  final Habit habit;
  final bool completed;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onToggle(!completed),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? AppColors.accentGreen : Colors.transparent,
                border: Border.all(color: completed ? AppColors.accentGreen : AppColors.glassStroke, width: 2),
              ),
              child: completed ? const Icon(Icons.check, size: 14, color: Colors.black) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                habit.name,
                style: TextStyle(
                  fontSize: 14,
                  decoration: completed ? TextDecoration.lineThrough : null,
                  color: completed
                      ? AppColors.textPrimary.withValues(alpha: 0.5)
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.streak, required this.onTap});

  final StreakResult? streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = streak?.current ?? 0;
    return Pressable(
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CONSISTENCY STREAK',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$days days',
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(fontSize: 32, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Text('View →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
