import 'package:flutter/material.dart';

/// A circular progress indicator used for stats like "calories so far".
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
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: strokeWidth,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          ?center,
        ],
      ),
    );
  }
}
