import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'app_card.dart';
import 'farm_scene_artwork.dart';

class SoftScreenScaffold extends StatelessWidget {
  const SoftScreenScaffold({
    super.key,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.heroIcon,
    required this.heroVariant,
    required this.sections,
    this.heroBadge,
    this.trailing,
    this.onBack,
    this.showArtwork = true,
    this.scrollController,
  });

  final String heroTitle;
  final String heroSubtitle;
  final IconData heroIcon;
  final FarmArtworkVariant heroVariant;
  final List<Widget> sections;
  final String? heroBadge;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool showArtwork;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? <Color>[
                  const Color(0xFF0B1610),
                  const Color(0xFF102219),
                  scheme.surface,
                ]
              : <Color>[
                  const Color(0xFFFFFBF2),
                  const Color(0xFFF1F8EE),
                ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 560;
              final double titleSize = compact ? 22 : 30;
              final double artworkHeight = compact ? 170 : 200;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppCard(
                    color: scheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (compact) ...<Widget>[
                            if (onBack != null) ...<Widget>[
                              Align(
                                alignment: Alignment.topLeft,
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  color: isDark
                                      ? theme.colorScheme.onSurface
                                      : AppColors.primary,
                                  onPressed: onBack,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSoft,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child:
                                      Icon(heroIcon, color: AppColors.primary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      if (heroBadge != null) ...<Widget>[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceSoft,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            heroBadge!,
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                              color: AppColors.primaryMid,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                      Text(
                                        heroTitle,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                          fontSize: titleSize,
                                          color: AppColors.primary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        heroSubtitle,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          height: 1.6,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: compact ? 4 : 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (trailing != null) ...<Widget>[
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: trailing!,
                              ),
                            ],
                          ] else ...<Widget>[
                            if (onBack != null) ...<Widget>[
                              IconButton(
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: isDark
                                    ? theme.colorScheme.onSurface
                                    : AppColors.primary,
                                onPressed: onBack,
                              ),
                              const SizedBox(width: 12),
                            ],
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSoft,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child:
                                      Icon(heroIcon, color: AppColors.primary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      if (heroBadge != null) ...<Widget>[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceSoft,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            heroBadge!,
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                              color: AppColors.primaryMid,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      Text(
                                        heroTitle,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                          fontSize: titleSize,
                                          color: AppColors.primary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        heroSubtitle,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          height: 1.6,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: compact ? 4 : 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (trailing != null) ...<Widget>[
                                  const SizedBox(width: 12),
                                  trailing!,
                                ],
                              ],
                            ),
                          ],
                          if (showArtwork) ...<Widget>[
                            const SizedBox(height: 18),
                            FarmSceneArtwork(
                              height: artworkHeight,
                              variant: heroVariant,
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(28)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...sections,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class SoftSectionTitle extends StatelessWidget {
  const SoftSectionTitle({
    super.key,
    required this.title,
    this.action,
    this.titleStyle,
  });

  final String title;
  final Widget? action;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: titleStyle ??
                  theme.textTheme.titleLarge?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.onSurface
                        : AppColors.primary,
                  ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class SoftInfoChip extends StatelessWidget {
  const SoftInfoChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background = isDark
        ? Color.alphaBlend(color.withOpacity(0.20), theme.colorScheme.surface)
        : color.withOpacity(0.18);
    final Color borderColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.08)
        : theme.colorScheme.primary.withOpacity(0.18);
    final Color labelColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurfaceVariant;
    final Color valueColor =
        isDark ? theme.colorScheme.onSurface : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: valueColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleLarge?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
