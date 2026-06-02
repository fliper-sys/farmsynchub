import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// Grid of quick action buttons for common tasks.
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
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
              icon: Icons.landscape_rounded,
              label: 'My Farm',
              subtitle: 'Land records and setup',
              tint: const Color(0xFFDDF2C9),
              route: '/farms',
            ),
            _QuickActionButton(
              compact: compact,
              icon: Icons.spa_rounded,
              label: 'Crops',
              subtitle: 'Stages and planting',
              tint: const Color(0xFFD8F2E5),
              route: '/crops',
            ),
            _QuickActionButton(
              compact: compact,
              icon: Icons.inventory_2_rounded,
              label: 'Livestock',
              subtitle: 'Animals and count',
              tint: const Color(0xFFE4F1FF),
              route: '/livestock',
            ),
            _QuickActionButton(
              compact: compact,
              icon: Icons.savings_rounded,
              label: 'Sales',
              subtitle: 'Receipts and finance',
              tint: const Color(0xFFFFE9BF),
              route: '/finance',
            ),
            _QuickActionButton(
              compact: compact,
              icon: Icons.school_rounded,
              label: 'Learn',
              subtitle: 'Lessons and practice',
              tint: const Color(0xFFFFEEE4),
              route: '/learn',
            ),
            _QuickActionButton(
              compact: compact,
              icon: Icons.auto_awesome_rounded,
              label: 'AI Advisor',
              subtitle: 'Ask for field help',
              tint: const Color(0xFFEDE8FF),
              route: '/ai-advisor',
            ),
            _QuickActionButton(
              compact: compact,
              icon: Icons.newspaper_rounded,
              label: 'News',
              subtitle: 'Feeds and updates',
              tint: const Color(0xFFEDE8FF),
              route: '/news',
            ),
            _QuickActionButton(
              compact: compact,
              icon: Icons.person_rounded,
              label: 'Profile',
              subtitle: 'Account and setup',
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

    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
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
                  color: tint,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  icon,
                  size: compact ? 28 : 34,
                  color: AppColors.primary,
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
