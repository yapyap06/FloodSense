import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand Palette ──────────────────────────────────────────────────────────
  static const govBlue    = Color(0xFF1E40AF);
  static const govBlueLight = Color(0xFFDBEAFE);
  static const emergency  = Color(0xFFEF4444);
  static const emergencyLight = Color(0xFFFEE2E2);
  static const hope       = Color(0xFF0D9488);
  static const hopeLight  = Color(0xFFCCFBF1);
  static const warning    = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const bgBase     = Color(0xFFF8FAFC);
  static const surface    = Color(0xFFFFFFFF);
  static const border     = Color(0xFFE2E8F0);
  static const textPrimary   = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted     = Color(0xFF94A3B8);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: bgBase,
        colorScheme: const ColorScheme.light(
          primary: govBlue,
          primaryContainer: govBlueLight,
          secondary: hope,
          secondaryContainer: hopeLight,
          error: emergency,
          errorContainer: emergencyLight,
          surface: surface,
          onSurface: textPrimary,
          outline: border,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 28),
          displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 22),
          titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
          titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
          bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
          bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
          labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
          labelSmall: TextStyle(color: textMuted, fontSize: 11, letterSpacing: 0.5),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: border),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: govBlueLight,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return const IconThemeData(color: govBlue);
            return const IconThemeData(color: textMuted);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: govBlue, fontWeight: FontWeight.w600, fontSize: 11);
            }
            return const TextStyle(color: textMuted, fontSize: 11);
          }),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: govBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: govBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: govBlue,
            side: const BorderSide(color: govBlue),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: govBlue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(color: textSecondary),
          hintStyle: const TextStyle(color: textMuted),
        ),
        dividerColor: border,
        chipTheme: ChipThemeData(
          backgroundColor: bgBase,
          selectedColor: govBlueLight,
          labelStyle: const TextStyle(fontSize: 13),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
}
