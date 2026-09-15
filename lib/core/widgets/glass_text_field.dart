import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A labeled input matching the glass-UI handoff: a small caption label
/// above a rounded translucent box (no visible focus underline — the box
/// itself is the field). Used anywhere a form needs the handoff's field
/// look (onboarding, profile) instead of the default Material underline
/// `TextFormField` styling.
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.onChanged,
    this.fieldKey,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Key? fieldKey;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassStroke),
          ),
          child: TextFormField(
            key: fieldKey,
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            validator: validator,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
