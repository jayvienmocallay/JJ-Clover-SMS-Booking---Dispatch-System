// Task 010 — App theme with dark mode color scheme
// Color palette derived from the UI design's CSS variables
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  /// Returns the current theme's color palette.
  /// Use this in build methods instead of static constants for theme-aware colors.
  static AppPalette of(BuildContext context) => AppPalette.of(context);
}

/// Builds the app-wide [ThemeData] for the dark theme.
class AppTheme {
  static ThemeData get darkTheme {
    final textTheme = TextTheme(
      displayLarge:  GoogleFonts.quicksand(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.foreground),
      headlineLarge: GoogleFonts.quicksand(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.foreground),
      headlineMedium:GoogleFonts.quicksand(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.foreground),
      headlineSmall: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.foreground),
      titleLarge:    GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground),
      titleMedium:   GoogleFonts.quicksand(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.foreground),
      titleSmall:    GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground),
      bodyLarge:     GoogleFonts.nunitoSans(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.foreground),
      bodyMedium:    GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.foreground),
      bodySmall:     GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.mutedForeground),
      labelLarge:    GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.foreground),
      labelMedium:   GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.mutedForeground),
      labelSmall:    GoogleFonts.nunitoSans(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.mutedForeground),
    );

    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.nunitoSans().fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.card,
        primary: AppColors.primary,
        onPrimary: AppColors.primaryForeground,
        onSurface: AppColors.foreground,
        error: AppColors.statusMaintenance,
      ),
      cardColor: AppColors.card,
      dividerColor: AppColors.border,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.foreground,
        elevation: 0,
        titleTextStyle: GoogleFonts.quicksand(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.foreground,
        ),
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
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.statusMaintenance),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.statusMaintenance, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.muted,
        contentTextStyle: GoogleFonts.nunitoSans(
          color: AppColors.foreground,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.quicksand(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.foreground,
        ),
        contentTextStyle: GoogleFonts.nunitoSans(
          fontSize: 14,
          color: AppColors.mutedForeground,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      extensions: const [_darkPalette],
    );
  }

  static ThemeData get lightTheme {
    final textTheme = TextTheme(
      displayLarge:   GoogleFonts.quicksand(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
      headlineLarge:  GoogleFonts.quicksand(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
      headlineMedium: GoogleFonts.quicksand(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
      headlineSmall:  GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
      titleLarge:     GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
      titleMedium:    GoogleFonts.quicksand(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
      titleSmall:     GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A)),
      bodyLarge:      GoogleFonts.nunitoSans(fontSize: 14, fontWeight: FontWeight.w400, color: const Color(0xFF0F172A)),
      bodyMedium:     GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.w400, color: const Color(0xFF0F172A)),
      bodySmall:      GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w400, color: const Color(0xFF64748B)),
      labelLarge:     GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
      labelMedium:    GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
      labelSmall:     GoogleFonts.nunitoSans(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
    );

    return ThemeData(
      brightness: Brightness.light,
      fontFamily: GoogleFonts.nunitoSans().fontFamily,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        surface: Color(0xFFFFFFFF),
        primary: Color(0xFF2D7AED),
        onPrimary: Colors.white,
        onSurface: Color(0xFF0F172A),
        error: Color(0xFFDC2626),
      ),
      cardColor: const Color(0xFFFFFFFF),
      dividerColor: const Color(0xFFE2E8F0),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        titleTextStyle: GoogleFonts.quicksand(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        selectedItemColor: Color(0xFF2D7AED),
        unselectedItemColor: Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2D7AED),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D7AED), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        contentTextStyle: GoogleFonts.nunitoSans(
          color: const Color(0xFF0F172A),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.quicksand(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
        contentTextStyle: GoogleFonts.nunitoSans(
          fontSize: 14,
          color: const Color(0xFF64748B),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),
      extensions: const [_lightPalette],
    );
  }
}

/// Dynamic color palette accessed via Theme.of(context).extension for AppPalette.
/// Provides light and dark variants for all app-specific colors.
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color card;
  final Color foreground;
  final Color primary;
  final Color primaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color border;
  final Color statusOperating;
  final Color statusOperatingLight;
  final Color statusAway;
  final Color statusAwayLight;
  final Color statusBusy;
  final Color statusBusyLight;
  final Color statusMaintenance;
  final Color statusMaintenanceLight;
  final Color primaryLight;

  const AppPalette({
    required this.background,
    required this.card,
    required this.foreground,
    required this.primary,
    required this.primaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.border,
    required this.statusOperating,
    required this.statusOperatingLight,
    required this.statusAway,
    required this.statusAwayLight,
    required this.statusBusy,
    required this.statusBusyLight,
    required this.statusMaintenance,
    required this.statusMaintenanceLight,
    required this.primaryLight,
  });

  @override
  AppPalette copyWith({
    Color? background,
    Color? card,
    Color? foreground,
    Color? primary,
    Color? primaryForeground,
    Color? muted,
    Color? mutedForeground,
    Color? border,
    Color? statusOperating,
    Color? statusOperatingLight,
    Color? statusAway,
    Color? statusAwayLight,
    Color? statusBusy,
    Color? statusBusyLight,
    Color? statusMaintenance,
    Color? statusMaintenanceLight,
    Color? primaryLight,
  }) =>
      AppPalette(
        background: background ?? this.background,
        card: card ?? this.card,
        foreground: foreground ?? this.foreground,
        primary: primary ?? this.primary,
        primaryForeground: primaryForeground ?? this.primaryForeground,
        muted: muted ?? this.muted,
        mutedForeground: mutedForeground ?? this.mutedForeground,
        border: border ?? this.border,
        statusOperating: statusOperating ?? this.statusOperating,
        statusOperatingLight: statusOperatingLight ?? this.statusOperatingLight,
        statusAway: statusAway ?? this.statusAway,
        statusAwayLight: statusAwayLight ?? this.statusAwayLight,
        statusBusy: statusBusy ?? this.statusBusy,
        statusBusyLight: statusBusyLight ?? this.statusBusyLight,
        statusMaintenance: statusMaintenance ?? this.statusMaintenance,
        statusMaintenanceLight:
            statusMaintenanceLight ?? this.statusMaintenanceLight,
        primaryLight: primaryLight ?? this.primaryLight,
      );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryForeground:
          Color.lerp(primaryForeground, other.primaryForeground, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      border: Color.lerp(border, other.border, t)!,
      statusOperating:
          Color.lerp(statusOperating, other.statusOperating, t)!,
      statusOperatingLight:
          Color.lerp(statusOperatingLight, other.statusOperatingLight, t)!,
      statusAway: Color.lerp(statusAway, other.statusAway, t)!,
      statusAwayLight:
          Color.lerp(statusAwayLight, other.statusAwayLight, t)!,
      statusBusy: Color.lerp(statusBusy, other.statusBusy, t)!,
      statusBusyLight:
          Color.lerp(statusBusyLight, other.statusBusyLight, t)!,
      statusMaintenance:
          Color.lerp(statusMaintenance, other.statusMaintenance, t)!,
      statusMaintenanceLight: Color.lerp(
          statusMaintenanceLight, other.statusMaintenanceLight, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
    );
  }

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;
}

const _darkPalette = AppPalette(
  background: Color(0xFF101418),
  card: Color(0xFF171C24),
  foreground: Color(0xFFE8ECF0),
  primary: Color(0xFF2D7AED),
  primaryForeground: Colors.white,
  muted: Color(0xFF1E2330),
  mutedForeground: Color(0xFF7A8599),
  border: Color(0xFF262D3A),
  statusOperating: Color(0xFF25A55A),
  statusOperatingLight: Color(0xFF1A2E22),
  statusAway: Color(0xFFEDA32D),
  statusAwayLight: Color(0xFF2E2618),
  statusBusy: Color(0xFFED5A2D),
  statusBusyLight: Color(0xFF2E1E18),
  statusMaintenance: Color(0xFFE04444),
  statusMaintenanceLight: Color(0xFF2E1A1A),
  primaryLight: Color(0xFF1A2640),
);

const _lightPalette = AppPalette(
  background: Color(0xFFF8FAFC),
  card: Color(0xFFFFFFFF),
  foreground: Color(0xFF0F172A),
  primary: Color(0xFF2D7AED),
  primaryForeground: Colors.white,
  muted: Color(0xFFF1F5F9),
  mutedForeground: Color(0xFF64748B),
  border: Color(0xFFE2E8F0),
  statusOperating: Color(0xFF16A34A),
  statusOperatingLight: Color(0xFFDCFCE7),
  statusAway: Color(0xFFD97706),
  statusAwayLight: Color(0xFFFEF3C7),
  statusBusy: Color(0xFFEA580C),
  statusBusyLight: Color(0xFFFFEDD5),
  statusMaintenance: Color(0xFFDC2626),
  statusMaintenanceLight: Color(0xFFFEE2E2),
  primaryLight: Color(0xFFEFF6FF),
);

// Layout constants — used across all screens and widgets
const double kPagePadding = 16;
const double kCardPadding = 16;
const double kCardRadius = 16;
const double kButtonRadius = 12;
const double kSectionGap = 20;
const double kCompactGap = 8;
