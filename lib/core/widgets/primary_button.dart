import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The primary CTA pill: [AppColors.accentGradient] fill, fully round
/// (`999` per the glass-UI spec — every pill/chip/button in the app is a
/// stadium shape, not a rounded rectangle), with a soft accent-coloured
/// glow shadow. Pass `null` for [onPressed] to render a disabled/dimmed
/// state (e.g. while an async action is in flight).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: AppColors.accentGradient,
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.accentBlue.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
