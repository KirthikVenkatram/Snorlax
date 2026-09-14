import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class _TabSpec {
  const _TabSpec(this.icon, this.activeIcon, this.label, this.color);

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
}

const _tabs = [
  _TabSpec(Icons.home_outlined, Icons.home, 'Home', AppColors.accentBlue),
  _TabSpec(Icons.restaurant_outlined, Icons.restaurant, 'Nutrition', AppColors.accentGreen),
  _TabSpec(Icons.fitness_center_outlined, Icons.fitness_center, 'Train', AppColors.accentViolet),
  _TabSpec(Icons.auto_awesome_outlined, Icons.auto_awesome, 'Coach', AppColors.accentAmber),
  _TabSpec(Icons.grid_view_outlined, Icons.grid_view, 'More', AppColors.textSecondary),
];

/// The app's persistent shell: five tabs behind a bottom nav bar instead of
/// one screen pushing into everything else. Each tab keeps its own screen
/// (and its own Scaffold/AppBar) alive via [IndexedStack] — switching tabs
/// never rebuilds or loses scroll position on the others.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.homeBuilder,
    required this.nutrition,
    required this.train,
    required this.coach,
    required this.more,
  });

  /// Home is the only tab that needs to switch tabs itself (its quick
  /// actions and hero cards jump straight to Nutrition/Train/Coach), so
  /// it's built here with [_setIndex] rather than passed as a plain widget.
  final Widget Function(ValueChanged<int> onNavigateToTab) homeBuilder;
  final Widget nutrition;
  final Widget train;
  final Widget coach;
  final Widget more;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final Widget _home = widget.homeBuilder(_setIndex);

  void _setIndex(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final screens = [_home, widget.nutrition, widget.train, widget.coach, widget.more];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: _CyberTabBar(index: _index, onChanged: _setIndex),
    );
  }
}

class _CyberTabBar extends StatelessWidget {
  const _CyberTabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.surfaceGradient,
        border: Border(top: BorderSide(color: Color(0x40FF2E9A), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(child: _TabButton(spec: _tabs[i], selected: i == index, onTap: () => onChanged(i))),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.spec, required this.selected, required this.onTap});

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? spec.color : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (selected)
            Container(
              width: 20,
              height: 3,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: spec.color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: spec.color.withValues(alpha: 0.7), blurRadius: 8)],
              ),
            )
          else
            const SizedBox(height: 9),
          Icon(selected ? spec.activeIcon : spec.icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(spec.label.toUpperCase(), style: AppTypography.mono(fontSize: 9, color: color, letterSpacing: 0.8)),
        ],
      ),
    );
  }
}
