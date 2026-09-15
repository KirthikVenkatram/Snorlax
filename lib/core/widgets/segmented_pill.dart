import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'pressable.dart';

/// A stadium-shaped multi-option toggle: equal-width segments inside one
/// glass track, the selected segment lit with a neon fill/text. Used for
/// Sex (onboarding) and Goal (onboarding + profile) per the handoff.
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.options,
    required this.value,
    required this.labelBuilder,
    required this.onChanged,
    this.subLabelBuilder,
  });

  final List<T> options;
  final T value;
  final String Function(T option) labelBuilder;
  final String Function(T option)? subLabelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Pressable(
                onTap: () => onChanged(option),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: option == value
                        ? AppColors.accentGreen.withValues(alpha: 0.20)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labelBuilder(option),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: option == value ? AppColors.accentGreen : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (subLabelBuilder != null)
                        Text(
                          subLabelBuilder!(option),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: option == value
                                ? AppColors.accentGreen.withValues(alpha: 0.8)
                                : AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
