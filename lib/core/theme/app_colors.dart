import 'package:flutter/material.dart';

/// Centralized application color tokens for AgriCare.
abstract final class AppColors {
  /// Deep botanical green used as the primary brand color.
  static const Color primary = Color(0xFF214B34);

  /// Medium green used for active states and FABs.
  static const Color primaryMid = Color(0xFF4D8F5E);

  /// Bright green used for progress and highlight states.
  static const Color primaryLight = Color(0xFF81C784);

  /// Warm cream surface for light mode containers.
  static const Color surfaceLight = Color(0xFFFFFBF2);

  /// Soft green-tinted surface for highlighted cards.
  static const Color surfaceSoft = Color(0xFFF2FAEE);

  /// Deep green background for dark mode.
  static const Color surfaceDark = Color(0xFF0F1F13);

  /// Elevated card surface for dark mode.
  static const Color cardDark = Color(0xFF1A2E1F);

  /// Harvest amber accent for warnings and sunny weather states.
  static const Color amberAccent = Color(0xFFF2BE63);

  /// Golden surface used in weather hero cards.
  static const Color sunGold = Color(0xFFF8D58A);

  /// Soft sky blue used across illustrated backgrounds.
  static const Color skyBlue = Color(0xFFB9E3FF);

  /// Fresh mint used for subtle gradients and chips.
  static const Color mint = Color(0xFFCFEFBD);

  /// Field green used in illustrations.
  static const Color leafGreen = Color(0xFF3F8B4C);

  /// Soil-inspired brown for input and soil related data.
  static const Color soilBrown = Color(0xFF8B5E3C);

  /// Light border color for cards and input outlines.
  static const Color borderLight = Color(0xFFE7E8DD);

  /// Dark border color for dark surfaces.
  static const Color borderDark = Color(0xFF2A4A35);

  /// Subsistence farmer badge background.
  static const Color subsistenceBadgeBackground = Color(0xFFF5D060);

  /// Subsistence farmer badge foreground.
  static const Color subsistenceBadgeForeground = Color(0xFFBF8000);

  /// Semi-commercial farmer badge background.
  static const Color semiCommercialBadgeBackground = Color(0xFF90CAF9);

  /// Semi-commercial farmer badge foreground.
  static const Color semiCommercialBadgeForeground = Color(0xFF1565C0);

  /// Market-oriented farmer badge background.
  static const Color marketOrientedBadgeBackground = Color(0xFF7DD3A8);

  /// Market-oriented farmer badge foreground.
  static const Color marketOrientedBadgeForeground = Color(0xFF1A6635);

  /// Synced indicator color.
  static const Color syncSuccess = Color(0xFF4CAF76);

  /// Pending sync indicator color.
  static const Color syncPending = Color(0xFFE8A020);

  /// Error indicator color.
  static const Color syncError = Color(0xFFC65B46);
}
