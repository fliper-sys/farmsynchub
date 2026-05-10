import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Text style constants for FarmSync Jos South.
/// All text styles should be referenced from this file for consistency.
abstract final class AppTextStyles {
  // Display styles (DM Serif Display)
  static TextStyle displayLarge = GoogleFonts.dmSerifDisplay(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    height: 1.12,
  );

  static TextStyle displayMedium = GoogleFonts.dmSerifDisplay(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    height: 1.16,
  );

  static TextStyle displaySmall = GoogleFonts.dmSerifDisplay(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    height: 1.22,
  );

  static TextStyle headlineLarge = GoogleFonts.dmSerifDisplay(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    height: 1.25,
  );

  static TextStyle headlineMedium = GoogleFonts.dmSerifDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 1.29,
  );

  static TextStyle headlineSmall = GoogleFonts.dmSerifDisplay(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 1.33,
  );

  static TextStyle titleLarge = GoogleFonts.dmSerifDisplay(
    fontSize: 22,
    fontWeight: FontWeight.w400,
    height: 1.27,
  );

  static TextStyle titleMedium = GoogleFonts.dmSerifDisplay(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.15,
  );

  static TextStyle titleSmall = GoogleFonts.dmSerifDisplay(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.43,
    letterSpacing: 0.1,
  );

  // Body styles (Plus Jakarta Sans)
  static TextStyle bodyLarge = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.15,
  );

  static TextStyle bodyMedium = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43,
    letterSpacing: 0.25,
  );

  static TextStyle bodySmall = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.33,
    letterSpacing: 0.4,
  );

  // Label styles (Plus Jakarta Sans)
  static TextStyle labelLarge = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.43,
    letterSpacing: 0.1,
  );

  static TextStyle labelMedium = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.33,
    letterSpacing: 0.5,
  );

  static TextStyle labelSmall = GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: 0.5,
  );

  // Button styles
  static TextStyle buttonLarge = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.15,
  );

  static TextStyle buttonMedium = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.43,
    letterSpacing: 0.1,
  );

  static TextStyle buttonSmall = GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.54,
    letterSpacing: 0.46,
  );
}