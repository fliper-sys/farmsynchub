import 'dart:convert';

import 'package:flutter/material.dart';

import 'farm_scene_artwork.dart';

/// Shared building blocks for the crop/livestock list-card pattern: a real
/// photo thumbnail (falling back to decorative artwork), a small stage
/// badge, and a metric row that never wraps to multiple lines regardless of
/// screen width.

/// A card thumbnail that shows the entity's most recent real photo when one
/// exists, decoded at display size (not full resolution) to keep memory and
/// jank down, and falls back to a themed illustration otherwise. Wrapped in
/// a [Hero] so opening the detail screen animates the image into place.
class EntityThumbnail extends StatelessWidget {
  const EntityThumbnail({
    super.key,
    required this.heroTag,
    required this.size,
    required this.artworkVariant,
    this.photoBase64,
    this.emoji,
  });

  final Object heroTag;
  final double size;
  final FarmArtworkVariant artworkVariant;
  final String? photoBase64;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final int cacheSize = (size * MediaQuery.of(context).devicePixelRatio).round();
    final bool hasPhoto = photoBase64 != null && photoBase64!.isNotEmpty;

    Widget child;
    if (hasPhoto) {
      child = Image.memory(
        base64Decode(photoBase64!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
            _fallback(context),
      );
    } else {
      child = _fallback(context);
    }

    return Hero(
      tag: heroTag,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(width: size, height: size, child: child),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    if (emoji != null && emoji!.isNotEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        alignment: Alignment.center,
        child: Text(emoji!, style: TextStyle(fontSize: size * 0.42)),
      );
    }
    return FarmSceneArtwork(
      height: size,
      variant: artworkVariant,
      borderRadius: BorderRadius.zero,
    );
  }
}

/// A small rounded stage/status badge, meant to sit inline next to a title.
class EntityStageBadge extends StatelessWidget {
  const EntityStageBadge({super.key, required this.label, required this.tint});

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background = isDark
        ? Color.alphaBlend(tint.withOpacity(0.24), theme.colorScheme.surface)
        : tint;
    final Color foreground =
        isDark ? theme.colorScheme.onSurface : const Color(0xFF284231);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: isDark ? tint.withOpacity(0.4) : tint.withOpacity(0.85)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class EntityMetric {
  const EntityMetric({required this.label, this.tint});

  final String label;
  final Color? tint;
}

/// A single row of metric chips that scrolls horizontally instead of
/// wrapping — so it never balloons a card to 3-4 lines tall on a narrow
/// phone. Shows [maxVisible] chips, then a "+N more" indicator for the rest.
class EntityMetricChipRow extends StatelessWidget {
  const EntityMetricChipRow({
    super.key,
    required this.metrics,
    this.maxVisible = 3,
  });

  final List<EntityMetric> metrics;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<EntityMetric> visible = metrics.take(maxVisible).toList();
    final int overflow = metrics.length - visible.length;

    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        children: <Widget>[
          for (final EntityMetric metric in visible)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(context, metric.label,
                  metric.tint ?? theme.colorScheme.surfaceContainerHigh, isDark),
            ),
          if (overflow > 0) _overflowChip(context, overflow),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color tint, bool isDark) {
    final ThemeData theme = Theme.of(context);
    final Color background = isDark
        ? Color.alphaBlend(tint.withOpacity(0.22), theme.colorScheme.surface)
        : tint;
    final Color foreground =
        isDark ? theme.colorScheme.onSurfaceVariant : const Color(0xFF44624E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _overflowChip(BuildContext context, int overflow) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: theme.colorScheme.outlineVariant,
            style: BorderStyle.solid),
      ),
      child: Text(
        '+$overflow more',
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
