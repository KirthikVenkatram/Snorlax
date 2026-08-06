import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentBlue,
          secondary: AppColors.accentViolet,
          tertiary: AppColors.accentGreen,
          surface: AppColors.surface,
        ),
        textTheme: AppTypography.textTheme,
        useMaterial3: true,
      );
}
