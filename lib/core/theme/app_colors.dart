import 'package:flutter/material.dart';

/// Centralized application color tokens for AgriCare.
abstract final class AppColors {
  static const Color darkPrimaryBackground = Color(0xFF070B11);
  static const Color darkSecondaryBackground = Color(0xFF0D121A);
  static const Color darkCard = Color(0xFF111827);
  static const Color darkElevatedCard = Color(0xFF151D29);
  static const Color darkBottomNavigation = Color(0xFF0B1018);
  static const Color premiumGreen = Color(0xFF32D583);
  static const Color secondaryGreen = Color(0xFF22C55E);
  static const Color tealAccent = Color(0xFF14B8A6);
  static const Color premiumWarning = Color(0xFFFBBF24);
  static const Color premiumDanger = Color(0xFFEF4444);
  static const Color darkPrimaryText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFFC7CDD6);
  static const Color darkMutedText = Color(0xFF8A93A2);
  static const Color darkBorder = Color(0x661F2937);

  /// Deep botanical green used as the primary brand color.
  static const Color primary = Color(0xFF32D583);

  /// Medium green used for active states and FABs.
  static const Color primaryMid = Color(0xFF22C55E);

  /// Bright green used for progress and highlight states.
  static const Color primaryLight = Color(0xFF32D583);

  /// Warm cream surface for light mode containers.
  static const Color surfaceLight = Color(0xFFFFFBF2);

  /// Soft green-tinted surface for highlighted cards.
  static const Color surfaceSoft = Color(0xFFF2FAEE);

  /// Deep green background for dark mode.
  static const Color surfaceDark = darkPrimaryBackground;

  /// Elevated card surface for dark mode.
  static const Color cardDark = darkCard;

  /// Harvest amber accent for warnings and sunny weather states.
  static const Color amberAccent = premiumWarning;

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
  static const Color borderDark = darkBorder;

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
  static const Color syncSuccess = secondaryGreen;

  /// Pending sync indicator color.
  static const Color syncPending = Color(0xFFE8A020);

  /// Error indicator color.
  static const Color syncError = premiumDanger;
}
