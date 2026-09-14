import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A restrained, solid-color CTA button for everyday primary actions.
///
/// Unlike [GradientButton] (reserved for celebratory moments), this uses a
/// two-stop [AppColors.accentBlue] gradient with a soft glow shadow rather
/// than the full multi-color celebration gradient. Pass `null` for
/// [onPressed] to render a disabled/dimmed state (e.g. while an async
/// action is in flight).
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
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF5B76FF), AppColors.accentBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
