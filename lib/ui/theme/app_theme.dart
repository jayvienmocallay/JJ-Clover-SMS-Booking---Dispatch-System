// Task 010 — App theme with dark mode color scheme
// Color palette derived from the UI design's CSS variables
import 'package:flutter/material.dart';

/// Centralized color palette for the JJ Clover app.
/// Maps directly to the UI design's CSS custom properties.
class AppColors {
  // --- Base colors (dark theme) ---
  static const Color background = Color(0xFF101418);    // --background: 220 20% 8%
  static const Color card = Color(0xFF171C24);           // --card: 220 18% 12%
  static const Color foreground = Color(0xFFE8ECF0);     // --foreground: 210 20% 95%
  static const Color primary = Color(0xFF2D7AED);        // --primary: 215 80% 55%
  static const Color primaryForeground = Colors.white;   // --primary-foreground: white
  static const Color muted = Color(0xFF1E2330);          // --muted: 220 15% 15%
  static const Color mutedForeground = Color(0xFF7A8599); // --muted-foreground: 215 15% 55%
  static const Color border = Color(0xFF262D3A);         // --border: 220 15% 20%

  // --- Status colors ---
  static const Color statusOperating = Color(0xFF25A55A);      // --status-operating: 145 65% 42%
  static const Color statusOperatingLight = Color(0xFF1A2E22); // dark variant of light bg
  static const Color statusAway = Color(0xFFEDA32D);           // --status-away: 35 90% 55%
  static const Color statusAwayLight = Color(0xFF2E2618);      // dark variant of light bg
  static const Color statusBusy = Color(0xFFED5A2D);           // --status-busy: 15 85% 55%
  static const Color statusBusyLight = Color(0xFF2E1E18);      // dark variant of light bg
  static const Color statusMaintenance = Color(0xFFE04444);    // --status-maintenance: 0 72% 55%
  static const Color statusMaintenanceLight = Color(0xFF2E1A1A); // dark variant

  // --- Convenience ---
  static const Color primaryLight = Color(0xFF1A2640); // primary/10 on dark bg
}

/// Builds the app-wide [ThemeData] for the dark theme.
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'PlusJakartaSans',
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.card,
        primary: AppColors.primary,
        onPrimary: AppColors.primaryForeground,
        onSurface: AppColors.foreground,
      ),
      cardColor: AppColors.card,
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.foreground,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.mutedForeground,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.muted,
        hintStyle: const TextStyle(color: AppColors.mutedForeground, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
