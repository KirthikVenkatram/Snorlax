import 'package:flutter/material.dart';

/// A circular progress indicator used for stats like "calories so far".
/// Animates toward [progress] whenever it changes, instead of jumping —
/// every ring in the app shares this widget, so the fill/count-up motion
/// applies everywhere for free.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.center,
    this.size = 96,
    this.strokeWidth = 10,
  });

  /// 0.0 to 1.0. Values outside this range are clamped at build time.
  final double progress;
  final Color color;
  final Widget? center;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final target = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: target),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CircularProgressIndicator(
              value: value,
              strokeWidth: strokeWidth,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          ?center,
        ],
      ),
    );
  }
}
