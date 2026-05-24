import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// Grid of quick action buttons for common tasks.
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      childAspectRatio: 0.96,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: const <Widget>[
        _QuickActionButton(
          icon: Icons.landscape_rounded,
          label: 'My Farm',
          subtitle: 'Land records and setup',
          tint: Color(0xFFDDF2C9),
          route: '/farms',
        ),
        _QuickActionButton(
          icon: Icons.spa_rounded,
          label: 'Crops',
          subtitle: 'Stages and planting',
          tint: Color(0xFFD8F2E5),
          route: '/crops',
        ),
        _QuickActionButton(
          icon: Icons.inventory_2_rounded,
          label: 'Livestock',
          subtitle: 'Animals and count',
          tint: Color(0xFFE4F1FF),
          route: '/livestock',
        ),
        _QuickActionButton(
          icon: Icons.savings_rounded,
          label: 'Sales',
          subtitle: 'Receipts and finance',
          tint: Color(0xFFFFE9BF),
          route: '/finance',
        ),
        _QuickActionButton(
          icon: Icons.school_rounded,
          label: 'Learn',
          subtitle: 'Lessons and practice',
          tint: Color(0xFFFFEEE4),
          route: '/learn',
        ),
        _QuickActionButton(
          icon: Icons.auto_awesome_rounded,
          label: 'AI Advisor',
          subtitle: 'Ask for field help',
          tint: Color(0xFFEDE8FF),
          route: '/ai-advisor',
        ),
        _QuickActionButton(
          icon: Icons.person_rounded,
          label: 'Profile',
          subtitle: 'Account and setup',
          tint: Color(0xFFE5F5D8),
          route: '/profile',
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tint,
    required this.route,
  });

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
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  icon,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
