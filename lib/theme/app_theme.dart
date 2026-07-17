import 'package:flutter/material.dart';

/// Premium Purple & Gray theme palette.
class AppTheme {
  static const Color _seed = Color(0xFF7F00FF); // Brand Purple (#7F00FF)
  static const Color _lightPrimary = Color(0xFF7F00FF); // Deep brand purple
  static const Color _darkPrimary = Color(0xFFB366FF); // Readable violet/purple for dark mode

  // Gray color scale
  static const Color _darkBg = Color(0xFF121214); // Very dark slate gray
  static const Color _darkSurface = Color(0xFF1A1A1E); // Dark surface gray
  static const Color _darkCard = Color(0xFF24242A); // Slate gray for cards/inputs
  
  static const Color _lightBg = Color(0xFFF4F4F7); // Cool light gray (matches logo text background)
  static const Color _lightSurface = Color(0xFFFFFFFF); // Pure white
  static const Color _lightCard = Color(0xFFE8E8EC); // Soft cool gray for card background

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
        primary: _darkPrimary,
        onPrimary: Colors.white,
        secondary: _seed,
        surfaceContainerHighest: _darkCard,
      ),
      scaffoldBackgroundColor: _darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBg,
        foregroundColor: Color(0xFFE2E2E8),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: _darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _darkPrimary,
        foregroundColor: Colors.white,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: _darkPrimary,
        unselectedLabelColor: Colors.white54,
        indicatorColor: _darkPrimary,
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
        primary: _lightPrimary,
        secondary: _seed,
        surfaceContainerHighest: _lightCard,
      ),
      scaffoldBackgroundColor: _lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBg,
        foregroundColor: Color(0xFF1E1E24),
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
        backgroundColor: _lightPrimary,
        foregroundColor: Colors.white,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: _lightPrimary,
        unselectedLabelColor: Colors.black45,
        indicatorColor: _lightPrimary,
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
        fillColor: _lightCard,
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
