import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_label.dart';

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
      _NavItem(Icons.monitor_weight_outlined, 'Body composition', AppColors.accentViolet, '/body'),
      _NavItem(Icons.checklist_outlined, 'Habits', AppColors.accentAmber, '/habits'),
      _NavItem(Icons.bedtime_outlined, 'Sleep', AppColors.accentViolet, '/sleep'),
    ],
  ),
  (
    'Insights',
    [
      _NavItem(Icons.insights_outlined, 'Adherence', AppColors.accentBlue, '/adherence'),
      _NavItem(Icons.bedtime_outlined, 'Readiness', AppColors.accentViolet, '/readiness'),
      _NavItem(Icons.show_chart, 'Trends', AppColors.accentGreen, '/trends'),
      _NavItem(Icons.local_fire_department_outlined, 'Streaks', AppColors.accentBlue, '/streaks'),
    ],
  ),
  (
    'Plan',
    [
      _NavItem(Icons.flag_outlined, 'Goals', AppColors.accentGreen, '/goals'),
      _NavItem(Icons.receipt_long_outlined, 'Meal planning', AppColors.accentBlue, '/meal-planning'),
    ],
  ),
  (
    'Account',
    [
      _NavItem(Icons.settings_outlined, 'Settings', AppColors.textSecondary, '/settings'),
    ],
  ),
];

/// The More tab: everything that isn't frequent enough to earn its own
/// bottom-bar slot, grouped the same way the original dashboard grouped it.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            for (final (title, items) in _sections) ...[
              SectionLabel(title),
              const SizedBox(height: 8),
              _NavGroup(items: items),
              const SizedBox(height: 24),
            ],
          ],
        ),
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
          gradient: AppColors.surfaceGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.fromBorderSide(const BorderSide(color: Color(0x0FFFFFFF))),
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
      key: Key('moreNavRow_${item.label}'),
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
