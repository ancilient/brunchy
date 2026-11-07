import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextTheme get textTheme => TextTheme(
    displayLarge: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.brandBrown),
    headlineMedium: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.brandBrown),
    titleLarge: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    titleMedium: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    bodyLarge: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
    bodyMedium: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
    labelLarge: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
    labelMedium: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    labelSmall: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
  );
}

