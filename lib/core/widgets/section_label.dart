import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A small tracked-uppercase label used above a group of content — gives
/// sections a consistent, deliberate hierarchy marker instead of relying on
/// heading size alone. Optional trailing [accessory] (e.g. a "See all"
/// action or a value chip) floats to the right.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.title, {super.key, this.color = AppColors.accentBlue, this.accessory});

  final String title;
  final Color color;
  final Widget? accessory;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
        ),
        ?accessory,
      ],
    );
  }
}
