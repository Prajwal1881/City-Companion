import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg         = Color(0xFFF7F6F2);
  static const card       = Color(0xFFFFFFFF);
  static const ink        = Color(0xFF0A0A0A);
  static const sub        = Color(0xFF6B6B6B);
  static const muted      = Color(0xFFADADAD);
  static const border     = Color(0xFFEBEBEB);
  static const orange     = Color(0xFFFF4D00);
  static const blue       = Color(0xFF0057FF);
  static const green      = Color(0xFF00C851);
  static const violet     = Color(0xFF7C3AED);
  static const teal       = Color(0xFF00A896);
  static const amber      = Color(0xFFFFAB00);
  static const rose       = Color(0xFFFF2D55);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.light(
      primary: AppColors.orange,
      secondary: AppColors.blue,
      surface: AppColors.card,
      background: AppColors.bg,
    ),
    textTheme: GoogleFonts.dmSansTextTheme().copyWith(
      displayLarge: GoogleFonts.fraunces(fontWeight: FontWeight.w900),
      displayMedium: GoogleFonts.fraunces(fontWeight: FontWeight.w800),
      headlineLarge: GoogleFonts.fraunces(fontWeight: FontWeight.w800),
      headlineMedium: GoogleFonts.fraunces(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.card,
      foregroundColor: AppColors.ink,
      elevation: 0,
      titleTextStyle: GoogleFonts.fraunces(
        fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 15),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.orange, width: 2),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.card,
      selectedItemColor: AppColors.orange,
      unselectedItemColor: AppColors.muted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}
