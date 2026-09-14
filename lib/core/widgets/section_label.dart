import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// A small tracked-uppercase HUD-style label used above a group of content
/// — bracketed like a readout, gives sections a consistent, deliberate
/// hierarchy marker instead of relying on heading size alone. Optional
/// trailing [accessory] (e.g. a "See all" action or a value chip) floats to
/// the right.
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
            '// ${title.toUpperCase()}',
            style: AppTypography.mono(color: color),
          ),
        ),
        ?accessory,
      ],
    );
  }
}
