import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';

class AppTextStyles {
  // Page Headers & Titles
  static final pageTitle = GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontStyle: FontStyle.italic,
    letterSpacing: 1.2,
  );

  static final pageTitleBlack = GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  static final pageSubtitle = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary.withValues(alpha: 0.85),
  );

  // Form & Input Styles
  static final fieldLabel = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static final inputText = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary.withValues(alpha: 0.95),
  );

  static final inputHint = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.gray400,
  );

  // Button Styles
  static final buttonLabel = GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static final smallButton = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Status & Feedback Messages
  static final errorMessage = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textError,
  );

  static final successMessage = GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSuccess,
  );

  // Footer & Helper Text
  static final helperText = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary.withValues(alpha: 0.6),
  );

  static final footerText = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w300,
    color: AppColors.textPrimary.withValues(alpha: 0.7),
  );

  // Billing card specific styles
  static final billingItems = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Colors.white70,
  );

  static final billingTotal = GoogleFonts.poppins(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static final productItemName = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );

  static final productItemQuantity = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Colors.black.withValues(alpha: 0.6),
  );

  static final productItemTotal = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  // Legacy aliases for backward compatibility
  static final title = pageTitle;
  static final subtitle = pageSubtitle;
  static final credentialsHeading = fieldLabel;
  static final label = fieldLabel;
  static final input = inputText;
  static final button = smallButton;
  static final footer = footerText;
  static final loginButtonText = buttonLabel;
}
