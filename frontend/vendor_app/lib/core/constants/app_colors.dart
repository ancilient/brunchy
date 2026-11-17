// Core color tokens for Brunchy Vendor App: a teal palette (the student app is yellow/orange).
// The burger logo keeps its orange bun; teal is the vendor app's own colour.
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Teal brand
  static const Color primary          = Color(0xFF0D9488); // buttons, active tabs, focus, progress
  static const Color primaryDark      = Color(0xFF0F766E); // pressed states, gradients
  static const Color primaryLight     = Color(0xFF99F6E4); // switch tracks, soft fills
  static const Color brandTeal        = Color(0xFF14C4AE); // the logo disc, splash, drawer header, highlights
  static const Color ink              = Color(0xFF134E4A); // headings, icons, snackbars

  // Accents with a meaning (not brand colours)
  static const Color attention        = Color(0xFFF97316); // overload level 2, queue position
  static const Color accent           = Color(0xFFFBBF24); // stars / small highlights
  static const Color errorRed         = Color(0xFFE53935);
  static const Color warningAmber     = Color(0xFFFFA000);
  static const Color successGreen     = Color(0xFF16A34A);

  // Surfaces and text
  static const Color background       = Color(0xFFF1FAF8); // soft mint
  static const Color cardWhite        = Color(0xFFFFFFFF);
  static const Color white            = Color(0xFFFFFFFF);
  static const Color textPrimary      = Color(0xFF0B2522);
  static const Color textSecondary    = Color(0xFF4A6D68);
  static const Color divider          = Color(0xFFD6ECE8);
  static const Color shadow           = Color(0x1A134E4A);

  // Greys
  static const Color grey50           = Color(0xFFFAFAFA);
  static const Color grey100          = Color(0xFFF5F5F5);
  static const Color grey200          = Color(0xFFEEEEEE);
  static const Color grey300          = Color(0xFFE0E0E0);
  static const Color grey400          = Color(0xFFBDBDBD);
  static const Color grey500          = Color(0xFF9E9E9E);
  static const Color grey600          = Color(0xFF757575);
  static const Color grey700          = Color(0xFF616161);
  static const Color grey800          = Color(0xFF424242);
}
