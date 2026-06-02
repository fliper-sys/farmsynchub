import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../providers/app_preferences_provider.dart';

/// Grid of quick action buttons for common tasks.
class QuickActionsGrid extends ConsumerWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool compact = width < 420;
        final int crossAxisCount = compact ? 2 : 3;
        final double spacing = compact ? 12 : 16;
        final double childAspectRatio = compact ? 1.08 : 0.96;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: <Widget>[
            _QuickActionButton(
              compact: compact,
              label: language.tr(en: 'My Farm', ha: 'Gonaki na', fr: 'Ma ferme'),
              subtitle: language.tr(en: 'Land records and setup', ha: 'Takardun gona da saitin aiki', fr: 'Parcelles et configuration'),
              icon: Icons.landscape_rounded,
              tint: const Color(0xFFDDF2C9),
              route: '/farms',
            ),
            _QuickActionButton(
              compact: compact,
              label: language.tr(en: 'Crops', ha: 'Amfanin gona', fr: 'Cultures'),
              subtitle: language.tr(en: 'Stages and planting', ha: 'Matakai da shuka', fr: 'Etapes et plantation'),
              icon: Icons.spa_rounded,
              tint: const Color(0xFFD8F2E5),
              route: '/crops',
            ),
            _QuickActionButton(
              compact: compact,
              label: language.tr(en: 'Livestock', ha: 'Dabbobi', fr: 'Bétail'),
              subtitle: language.tr(en: 'Animals and count', ha: 'Dabbobi da kidaya', fr: 'Animaux et nombre'),
              icon: Icons.inventory_2_rounded,
              tint: const Color(0xFFE4F1FF),
              route: '/livestock',
            ),
            _QuickActionButton(
              compact: compact,
              label: language.tr(en: 'Sales', ha: 'Siyarwa', fr: 'Ventes'),
              subtitle: language.tr(en: 'Receipts and finance', ha: 'Karbar kudi da kudi', fr: 'Reçus et finances'),
              icon: Icons.savings_rounded,
              tint: const Color(0xFFFFE9BF),
              route: '/finance',
            ),
            _QuickActionButton(
              compact: compact,
              label: language.tr(en: 'Learn', ha: 'Koyo', fr: 'Apprendre'),
              subtitle: language.tr(en: 'Lessons and practice', ha: 'Darussa da atisaye', fr: 'Leçons et pratique'),
              icon: Icons.school_rounded,
              tint: const Color(0xFFFFEEE4),
              route: '/learn',
            ),
            _QuickActionButton(
              compact: compact,
              label: language.tr(en: 'AI Advisor', ha: 'Mai ba da shawara', fr: 'Conseiller IA'),
              subtitle: language.tr(en: 'Ask for field help', ha: 'Tambayi taimakon gona', fr: 'Demander de l aide'),
              icon: Icons.auto_awesome_rounded,
              tint: const Color(0xFFEDE8FF),
              route: '/ai-advisor',
            ),
            _QuickActionButton(
              compact: compact,
              label: language.tr(en: 'News', ha: 'Labarai', fr: 'Actualites'),
              subtitle: language.tr(en: 'Feeds and updates', ha: 'Rahotanni da sabuntawa', fr: 'Flux et mises a jour'),
              icon: Icons.newspaper_rounded,
              tint: const Color(0xFFEDE8FF),
              route: '/news',
            ),
            _QuickActionButton(
              compact: compact,
              label: language.tr(en: 'Profile', ha: 'Bayanan kaina', fr: 'Profil'),
              subtitle: language.tr(en: 'Account and setup', ha: 'Asusu da saitin aiki', fr: 'Compte et configuration'),
              icon: Icons.person_rounded,
              tint: const Color(0xFFE5F5D8),
              route: '/profile',
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.compact,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tint,
    required this.route,
  });

  final bool compact;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color tint;
  final String route;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color iconBackground = isDark ? Color.alphaBlend(tint.withOpacity(0.22), theme.colorScheme.surface) : tint;
    final Color iconForeground = isDark ? theme.colorScheme.onSurface : AppColors.primary;

    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: compact ? 56 : 70,
                height: compact ? 56 : 70,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: isDark ? tint.withOpacity(0.42) : Colors.transparent),
                ),
                child: Icon(
                  icon,
                  size: compact ? 28 : 34,
                  color: iconForeground,
                ),
              ),
              SizedBox(height: compact ? 10 : 16),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 14 : null,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!compact) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
