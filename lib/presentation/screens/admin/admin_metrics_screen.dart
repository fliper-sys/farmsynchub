import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/user_profile.dart';
import '../../../providers/admin_provider.dart';
import '../../common/widgets/app_card.dart';
import 'admin_locked_view.dart';

class AdminMetricsScreen extends ConsumerWidget {
  const AdminMetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdminWorkspaceState> adminAsync = ref.watch(adminWorkspaceProvider);
    final AdminWorkspaceState? state = adminAsync.valueOrNull;
    final ThemeData theme = Theme.of(context);

    if (adminAsync.isLoading || state == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.currentAdmin == null) {
      return const AdminLockedView(
        message: 'Use the hidden admin login to view system metrics and health signals.',
      );
    }

    final DateTime now = DateTime.now();
    final int totalUsers = state.users.length;
    final int completeProfiles = state.users.where((UserProfile user) => user.isComplete).length;
    final int disabledUsers = state.users.where((UserProfile user) => user.isDisabled).length;
    final int restrictedUsers = state.users.where((UserProfile user) => user.restrictedFeatures.isNotEmpty).length;
    final int recentUsers = state.users.where((UserProfile user) => now.difference(user.createdAt).inDays <= 7).length;
    final int recentUpdates = state.users.where((UserProfile user) => now.difference(user.updatedAt).inDays <= 7).length;
    final int owners = state.users.where((UserProfile user) => user.accountRole == UserAccountRole.owner).length;
    final int workers = state.users.where((UserProfile user) => user.accountRole == UserAccountRole.worker).length;
    final int partners = state.users.where((UserProfile user) => user.accountRole == UserAccountRole.partner).length;
    final int viewers = state.users.where((UserProfile user) => user.accountRole == UserAccountRole.viewer).length;
    final double completionRate = totalUsers == 0 ? 0 : completeProfiles / totalUsers;
    final double restrictionRate = totalUsers == 0 ? 0 : restrictedUsers / totalUsers;
    final double disableRate = totalUsers == 0 ? 0 : disabledUsers / totalUsers;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go('/admin-dashboard'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Admin metrics'),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.read(adminWorkspaceProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(adminWorkspaceProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            AppCard(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('System health', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'Quick signals that help admins see account growth, profile completeness, restrictions, and recent activity.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _StatChip(label: 'Users', value: '$totalUsers'),
                        _StatChip(label: 'Recent signups', value: '$recentUsers'),
                        _StatChip(label: 'Updated 7d', value: '$recentUpdates'),
                        _StatChip(label: 'Disabled', value: '$disabledUsers'),
                        _StatChip(label: 'Restricted', value: '$restrictedUsers'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width < 620 ? 2 : 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: <Widget>[
                _MiniMetric(
                  title: 'Profile completeness',
                  value: '${(completionRate * 100).round()}%',
                  subtitle: '$completeProfiles of $totalUsers complete',
                  progress: completionRate,
                  tint: Colors.green,
                ),
                _MiniMetric(
                  title: 'Restriction rate',
                  value: '${(restrictionRate * 100).round()}%',
                  subtitle: '$restrictedUsers users limited',
                  progress: restrictionRate,
                  tint: Colors.orange,
                ),
                _MiniMetric(
                  title: 'Disabled rate',
                  value: '${(disableRate * 100).round()}%',
                  subtitle: '$disabledUsers accounts disabled',
                  progress: disableRate,
                  tint: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Role breakdown', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            AppCard(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: <Widget>[
                    _RoleRow(label: 'Owners', value: owners, color: Colors.green),
                    _RoleRow(label: 'Workers', value: workers, color: Colors.blue),
                    _RoleRow(label: 'Partners', value: partners, color: Colors.orange),
                    _RoleRow(label: 'Viewers', value: viewers, color: Colors.purple),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Quick links', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _QuickLink(label: 'Users', icon: Icons.people_alt_rounded, onTap: () => context.go('/admin-users')),
                _QuickLink(label: 'Admins', icon: Icons.admin_panel_settings_rounded, onTap: () => context.go('/admin-admins')),
                _QuickLink(label: 'Broadcast', icon: Icons.campaign_rounded, onTap: () => context.go('/admin-notifications')),
                _QuickLink(label: 'News', icon: Icons.newspaper_rounded, onTap: () => context.go('/admin-news')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.progress,
    required this.tint,
  });

  final String title;
  final String value;
  final String subtitle;
  final double progress;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: tint, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 8,
                backgroundColor: tint.withOpacity(0.16),
                valueColor: AlwaysStoppedAnimation<Color>(tint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text('$value'),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      ),
    );
  }
}
