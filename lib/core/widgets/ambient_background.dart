import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The dark base + three blurred colour blooms behind every authenticated
/// screen — see `design_handoff_glass_ui/README.md`. [GlassCard]'s
/// translucent fill only reads as "glass" when something colourful is
/// blurred in from behind it; on a flat background it just looks grey.
///
/// Wrap a screen's `Scaffold.body` (or the `Scaffold` itself, with
/// `backgroundColor: Colors.transparent`) in this rather than relying on
/// the default black — it's cheap (three static gradients, no blur of its
/// own; the blur happens in each card's own `BackdropFilter`).
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Top-left green bloom, ~90% x 44% of screen.
          Align(
            alignment: const Alignment(-0.8, -1.0),
            child: FractionallySizedBox(
              widthFactor: 0.9,
              heightFactor: 0.44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [AppColors.bloomGreen, AppColors.bloomGreen.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          // Top-right red bloom, ~92% x 18%.
          Align(
            alignment: const Alignment(1.0, -1.0),
            child: FractionallySizedBox(
              widthFactor: 0.92,
              heightFactor: 0.18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [AppColors.bloomRed, AppColors.bloomRed.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          // Bottom-centre violet bloom.
          Align(
            alignment: const Alignment(0.0, 1.1),
            child: FractionallySizedBox(
              widthFactor: 1.0,
              heightFactor: 0.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [AppColors.bloomViolet, AppColors.bloomViolet.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
