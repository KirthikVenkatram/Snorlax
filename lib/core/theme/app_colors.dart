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

  /// Diagonal near-black gradient used as the base fill for cards, instead
  /// of a flat color — a single flat dark fill reads noticeably flatter
  /// than a subtle gradient once placed next to a real glow.
  static const surfaceGradient = LinearGradient(
    colors: [Color(0xFF1A1A24), Color(0xFF101018)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Hairline border gradient: brighter where the light would hit (top
  /// left), fading to near-invisible — reads as a lit edge rather than a
  /// flat outline.
  static const cardStroke = LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x0DFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
