import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Builds the app-wide [ThemeData] from [AppColors].
///
/// Kept as a single source of truth: [RinglyApp] passes the result straight
/// into MaterialApp, so every screen inherits the off-white background, white
/// surfaces, and consistent input/button styling without repeating itself.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
    ).copyWith(
      surface: AppColors.background,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      // Cards sit as pure-white panels lifted off the off-white background by
      // a soft border rather than a heavy drop shadow.
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        bodySmall: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}
