import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class _TabSpec {
  const _TabSpec(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

// Destinations kept as the app's real 5-tab IA (Home/Nutrition/Train/Coach/
// More) — the handoff's "Today/Train/Fuel/Rest/Me" set swaps Coach for a
// Sleep tab, which is an information-architecture change, not a visual one,
// so it's out of scope for a pixel-restyle pass. Logged in ISSUES.md.
const _tabs = [
  _TabSpec(Icons.home_outlined, Icons.home, 'Home'),
  _TabSpec(Icons.restaurant_outlined, Icons.restaurant, 'Nutrition'),
  _TabSpec(Icons.fitness_center_outlined, Icons.fitness_center, 'Train'),
  _TabSpec(Icons.auto_awesome_outlined, Icons.auto_awesome, 'Coach'),
  _TabSpec(Icons.grid_view_outlined, Icons.grid_view, 'More'),
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
    final screens = [
      _home,
      widget.nutrition,
      widget.train,
      widget.coach,
      widget.more,
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: _GlassTabBar(index: _index, onChanged: _setIndex),
    );
  }
}

/// Floating glass pill tab bar per the handoff nav spec: 14px side inset,
/// fully rounded, blur 30, white@10 fill, white@18 border, inner highlight,
/// selected item gets a white@22 pill with neon text.
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: SizedBox(
              height: 72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.glassStrokeStrong),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x80000000),
                      blurRadius: 34,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 24,
                      right: 24,
                      child: Container(
                        height: 1,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.glassHighlight,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          for (var i = 0; i < _tabs.length; i++)
                            Expanded(
                              child: _TabButton(
                                spec: _tabs[i],
                                selected: i == index,
                                onTap: () => onChanged(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accentGreen : AppColors.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0x38FFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? spec.activeIcon : spec.icon,
              color: color,
              size: 20,
            ),
            const SizedBox(height: 3),
            Text(
              spec.label.toUpperCase(),
              style: AppTypography.mono(
                fontSize: 9,
                color: color,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
