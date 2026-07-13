import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/admin_provider.dart';
import '../../../domain/models/user_profile.dart';
import '../../../domain/models/verified_badge_request.dart';
import '../../common/widgets/app_card.dart';
import 'admin_locked_view.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdminWorkspaceState> adminAsync = ref.watch(adminWorkspaceProvider);
    final AdminWorkspaceState? state = adminAsync.valueOrNull;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (adminAsync.isLoading || state == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.currentAdmin == null) {
      return const AdminLockedView(
        message:
            'Tap the hidden login route to access the admin console, register admins, and manage users.',
      );
    }

    final int userCount = state.users.length;
    final int adminCount = state.admins.length;
    final int disabledUsers = state.users.where((UserProfile user) => user.isDisabled).length;
    final int restrictedUsers = state.users.where((UserProfile user) => user.restrictedFeatures.isNotEmpty).length;
    final int completeProfiles = state.users.where((UserProfile user) => user.isComplete).length;
    final int recentUpdates = state.users.where((UserProfile user) => DateTime.now().difference(user.updatedAt).inDays <= 7).length;
    final int owners = state.users.where((UserProfile user) => user.accountRole == UserAccountRole.owner).length;
    final int workers = state.users.where((UserProfile user) => user.accountRole == UserAccountRole.worker).length;
    final int badgeRequests = state.verifiedBadgeRequests.where((VerifiedBadgeRequest request) => request.isPending).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin dashboard'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(adminWorkspaceProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => ref.read(adminWorkspaceProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(adminWorkspaceProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            AppCard(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Welcome, ${state.currentAdmin?.name ?? 'Admin'}',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use this console to manage admins, users, feature restrictions, broadcasts, and news updates.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _StatChip(label: 'Users', value: '$userCount'),
                        _StatChip(label: 'Admins', value: '$adminCount'),
                        _StatChip(label: 'Disabled', value: '$disabledUsers'),
                        _StatChip(label: 'Restricted', value: '$restrictedUsers'),
                        _StatChip(label: 'Complete profiles', value: '$completeProfiles'),
                        _StatChip(label: 'Updated 7d', value: '$recentUpdates'),
                        _StatChip(label: 'Owners', value: '$owners'),
                        _StatChip(label: 'Workers', value: '$workers'),
                        _StatChip(label: 'Badge requests', value: '$badgeRequests'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int columns = constraints.maxWidth < 620 ? 2 : 3;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns == 2 ? 1.35 : 1.45,
                  children: <Widget>[
                    _ActionTile(
                      icon: Icons.people_alt_rounded,
                      title: 'View users',
                      subtitle: 'Open detailed user management.',
                      onTap: () => context.go('/admin-users'),
                    ),
                    _ActionTile(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Register admin',
                      subtitle: 'Create a new app admin account.',
                      onTap: () => context.go('/admin-admins'),
                    ),
                    _ActionTile(
                      icon: Icons.campaign_rounded,
                      title: 'Broadcast',
                      subtitle: 'Send notifications to users.',
                      onTap: () => context.go('/admin-notifications'),
                    ),
                    _ActionTile(
                      icon: Icons.note_alt_rounded,
                      title: 'Admin notes',
                      subtitle: 'Live work messages for admins.',
                      onTap: () => context.go('/admin-notes'),
                    ),
                    _ActionTile(
                      icon: Icons.newspaper_rounded,
                      title: 'News updates',
                      subtitle: 'Publish admin news to the feed.',
                      onTap: () => context.go('/admin-news'),
                    ),
                    _ActionTile(
                      icon: Icons.lock_reset_rounded,
                      title: 'Recovery',
                      subtitle: 'Reset an admin password.',
                      onTap: () => context.go('/admin-recovery'),
                    ),
                    _ActionTile(
                      icon: Icons.verified_user_rounded,
                      title: 'Verified badges',
                      subtitle: 'Review farmer badge applications.',
                      onTap: () => context.go('/admin-verified-badges'),
                    ),
                    _ActionTile(
                      icon: Icons.security_rounded,
                      title: 'Access rules',
                      subtitle: 'Restrict or restore user features.',
                      onTap: () => context.go('/admin-users'),
                    ),
                    _ActionTile(
                      icon: Icons.insights_rounded,
                      title: 'Metrics',
                      subtitle: 'See account health and role breakdowns.',
                      onTap: () => context.go('/admin-metrics'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Text('Recent users', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            ...state.users.take(5).map(
              (UserProfile user) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  color: scheme.surfaceContainerHighest,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      child: Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?'),
                    ),
                    title: Text(user.fullName.isEmpty ? user.email : user.fullName),
                    subtitle: Text(
                      user.isDisabled
                          ? 'Disabled account'
                          : user.restrictedFeatures.isNotEmpty
                              ? 'Restricted: ${user.restrictedFeatures.join(', ')}'
                              : user.ward.isNotEmpty
                                  ? user.ward
                                  : user.primaryFocus,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.go('/admin-users/${user.uid}'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Account health', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            AppCard(
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: <Widget>[
                    _ProgressRow(
                      label: 'Profile completeness',
                      value: userCount == 0 ? 0 : state.users.where((UserProfile user) => user.isComplete).length / userCount,
                      trailingText: '${state.users.where((UserProfile user) => user.isComplete).length}/$userCount',
                      tint: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _ProgressRow(
                      label: 'Recent updates',
                      value: userCount == 0 ? 0 : recentUpdates / userCount,
                      trailingText: '$recentUpdates/$userCount',
                      tint: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _ProgressRow(
                      label: 'Disabled accounts',
                      value: userCount == 0 ? 0 : disabledUsers / userCount,
                      trailingText: '$disabledUsers/$userCount',
                      tint: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    _ProgressRow(
                      label: 'Restricted accounts',
                      value: userCount == 0 ? 0 : restrictedUsers / userCount,
                      trailingText: '$restrictedUsers/$userCount',
                      tint: Colors.orange,
                    ),
                  ],
                ),
              ),
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
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 14),
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.trailingText,
    required this.tint,
  });

  final String label;
  final double value;
  final String trailingText;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(trailingText, style: theme.textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1),
            minHeight: 8,
            backgroundColor: tint.withOpacity(0.14),
            valueColor: AlwaysStoppedAnimation<Color>(tint),
          ),
        ),
      ],
    );
  }
}
