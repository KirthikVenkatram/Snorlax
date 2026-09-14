import 'package:flutter/material.dart';

/// Design tokens for the dark, neon-accented base UI.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF15151F);
  static const surfaceGlass = Color(0x1AFFFFFF); // translucent white for glass cards

  // Cyberpunk-neon accent trio (retinted from the original blue/violet/teal
  // set — the token names stayed put to avoid a repo-wide rename, but the
  // hues are now hot magenta / crimson / acid green).
  static const accentBlue = Color(0xFFFF2E9A); // primary accent: neon magenta
  static const accentViolet = Color(0xFFFF2A4D); // neon crimson red
  static const accentGreen = Color(0xFF00FF9C); // brighter acid green
  static const accentAmber = Color(0xFFFFD23F); // neon yellow
  static const error = Color(0xFFFF3B30); // true red, kept distinct from the accents above

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
  /// flat outline. Faintly magenta-tinted rather than pure white, so the
  /// edge itself reads as neon rather than generic "glass."
  static const cardStroke = LinearGradient(
    colors: [Color(0x40FF2E9A), Color(0x0DFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
