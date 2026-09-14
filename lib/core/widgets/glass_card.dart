import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A layered glass card: gradient surface + a soft top-left glow tinted by
/// [glowColor] + a lit hairline edge, on top of a real backdrop blur. Used
/// across everyday (non-celebratory) screens.
///
/// [hero] makes the glow brighter and larger — reserved for the one card at
/// the top of a screen that should read as the page's headline surface
/// (e.g. a dashboard's stat row), matching how the rest of the app treats a
/// hero differently from an ordinary content card.
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(innerRadius),
                        gradient: RadialGradient(
                          colors: [
                            glowColor.withValues(alpha: hero ? 0.16 : 0.08),
                            glowColor.withValues(alpha: 0.0),
                          ],
                          center: Alignment.topLeft,
                          radius: hero ? 1.4 : 1.0,
                        ),
                      ),
                    ),
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
