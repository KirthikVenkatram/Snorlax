import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A layered glass card: gradient surface + a soft top-left glow tinted by
/// [glowColor] + a lit hairline edge, on top of a real backdrop blur. Used
/// across everyday (non-celebratory) screens.
///
/// [hero] makes the glow brighter and larger, and gives it a slow "breathing"
/// pulse — reserved for the one card at the top of a screen that should read
/// as the page's headline surface (e.g. a dashboard's stat row).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glowColor = AppColors.accentBlue,
    this.hero = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color glowColor;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    const outerRadius = 20.0;
    const innerRadius = 19.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(outerRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        // The outer gradient shows only as a 1px ring: the inset opaque
        // surface below covers everything except that hairline margin.
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.cardStroke,
            borderRadius: BorderRadius.circular(outerRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.surfaceGradient,
                borderRadius: BorderRadius.circular(innerRadius),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    // Only hero cards get the animated (ticker-backed)
                    // glow — an ordinary card in a list of a dozen doesn't
                    // need its own AnimationController, and pulsing every
                    // row would read as noise, not polish.
                    child: hero
                        ? _PulsingGlow(color: glowColor, radius: innerRadius)
                        : _StaticGlow(color: glowColor, radius: innerRadius),
                  ),
                  Padding(padding: padding, child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticGlow extends StatelessWidget {
  const _StaticGlow({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0)],
          center: Alignment.topLeft,
          radius: 1.0,
        ),
      ),
    );
  }
}

class _PulsingGlow extends StatefulWidget {
  const _PulsingGlow({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  State<_PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<_PulsingGlow> with SingleTickerProviderStateMixin {
  // Bounded rather than infinite: an ever-repeating controller never
  // "settles", which would hang any widget test calling pumpAndSettle() on
  // a screen with a hero card. A handful of breathing cycles on first view
  // reads as alive without that cost — real usage doesn't need it to pulse
  // forever to feel premium.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true, count: 6);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final alpha = 0.16 * (0.75 + 0.25 * _controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: RadialGradient(
              colors: [widget.color.withValues(alpha: alpha), widget.color.withValues(alpha: 0)],
              center: Alignment.topLeft,
              radius: 1.4,
            ),
          ),
        );
      },
    );
  }
}
