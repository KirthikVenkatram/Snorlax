import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/progress_ring.dart';
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

class _NavItem {
  const _NavItem(this.icon, this.label, this.color, this.route);

  final IconData icon;
  final String label;
  final Color color;
  final String route;
}

const _sections = <(String, List<_NavItem>)>[
  (
    'Track',
    [
      _NavItem(Icons.restaurant_outlined, 'Nutrition', AppColors.accentGreen, '/nutrition'),
      _NavItem(Icons.fitness_center_outlined, 'Workouts', AppColors.accentBlue, '/workouts'),
      _NavItem(Icons.monitor_weight_outlined, 'Body composition', AppColors.accentViolet, '/body'),
      _NavItem(Icons.checklist_outlined, 'Habits', AppColors.accentAmber, '/habits'),
    ],
  ),
  (
    'Insights',
    [
      _NavItem(Icons.insights_outlined, 'Adherence', AppColors.accentBlue, '/adherence'),
      _NavItem(Icons.bedtime_outlined, 'Readiness', AppColors.accentViolet, '/readiness'),
      _NavItem(Icons.auto_awesome_outlined, 'AI Coach', AppColors.accentAmber, '/coach'),
    ],
  ),
  (
    'Plan',
    [
      _NavItem(Icons.flag_outlined, 'Goals', AppColors.accentGreen, '/goals'),
      _NavItem(Icons.receipt_long_outlined, 'Meal planning', AppColors.accentBlue, '/meal-planning'),
    ],
  ),
];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.uid,
    required this.nutritionRepository,
    required this.adherenceRepository,
  });

  final String uid;
  final NutritionRepository nutritionRepository;
  final AdherenceRepository adherenceRepository;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
            SliverAppBar.large(
              title: Text(_greeting),
              actions: [
                IconButton(
                  key: const Key('settingsButton'),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () => GoRouter.of(context).push('/settings'),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  FutureBuilder<_DashboardStats>(
                    future: _statsFuture,
                    builder: (context, snapshot) => _HeroStatsRow(stats: snapshot.data),
                  ),
                  const SizedBox(height: 32),
                  for (final (title, items) in _sections) ...[
                    _SectionHeader(title),
                    const SizedBox(height: 8),
                    _NavGroup(items: items),
                    const SizedBox(height: 24),
                  ],
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
  const _HeroStatsRow({required this.stats});

  final _DashboardStats? stats;

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
            onTap: () => GoRouter.of(context).push('/nutrition'),
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
            onTap: () => GoRouter.of(context).push('/adherence'),
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
  });

  final String label;
  final Widget ring;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: GlassCard(
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
    );
  }
}

class _NavGroup extends StatelessWidget {
  const _NavGroup({required this.items});

  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _NavRow(item: items[i]),
              if (i != items.length - 1)
                const Divider(height: 1, indent: 68, color: Colors.white12),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.item});

  final _NavItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => GoRouter.of(context).push(item.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, size: 18, color: item.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(item.label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
