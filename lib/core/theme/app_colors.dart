import 'package:flutter/material.dart';

/// Design tokens for the dark "liquid glass" UI — per
/// `design_handoff_glass_ui/README.md`: translucent blurred surfaces over a
/// coloured bloom, pill geometry, neon data colours.
class AppColors {
  AppColors._();

  static const background = Color(0xFF080910);
  static const surface = Color(0xFF15151F);
  static const surfaceGlass = Color(0x1AFFFFFF); // translucent white for glass cards

  // Token names kept as-is (accentBlue/accentViolet/accentGreen/accentAmber)
  // to avoid a repo-wide rename, but the hues now match the handoff's
  // green/red/violet system rather than the earlier cyberpunk magenta trio.
  static const accentBlue = Color(0xFFFF3B24); // "accent": primary actions, gradient FF6A52->FF3B24
  static const accentViolet = Color(0xFF7C4DFF); // "violet": sleep data, discipline bars
  static const accentGreen = Color(0xFF00E5A0); // "neon": live/data values, calorie ring
  static const accentAmber = Color(0xFFFFD23F);
  static const error = Color(0xFFFF3B30);

  static const textPrimary = Color(0xFFF5F5FA);
  static const textSecondary = Color(0x8FFFFFFF); // white @ ~56%, per spec's 50-60% range

  static const celebrationGradient = [accentViolet, accentBlue, accentGreen];

  /// The three ambient blooms behind every authenticated screen — see
  /// [AmbientBackground]. Positions/sizes are on the widget, not here.
  static const bloomGreen = Color(0x4200E5A0); // 26%
  static const bloomRed = Color(0x3DFF3B24); // 24%
  static const bloomViolet = Color(0x427C4DFF); // 26%

  /// Real glass, not an opaque card: a faint white tint over whatever bloom
  /// is blurred in from behind. Card surfaces must sit over an
  /// [AmbientBackground] (or another bloom) for the glass effect to read —
  /// on a flat background this just looks like a grey box.
  static const glassFill = Color(0x12FFFFFF); // white @ 7%
  static const glassFillStrong = Color(0x17FFFFFF); // white @ 9%, hero cards / tab bar
  static const glassStroke = Color(0x24FFFFFF); // white @ 14%
  static const glassStrokeStrong = Color(0x2BFFFFFF); // white @ 17%, hero/tab bar
  static const glassHighlight = Color(0x33FFFFFF); // white @ 20%, 1px inner top highlight

  static const accentGradient = LinearGradient(
    colors: [Color(0xFFFF6A52), accentBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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
    colors: [Color(0x40FF3B24), Color(0x0DFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
