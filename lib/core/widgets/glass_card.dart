import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Real "liquid glass": a translucent white fill + hairline border + a 1px
/// inner top highlight, over a `BackdropFilter` blur — so whatever colour
/// bloom sits behind the card (see [AmbientBackground]) shows through
/// tinted, not an opaque painted box. A [glowColor]-tinted radial glow sits
/// under the glass fill for card-specific emphasis on top of that.
///
/// [hero] uses the stronger fill/stroke reserved for the one headline card
/// per screen, and gives its glow a slow "breathing" pulse.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.glowColor = AppColors.accentGreen,
    this.hero = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color glowColor;
  final bool hero;

  static const _radius = 26.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: hero ? AppColors.glassFillStrong : AppColors.glassFill,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: hero ? AppColors.glassStrokeStrong : AppColors.glassStroke,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: hero
                    ? _PulsingGlow(color: glowColor, radius: _radius)
                    : _StaticGlow(color: glowColor, radius: _radius),
              ),
              // The inner top highlight the CSS box-shadow `inset` can't be
              // expressed as in Flutter: a 1px line fading left-to-right.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.glassHighlight, Colors.transparent],
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
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
          colors: [color.withValues(alpha: 0.10), color.withValues(alpha: 0)],
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
        final alpha = 0.18 * (0.75 + 0.25 * _controller.value);
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
