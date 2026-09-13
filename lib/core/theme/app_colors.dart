import 'package:flutter/material.dart';

/// Design tokens for the dark, neon-accented base UI.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF15151F);
  static const surfaceGlass = Color(0x1AFFFFFF); // translucent white for glass cards

  static const accentBlue = Color(0xFF3D5AFE);
  static const accentViolet = Color(0xFF9C4DFF);
  static const accentGreen = Color(0xFF00E5A0);
  static const accentAmber = Color(0xFFFFC24D);
  static const error = Color(0xFFFF5C7A);

  static const textPrimary = Color(0xFFF5F5FA);
  static const textSecondary = Color(0xFFA0A0B2);

  static const celebrationGradient = [accentViolet, accentBlue, accentGreen];
}
