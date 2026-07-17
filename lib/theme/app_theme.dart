import 'package:flutter/material.dart';

/// Warm, paper-like reading palette (dark-mode first).
class AppTheme {
  static const Color _seed = Color(0xFFC4A574); // warm paper/amber
  static const Color _darkBg = Color(0xFF12100E);
  static const Color _darkSurface = Color(0xFF1C1916);
  static const Color _darkCard = Color(0xFF26211C);
  static const Color _lightBg = Color(0xFFF7F1E8);
  static const Color _lightSurface = Color(0xFFFFFBF5);
  static const Color _accent = Color(0xFFE8A838);

  static ThemeData get dark {
    final base = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: base.copyWith(
        surface: _darkSurface,
        primary: _accent,
        onPrimary: Colors.black,
        secondary: _seed,
        surfaceContainerHighest: _darkCard,
      ),
      scaffoldBackgroundColor: _darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBg,
        foregroundColor: Color(0xFFF5EDE0),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: _darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _accent,
        foregroundColor: Colors.black,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _accent,
        unselectedLabelColor: Colors.white54,
        indicatorColor: _accent,
        dividerColor: Colors.white12,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkSurface,
        modalBackgroundColor: _darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get light {
    final base = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: base.copyWith(
        surface: _lightSurface,
        primary: const Color(0xFF8B6914),
        secondary: _seed,
        surfaceContainerHighest: const Color(0xFFEDE4D4),
      ),
      scaffoldBackgroundColor: _lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBg,
        foregroundColor: Color(0xFF2C2416),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF8B6914),
        foregroundColor: Colors.white,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Color(0xFF8B6914),
        unselectedLabelColor: Colors.black45,
        indicatorColor: Color(0xFF8B6914),
        dividerColor: Colors.black12,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _lightSurface,
        modalBackgroundColor: _lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFEDE4D4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
