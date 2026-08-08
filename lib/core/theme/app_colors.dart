import 'package:flutter/material.dart';

/// Centralized application color tokens for AgriCare.
abstract final class AppColors {
  // Dark-mode elevation ladder: each level is a deliberate step lighter than
  // the one below (never one flat grey reused everywhere). Level 0 stays
  // near-black for OLED battery savings; sheets/dialogs/bottom nav sit on
  // level 2, popovers/menus on level 3.
  /// Level 0 — app scaffold background.
  static const Color darkPrimaryBackground = Color(0xFF0B0F0D);

  /// Level 1 — cards, chips, input fields.
  static const Color darkSecondaryBackground = Color(0xFF121714);

  /// Level 1 — alias of [darkSecondaryBackground] for card surfaces.
  static const Color darkCard = Color(0xFF121714);

  /// Level 2 — bottom sheets, dialogs, popovers.
  static const Color darkElevatedCard = Color(0xFF1A211D);

  /// Level 2 — bottom navigation bar.
  static const Color darkBottomNavigation = Color(0xFF1A211D);

  /// Level 3 — menus, tooltips, nested overlays.
  static const Color darkOverlaySurface = Color(0xFF232B26);

  static const Color premiumGreen = Color(0xFF34D399);
  static const Color secondaryGreen = Color(0xFF10B981);
  static const Color tealAccent = Color(0xFF2DD4BF);
  static const Color premiumWarning = Color(0xFFF5B14C);
  static const Color premiumDanger = Color(0xFFF0645C);
  static const Color infoAccent = Color(0xFF60A5FA);

  /// Off-white instead of pure white — pure #FFFFFF on a near-black
  /// background is the single biggest cause of dark-mode eye strain.
  static const Color darkPrimaryText = Color(0xFFEDEFEC);
  static const Color darkSecondaryText = Color(0xFFA9B3AC);
  static const Color darkMutedText = Color(0xFF737F76);
  static const Color darkBorder = Color(0x17EDEFEC);

  /// Deep botanical green used as the primary brand color.
  static const Color primary = premiumGreen;

  /// Medium green used for active states and FABs.
  static const Color primaryMid = secondaryGreen;

  /// Bright green used for progress and highlight states.
  static const Color primaryLight = premiumGreen;

  // Light-mode elevation ladder: a deliberately warm "milk cream" family —
  // closer to the colour of dairy milk/cream than an off-white — kept
  // consistent end to end (background AND cards) instead of a cream
// background with cards that jump to pure white.
  /// Level 0 — app scaffold background.
  static const Color surfaceLight = Color.fromARGB(255, 241, 236, 224);

  /// Level 0/-1 — lightest cream for lowest surface tier.
  static const Color surfaceLightLowest = Color.fromARGB(255, 250, 247, 240);

  /// Level 0 — soft cream for low surface tier.
  static const Color surfaceLightLow = Color.fromARGB(255, 244, 240, 228);

  /// Level 1 — cards, chips, input fields.
  static const Color surfaceLightCard = Color.fromARGB(255, 240, 232, 220);

  /// Level 1 — container tier (matches [surfaceLightCard]).
  static const Color surfaceLightContainer = Color.fromARGB(255, 240, 232, 220);

  /// Level 2 — bottom sheets, dialogs, bottom navigation, popovers.
  static const Color surfaceLightElevated = Color(0xFFFFF4E4);

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

  /// Blends a light-mode pastel tag/chip/badge color into a dark-mode-safe
  /// version instead of showing the raw pastel on a near-black background.
  /// A handful of widgets already do this inline (e.g. the news tag chips);
  /// this centralizes that pattern so it can be reused everywhere the same
  /// hardcoded-pastel-on-dark clash shows up (crop/livestock stat chips,
  /// badges, etc).
  static Color chipBackgroundFor(
    Color pastel, {
    required bool isDark,
    required Color surface,
  }) {
    return isDark ? Color.alphaBlend(pastel.withOpacity(0.22), surface) : pastel;
  }

  /// Matching foreground for [chipBackgroundFor].
  static Color chipForegroundFor({
    required bool isDark,
    required Color onSurface,
  }) {
    return isDark ? onSurface : const Color(0xFF284231);
  }
}
