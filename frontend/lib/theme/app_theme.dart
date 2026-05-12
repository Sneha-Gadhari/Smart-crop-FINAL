import 'package:flutter/material.dart';

class AppTheme {
// Brand Colors
static const Color primary = Color(0xFF2E7D32);        // Deep Green
static const Color primaryLight = Color(0xFF4CAF50);   // Medium Green
static const Color primarySurface = Color(0xFFE8F5E9); // Light Green tint
static const Color accent = Color(0xFF8BC34A);         // Lime Green
static const Color accentAmber = Color(0xFFF59E0B);    // Amber for medium risk
static const Color accentRed = Color(0xFFEF4444);      // Red for high risk
static const Color surface = Color(0xFFF9FAFB);        // Off-white surface
static const Color cardBg = Color(0xFFFFFFFF);
static const Color textPrimary = Color(0xFF1A2E1A);
static const Color textSecondary = Color(0xFF6B7280);
static const Color divider = Color(0xFFE5E7EB);
static const Color inputBorder = Color(0xFFD1D5DB);

static ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: primary,
    primary: primary,
    secondary: accent,
    surface: surface,
    background: surface,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: surface,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: textPrimary,
    elevation: 0,
    scrolledUnderElevation: 1,
    surfaceTintColor: Colors.white,
    titleTextStyle: TextStyle(
      color: textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primary,
      side: const BorderSide(color: primary, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  cardTheme: CardTheme(
    color: cardBg,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: divider, width: 1),
    ),
    margin: EdgeInsets.zero,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: inputBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: inputBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  sliderTheme: SliderThemeData(
    activeTrackColor: primary,
    thumbColor: primary,
    inactiveTrackColor: primarySurface,
    overlayColor: primary.withOpacity(0.12),
    trackHeight: 4,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: primarySurface,
    labelStyle: const TextStyle(color: primary, fontWeight: FontWeight.w500, fontSize: 13),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  dividerTheme: const DividerThemeData(color: divider, thickness: 1, space: 1),
  fontFamily: 'SF Pro Display', // Falls back to system font
);
}
