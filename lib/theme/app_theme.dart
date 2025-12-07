import 'package:flutter/material.dart';

class AppTheme {
  // Woody Forest theme for Gozdar
  static ThemeData get greenTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: Color(0xFFD4A574), // Warm wood tan
        onPrimary: Color(0xFF2D1810), // Dark brown
        primaryContainer: Color(0xFF5D4037), // Medium brown
        onPrimaryContainer: Color(0xFFEFDDD1),
        secondary: Color(0xFF8FBF6B), // Forest sage green
        onSecondary: Color(0xFF1B3212),
        secondaryContainer: Color(0xFF3E5435), // Dark moss green
        onSecondaryContainer: Color(0xFFD4E8C8),
        tertiary: Color(0xFFE6A35E), // Amber/honey
        onTertiary: Color(0xFF2D1810),
        error: Color(0xFFCF6679),
        onError: Color(0xFF000000),
        surface: Color(0xFF1A2418), // Very dark forest green
        onSurface: Color(0xFFE8E4DF), // Warm off-white
        surfaceContainerHighest: Color(0xFF2D3A2A), // Dark green-brown
        onSurfaceVariant: Color(0xFFCBC5BC),
        outline: Color(0xFF8B7355), // Bark brown
      ),
      scaffoldBackgroundColor: const Color(0xFF1A2418),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF2D3A2A),
        foregroundColor: Color(0xFFE8E4DF),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF2D3A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: Color(0xFF5D4037),
            width: 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B7355)),
        ),
        filled: true,
        fillColor: const Color(0xFF2D3A2A),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4A574),
          foregroundColor: const Color(0xFF2D1810),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFD4A574),
        foregroundColor: Color(0xFF2D1810),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF2D3A2A),
        indicatorColor: const Color(0xFFD4A574).withValues(alpha: 0.3),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFFD4A574));
          }
          return const IconThemeData(color: Color(0xFFCBC5BC));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: Color(0xFFD4A574), fontSize: 12);
          }
          return const TextStyle(color: Color(0xFFCBC5BC), fontSize: 12);
        }),
      ),
    );
  }
}
