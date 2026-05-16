import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get glassLightTheme {
    const brandMint = Color(0xFFADEBB3);
    const brandIris = Color(0xFF7C6BFF);
    const canvas = Color(0xFFF7FBF8);
    const surface = Color(0xFFFFFFFF);
    const text = Color(0xFF0B1B14);
    const textMuted = Color(0xFF3C5A4B);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandMint,
      brightness: Brightness.light,
      primary: brandMint,
      secondary: brandIris,
      surface: surface,
    ).copyWith(onSurface: text, onPrimary: text, onSecondary: Colors.white);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: canvas,
      colorScheme: colorScheme,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: -0.6,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: text),
        bodyMedium: TextStyle(fontSize: 14, color: textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF0B1B14).withValues(alpha: 0.92),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
