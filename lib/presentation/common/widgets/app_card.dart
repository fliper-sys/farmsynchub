import 'package:flutter/material.dart';

/// Custom card widget following FarmSync design system.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    this.child,
    this.color,
    this.shadowColor,
    this.surfaceTintColor,
    this.elevation,
    this.shape,
    this.borderOnForeground = true,
    this.margins,
    this.clipBehavior,
    this.semanticContainer = true,
    this.onTap,
    this.onLongPress,
  });

  final Widget? child;
  final Color? color;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final double? elevation;
  final ShapeBorder? shape;
  final bool borderOnForeground;
  final EdgeInsetsGeometry? margins;
  final Clip? clipBehavior;
  final bool semanticContainer;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: color ?? Theme.of(context).colorScheme.surface,
      shadowColor: shadowColor ?? Theme.of(context).colorScheme.shadow,
      surfaceTintColor: surfaceTintColor,
      elevation: elevation ?? 0,
      shape: shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
      borderOnForeground: borderOnForeground,
      clipBehavior: clipBehavior,
      semanticContainer: semanticContainer,
      child: child,
    );

    if (margins != null) {
      return Padding(
        padding: margins!,
        child: card,
      );
    }

    if (onTap != null || onLongPress != null) {
      return InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(28),
        child: card,
      );
    }

    return card;
  }
}
