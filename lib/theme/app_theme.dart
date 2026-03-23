import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData darkVibrant() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF7C4DFF),
      secondary: Color(0xFF00E5FF),
      surface: Color(0xFF121212),
      error: Color(0xFFFF5252),
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFF001014),
      onSurface: Color(0xFFEFEFEF),
      onError: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFF311B92),
      secondaryContainer: Color(0xFF00B8D4),
      outline: Color(0xFF2A2A2A),
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

