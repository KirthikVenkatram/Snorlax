import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/section_label.dart';
import '../../adherence/data/adherence_repository.dart';
import '../../nutrition/data/nutrition_repository.dart';

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

/// The Home tab: today's headline stats plus quick actions into the other
/// tabs. Kept lean on purpose — everything else lives one tap away in its
/// own tab, or in More.
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.uid,
    required this.nutritionRepository,
    required this.adherenceRepository,
    required this.onNavigateToTab,
  });

  final String uid;
  final NutritionRepository nutritionRepository;
  final AdherenceRepository adherenceRepository;

  /// Switches the enclosing [AppShell] to another tab by index
  /// (0=Home, 1=Nutrition, 2=Train, 3=Coach, 4=More).
  final ValueChanged<int> onNavigateToTab;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<_DashboardStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(title: Text(_greeting)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  FutureBuilder<_DashboardStats>(
                    future: _statsFuture,
                    builder: (context, snapshot) => _HeroStatsRow(
                      stats: snapshot.data,
                      onOpenNutrition: () => widget.onNavigateToTab(1),
                      onOpenCoach: () => widget.onNavigateToTab(3),
                    ),
                  ),
                  const SizedBox(height: 32),
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
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return InkWell(
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
    return InkWell(
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
    );
  }
}
