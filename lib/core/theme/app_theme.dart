import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Shared theme factory for AgriCare light and dark modes.
abstract final class AppTheme {
  /// Light color scheme derived from the FarmSync green brand seed.
  static final ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    secondary: AppColors.primaryMid,
    tertiary: AppColors.amberAccent,
    surface: AppColors.surfaceLight,
    surfaceContainerHighest: Colors.white,
    onPrimary: Colors.white,
    onSurfaceVariant: const Color(0xFF6B746C),
    outline: AppColors.borderLight,
    outlineVariant: AppColors.borderLight,
    error: AppColors.syncError,
    shadow: AppColors.primary.withOpacity(0.10),
  );

  /// Dark color scheme derived from the FarmSync green brand seed.
  static final ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primaryLight,
    secondary: AppColors.primaryMid,
    tertiary: AppColors.amberAccent,
    surface: AppColors.cardDark,
    surfaceContainerHighest: const Color(0xFF223729),
    onPrimary: AppColors.surfaceDark,
    onSecondary: Colors.white,
    onTertiary: AppColors.surfaceDark,
    onSurface: const Color(0xFFF0F4EB),
    onSurfaceVariant: AppColors.borderLight.withOpacity(0.74),
    outline: AppColors.borderDark,
    outlineVariant: AppColors.borderDark,
    error: AppColors.syncError,
    shadow: Colors.black.withOpacity(0.24),
  );

  /// Light theme definition for the application.
  static ThemeData get lightTheme => _buildTheme(
        colorScheme: lightColorScheme,
        brightness: Brightness.light,
      );

  /// Dark theme definition for the application.
  static ThemeData get darkTheme => _buildTheme(
        colorScheme: darkColorScheme,
        brightness: Brightness.dark,
      );

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Brightness brightness,
  }) {
    final TextTheme baseTextTheme = brightness == Brightness.light
        ? ThemeData.light(useMaterial3: true).textTheme
        : ThemeData.dark(useMaterial3: true).textTheme;

    final TextTheme textTheme = GoogleFonts.plusJakartaSansTextTheme(
      baseTextTheme,
    ).copyWith(
      displayLarge: GoogleFonts.dmSerifDisplay(
        textStyle: baseTextTheme.displayLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w400,
        ),
      ),
      displayMedium: GoogleFonts.dmSerifDisplay(
        textStyle: baseTextTheme.displayMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w400,
        ),
      ),
      displaySmall: GoogleFonts.dmSerifDisplay(
        textStyle: baseTextTheme.displaySmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w400,
        ),
      ),
      headlineLarge: GoogleFonts.dmSerifDisplay(
        textStyle: baseTextTheme.headlineLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w400,
        ),
      ),
      headlineMedium: GoogleFonts.dmSerifDisplay(
        textStyle: baseTextTheme.headlineMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w400,
        ),
      ),
      headlineSmall: GoogleFonts.dmSerifDisplay(
        textStyle: baseTextTheme.headlineSmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w400,
        ),
      ),
      titleLarge: GoogleFonts.dmSerifDisplay(
        textStyle: baseTextTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w400,
        ),
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.labelLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          brightness == Brightness.light ? AppColors.surfaceLight : AppColors.surfaceDark,
      canvasColor: brightness == Brightness.light ? AppColors.surfaceLight : AppColors.surfaceDark,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: brightness == Brightness.light ? Colors.white : colorScheme.surface,
        elevation: 0,
        shadowColor: colorScheme.shadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: brightness == Brightness.light
            ? AppColors.surfaceLight
            : AppColors.surfaceDark,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: GoogleFonts.dmSerifDisplay(
          color: colorScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w400,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brightness == Brightness.light
            ? Colors.white
            : colorScheme.surfaceContainerHighest,
        indicatorColor: brightness == Brightness.light
            ? AppColors.surfaceSoft
            : colorScheme.primary.withOpacity(0.18),
        height: 86,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            size: 24,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        extendedTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light ? Colors.white : colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.error, width: 1.4),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primary.withOpacity(0.12),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppSpacingTheme.standard,
        AppMotionTheme.standard,
        AppShadowTheme.fromBrightness(brightness),
      ],
    );
  }
}

/// Shared spacing tokens exposed through [ThemeData.extensions].
@immutable
class AppSpacingTheme extends ThemeExtension<AppSpacingTheme> {
  /// Creates a spacing token set.
  const AppSpacingTheme({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  /// Default spacing values using multiples of four.
  static const AppSpacingTheme standard = AppSpacingTheme(
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
    xxl: 48,
  );

  /// Extra small spacing.
  final double xs;

  /// Small spacing.
  final double sm;

  /// Medium spacing.
  final double md;

  /// Large spacing.
  final double lg;

  /// Extra large spacing.
  final double xl;

  /// Double extra large spacing.
  final double xxl;

  @override
  AppSpacingTheme copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
  }) {
    return AppSpacingTheme(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
    );
  }

  @override
  AppSpacingTheme lerp(ThemeExtension<AppSpacingTheme>? other, double t) {
    if (other is! AppSpacingTheme) {
      return this;
    }

    return AppSpacingTheme(
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      xxl: lerpDouble(xxl, other.xxl, t)!,
    );
  }
}

/// Motion tokens exposed through [ThemeData.extensions].
@immutable
class AppMotionTheme extends ThemeExtension<AppMotionTheme> {
  /// Creates a motion token set.
  const AppMotionTheme({
    required this.fast,
    required this.normal,
    required this.slow,
    required this.navCurve,
    required this.cardCurve,
    required this.fabCurve,
  });

  /// Default motion values.
  static const AppMotionTheme standard = AppMotionTheme(
    fast: Duration(milliseconds: 150),
    normal: Duration(milliseconds: 250),
    slow: Duration(milliseconds: 400),
    navCurve: Curves.easeInOut,
    cardCurve: Curves.easeOut,
    fabCurve: Curves.easeOutBack,
  );

  /// Fast duration token.
  final Duration fast;

  /// Normal duration token.
  final Duration normal;

  /// Slow duration token.
  final Duration slow;

  /// Preferred navigation curve.
  final Curve navCurve;

  /// Preferred card motion curve.
  final Curve cardCurve;

  /// Preferred FAB motion curve.
  final Curve fabCurve;

  @override
  AppMotionTheme copyWith({
    Duration? fast,
    Duration? normal,
    Duration? slow,
    Curve? navCurve,
    Curve? cardCurve,
    Curve? fabCurve,
  }) {
    return AppMotionTheme(
      fast: fast ?? this.fast,
      normal: normal ?? this.normal,
      slow: slow ?? this.slow,
      navCurve: navCurve ?? this.navCurve,
      cardCurve: cardCurve ?? this.cardCurve,
      fabCurve: fabCurve ?? this.fabCurve,
    );
  }

  @override
  AppMotionTheme lerp(ThemeExtension<AppMotionTheme>? other, double t) {
    if (other is! AppMotionTheme) {
      return this;
    }

    return AppMotionTheme(
      fast: t < 0.5 ? fast : other.fast,
      normal: t < 0.5 ? normal : other.normal,
      slow: t < 0.5 ? slow : other.slow,
      navCurve: t < 0.5 ? navCurve : other.navCurve,
      cardCurve: t < 0.5 ? cardCurve : other.cardCurve,
      fabCurve: t < 0.5 ? fabCurve : other.fabCurve,
    );
  }
}

/// Shadow tokens exposed through [ThemeData.extensions].
@immutable
class AppShadowTheme extends ThemeExtension<AppShadowTheme> {
  /// Creates a shadow token set.
  const AppShadowTheme({required this.cardShadow});

  /// Box shadow used for elevated cards.
  final BoxShadow cardShadow;

  /// Creates the shadow token set for a specific brightness.
  factory AppShadowTheme.fromBrightness(Brightness brightness) {
    return AppShadowTheme(
      cardShadow: brightness == Brightness.light
          ? BoxShadow(
              color: AppColors.primary.withOpacity(0.10),
              blurRadius: 28,
              offset: const Offset(0, 12),
            )
          : const BoxShadow(
              color: Color(0x33000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
    );
  }

  @override
  AppShadowTheme copyWith({BoxShadow? cardShadow}) {
    return AppShadowTheme(cardShadow: cardShadow ?? this.cardShadow);
  }

  @override
  AppShadowTheme lerp(ThemeExtension<AppShadowTheme>? other, double t) {
    if (other is! AppShadowTheme) {
      return this;
    }

    return AppShadowTheme(
      cardShadow: BoxShadow.lerp(cardShadow, other.cardShadow, t)!,
    );
  }
}
