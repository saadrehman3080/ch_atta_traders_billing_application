import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'color_schemes.dart';

class AppTheme {
  static ThemeData light = ThemeData(
    useMaterial3: true,

    // Google Fonts base theme
    textTheme: GoogleFonts.poppinsTextTheme(),

    scaffoldBackgroundColor: Colors.white,
    textSelectionTheme: TextSelectionThemeData(
      selectionHandleColor: AppColors.pepsiWhite,
      selectionColor: AppColors.textSecondary,
      cursorColor: AppColors.pepsiWhite,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputBg,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.textError, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.textError, width: 1.5),
      ),
      errorStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.textError),
    ),

    // Button theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size(double.infinity, 52)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
      ),
    ),
  );
}
