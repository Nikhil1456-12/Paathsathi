import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // ── Brand Palette (UI 2 inspired — Indian Flag) ─────────────
  static const Color primaryGreen      = Color(0xFF1A6B3C);
  static const Color primaryGreenLight = Color(0xFF2E8B57);
  static const Color primaryGreenDark  = Color(0xFF0D4A28);
  static const Color greenGlow         = Color(0x201A6B3C);

  static const Color saffron           = Color(0xFFFF6B00);
  static const Color saffronLight      = Color(0xFFFF8C00);
  static const Color saffronDark       = Color(0xFFCC5500);
  static const Color saffronGlow       = Color(0x20FF6B00);

  // ── Background & Surface ────────────────────────────────────
  static const Color background        = Color(0xFFF6F8F7);
  static const Color surface           = Color(0xFFFFFFFF);
  static const Color surfaceElevated   = Color(0xFFF0F4F2);

  // ── Text ────────────────────────────────────────────────────
  static const Color textPrimary       = Color(0xFF111827);
  static const Color textSecondary     = Color(0xFF4B5563);
  static const Color textMuted         = Color(0xFF9CA3AF);
  static const Color textOnGreen       = Color(0xFFFFFFFF);

  // ── Status ──────────────────────────────────────────────────
  static const Color success           = Color(0xFF16A34A);
  static const Color successLight      = Color(0xFFDCFCE7);
  static const Color warning           = Color(0xFFF59E0B);
  static const Color warningLight      = Color(0xFFFEF3C7);
  static const Color danger            = Color(0xFFDC2626);
  static const Color dangerLight       = Color(0xFFFEE2E2);
  static const Color info              = Color(0xFF2563EB);
  static const Color infoLight         = Color(0xFFDBEAFE);

  // ── Border & Divider ────────────────────────────────────────
  static const Color border            = Color(0xFFE5E7EB);
  static const Color divider           = Color(0xFFF3F4F6);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary:   AppColors.primaryGreen,
        secondary: AppColors.saffron,
        surface:   AppColors.surface,
        error:     AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge:  GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        displayMedium: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleLarge:    GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium:   GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge:     GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
        bodyMedium:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        bodySmall:     GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted),
        labelLarge:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.saffron,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 11),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
    );
  }
}
