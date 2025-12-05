import 'package:flutter/material.dart';

class AppTheme {
  // Forest Green theme for Gozdar
  static ThemeData get greenTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: Color(0xFF69F0AE), // Bright green
        onPrimary: Color(0xFF000000),
        primaryContainer: Color(0xFF00695C), // Dark teal-green
        onPrimaryContainer: Color(0xFFB9F6CA),
        secondary: Color(0xFF64FFDA),
        onSecondary: Color(0xFF000000),
        secondaryContainer: Color(0xFF004D40),
        onSecondaryContainer: Color(0xFFB9F6CA),
        tertiary: Color(0xFF1DE9B6),
        onTertiary: Color(0xFF000000),
        error: Color(0xFFCF6679),
        onError: Color(0xFF000000),
        surface: Color(0xFF001A12), // Very dark green-tinted
        onSurface: Color(0xFFE8F5E9),
        surfaceContainerHighest: Color(0xFF002D1F),
        onSurfaceVariant: Color(0xFFB9F6CA),
        outline: Color(0xFF69F0AE),
      ),
      scaffoldBackgroundColor: const Color(0xFF001A12),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF002D1F),
        foregroundColor: Color(0xFFE8F5E9),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF002D1F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: Color(0xFF69F0AE),
            width: 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF69F0AE)),
        ),
        filled: true,
        fillColor: const Color(0xFF002D1F),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF69F0AE),
          foregroundColor: const Color(0xFF000000),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF69F0AE),
        foregroundColor: Color(0xFF000000),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF002D1F),
        indicatorColor: const Color(0xFF69F0AE).withValues(alpha: 0.3),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF69F0AE));
          }
          return const IconThemeData(color: Color(0xFFB9F6CA));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: Color(0xFF69F0AE), fontSize: 12);
          }
          return const TextStyle(color: Color(0xFFB9F6CA), fontSize: 12);
        }),
      ),
    );
  }
}
