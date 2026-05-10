import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Custom button widget following FarmSync design system.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.onLongPress,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  }) : isSecondary = false;

  AppButton.primary({
    super.key,
    required this.onPressed,
    required this.child,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  }) : style = ButtonStyle(
         backgroundColor: MaterialStatePropertyAll(AppColors.primary),
         foregroundColor: MaterialStatePropertyAll(AppColors.surfaceLight),
         elevation: MaterialStatePropertyAll(0),
         shadowColor: MaterialStatePropertyAll(AppColors.primary.withOpacity(0.2)),
         shape: MaterialStatePropertyAll(
           RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(24),
           ),
         ),
         padding: MaterialStatePropertyAll(
           EdgeInsets.symmetric(horizontal: 24, vertical: 16),
         ),
         textStyle: MaterialStatePropertyAll(
           GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
       ),
       isSecondary = false;

  AppButton.secondary({
    super.key,
    required this.onPressed,
    required this.child,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  }) : style = ButtonStyle(
         foregroundColor: MaterialStatePropertyAll(AppColors.primary),
         elevation: MaterialStatePropertyAll(0),
         shape: MaterialStatePropertyAll(
           RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(24),
           ),
         ),
         padding: MaterialStatePropertyAll(
           EdgeInsets.symmetric(horizontal: 24, vertical: 16),
         ),
         textStyle: MaterialStatePropertyAll(
           GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
       ),
       isSecondary = true;

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget child;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle fallbackStyle = ButtonStyle(
      padding: const MaterialStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      shape: MaterialStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      textStyle: MaterialStatePropertyAll(
        GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final ButtonStyle baseStyle = style ?? fallbackStyle;
    final ButtonStyle resolvedStyle = isSecondary
        ? baseStyle.copyWith(
            backgroundColor: MaterialStatePropertyAll(Theme.of(context).colorScheme.surface),
            foregroundColor: MaterialStatePropertyAll(Theme.of(context).colorScheme.primary),
            side: MaterialStatePropertyAll(
              BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
          )
        : baseStyle;

    return ElevatedButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      style: resolvedStyle,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}
