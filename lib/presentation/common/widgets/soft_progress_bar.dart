import 'package:flutter/material.dart';

/// A flat, pill-shaped progress bar matching the app's soft card aesthetic.
class SoftProgressBar extends StatelessWidget {
  const SoftProgressBar({
    super.key,
    required this.progress,
    required this.tint,
  });

  final double progress;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color track = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.08)
        : theme.colorScheme.outlineVariant.withOpacity(0.5);
    final Color fill = isDark
        ? Color.alphaBlend(tint.withOpacity(0.55), theme.colorScheme.surface)
        : tint;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 8,
        color: track,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
