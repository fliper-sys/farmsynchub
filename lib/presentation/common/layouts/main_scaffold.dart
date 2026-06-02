import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/sync_provider.dart';

/// Connection state used for the app-wide sync indicator.
enum SyncStatus {
  /// Everything is synced with local persistence and cloud sync is idle.
  synced,

  /// Local changes are waiting for background sync.
  pending,

  /// Device is offline or sync is temporarily unavailable.
  offline,
}

/// Shared bottom-navigation scaffold used by the primary app tabs.
class MainScaffold extends ConsumerWidget {
  /// Creates the main scaffold shell for top-level navigation.
  const MainScaffold({
    super.key,
    required this.currentIndex,
    required this.child,
    required this.onDestinationSelected,
    this.title,
    this.floatingActionButton,
    this.drawer,
    this.actions,
    this.syncStatus = SyncStatus.synced,
    this.showAppBar = true,
    this.showBottomNavigation = true,
    this.extendBody = false,
  });

  /// The active navigation index.
  final int currentIndex;

  /// The content rendered above the bottom navigation.
  final Widget child;

  /// Callback fired when a bottom destination is selected.
  final ValueChanged<int> onDestinationSelected;

  /// Optional app bar title.
  final String? title;

  /// Optional floating action button for the active screen.
  final Widget? floatingActionButton;

  /// Optional navigation drawer for quick links like AI and Learn.
  final Widget? drawer;

  /// Optional trailing app bar actions.
  final List<Widget>? actions;

  /// Sync status badge shown in the app bar.
  final SyncStatus syncStatus;

  /// Whether to render the standard app bar.
  final bool showAppBar;

  /// Whether to render the bottom navigation bar.
  final bool showBottomNavigation;

  /// Whether the body should extend behind the navigation bar.
  final bool extendBody;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final SyncOverview syncOverview = ref.watch(syncOverviewProvider);
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isCompactNavigation = screenWidth < 420;

    return Scaffold(
      extendBody: extendBody,
      drawer: drawer,
      appBar: showAppBar
          ? AppBar(
              title: title == null ? null : Text(title!),
              leading: drawer == null
                  ? null
                  : Builder(
                      builder: (BuildContext context) => const _MenuButton(),
                    ),
              actions: <Widget>[
                _SyncStatusPill(
                  syncStatus: _resolveSyncStatus(syncOverview),
                  pendingCount: syncOverview.pendingCount,
                  isSyncing: syncOverview.isSyncing,
                  onTap: () => _showSyncSheet(context, ref, syncOverview),
                ),
                if (actions != null) ...actions!,
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: ColoredBox(
        color: colorScheme.surface,
        child: child,
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: floatingActionButton,
      ),
      bottomNavigationBar: showBottomNavigation
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: colorScheme.outlineVariant),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.light
                            ? AppColors.primary.withOpacity(0.08)
                            : Colors.black.withOpacity(0.22),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: NavigationBar(
                      height: isCompactNavigation ? 68 : 80,
                      labelBehavior: isCompactNavigation
                          ? NavigationDestinationLabelBehavior.onlyShowSelected
                          : NavigationDestinationLabelBehavior.alwaysShow,
                      animationDuration: const Duration(milliseconds: 220),
                      selectedIndex: currentIndex,
                      destinations: const <NavigationDestination>[
                        NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: AppStrings.home,
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.agriculture_outlined),
                          selectedIcon: Icon(Icons.agriculture_rounded),
                          label: AppStrings.farms,
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.grass_outlined),
                          selectedIcon: Icon(Icons.grass_rounded),
                          label: AppStrings.crops,
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.pets_outlined),
                          selectedIcon: Icon(Icons.pets),
                          label: AppStrings.livestock,
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.account_balance_wallet_outlined),
                          selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                          label: AppStrings.finance,
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.newspaper_outlined),
                          selectedIcon: Icon(Icons.newspaper_rounded),
                          label: AppStrings.news,
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.person_outline_rounded),
                          selectedIcon: Icon(Icons.person_rounded),
                          label: AppStrings.profile,
                        ),
                      ],
                      onDestinationSelected: onDestinationSelected,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  SyncStatus _resolveSyncStatus(SyncOverview syncOverview) {
    if (!syncOverview.hasConnection) {
      return SyncStatus.offline;
    }
    if (syncOverview.isSyncing || syncOverview.pendingCount > 0) {
      return SyncStatus.pending;
    }
    return SyncStatus.synced;
  }

  Future<void> _showSyncSheet(
    BuildContext context,
    WidgetRef ref,
    SyncOverview overview,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        final ColorScheme colorScheme = theme.colorScheme;
        final bool canSync = overview.hasConnection && !overview.isSyncing;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Sync status',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _SyncSheetRow(
                  icon: overview.isSyncing
                      ? Icons.sync_rounded
                      : overview.hasConnection
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                  title: overview.isSyncing
                      ? 'Sync in progress'
                      : overview.hasConnection
                          ? 'Connected'
                          : 'Offline',
                  detail: overview.isSyncing
                      ? 'Uploading local changes and pulling the latest farm data.'
                      : overview.hasConnection
                          ? 'Ready to sync when you make changes.'
                          : 'Changes stay on this device until the connection returns.',
                  color: overview.isSyncing
                      ? colorScheme.tertiary
                      : overview.hasConnection
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                _SyncSheetRow(
                  icon: Icons.pending_actions_rounded,
                  title: '${overview.pendingCount} pending item${overview.pendingCount == 1 ? '' : 's'}',
                  detail: overview.pendingCount == 0
                      ? 'No local changes are waiting to be uploaded.'
                      : 'Open the dashboard or tap sync to push the queued updates.',
                  color: colorScheme.tertiary,
                ),
                const SizedBox(height: 12),
                _SyncSheetRow(
                  icon: Icons.schedule_rounded,
                  title: overview.lastAttemptAt == null
                      ? 'No sync attempt yet'
                      : 'Last sync attempt',
                  detail: overview.lastAttemptAt == null
                      ? 'We will record the next sync attempt here.'
                      : MaterialLocalizations.of(sheetContext).formatFullDate(overview.lastAttemptAt!),
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: canSync
                            ? () async {
                                await ref.read(syncOverviewProvider.notifier).runSync();
                                Navigator.of(sheetContext).pop();
                              }
                            : null,
                        icon: overview.isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: Text(
                          overview.isSyncing ? 'Syncing...' : 'Sync now',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () async {
                        await ref.read(syncOverviewProvider.notifier).refreshOverview();
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppStrings.openMenu,
      icon: const Icon(Icons.menu_rounded),
      onPressed: () => Scaffold.of(context).openDrawer(),
    );
  }
}

class _SyncStatusPill extends StatelessWidget {
  const _SyncStatusPill({
    required this.syncStatus,
    required this.pendingCount,
    required this.isSyncing,
    required this.onTap,
  });

  final SyncStatus syncStatus;
  final int pendingCount;
  final bool isSyncing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final _SyncVisualState visualState = _resolveState(colorScheme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: visualState.backgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: visualState.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isSyncing
                      ? SizedBox(
                          key: const ValueKey<String>('syncing'),
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              visualState.dotColor,
                            ),
                          ),
                        )
                      : AnimatedContainer(
                          key: const ValueKey<String>('dot'),
                          duration: const Duration(milliseconds: 250),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: visualState.dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      visualState.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: visualState.foregroundColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (pendingCount > 0)
                      Text(
                        '$pendingCount pending',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: visualState.foregroundColor.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: visualState.foregroundColor.withOpacity(0.75),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _SyncVisualState _resolveState(ColorScheme colorScheme) {
    switch (syncStatus) {
      case SyncStatus.synced:
        return _SyncVisualState(
          label: AppStrings.syncStatusSynced,
          backgroundColor: colorScheme.primary.withOpacity(0.10),
          borderColor: colorScheme.primary.withOpacity(0.18),
          dotColor: colorScheme.primary,
          foregroundColor: colorScheme.primary,
        );
      case SyncStatus.pending:
        return _SyncVisualState(
          label: AppStrings.syncStatusPending,
          backgroundColor: colorScheme.tertiary.withOpacity(0.12),
          borderColor: colorScheme.tertiary.withOpacity(0.20),
          dotColor: colorScheme.tertiary,
          foregroundColor: colorScheme.tertiary,
        );
      case SyncStatus.offline:
        return _SyncVisualState(
          label: AppStrings.syncStatusOffline,
          backgroundColor: colorScheme.outlineVariant.withOpacity(0.26),
          borderColor: colorScheme.outlineVariant.withOpacity(0.40),
          dotColor: colorScheme.onSurfaceVariant,
          foregroundColor: colorScheme.onSurfaceVariant,
        );
    }
  }
}

class _SyncSheetRow extends StatelessWidget {
  const _SyncSheetRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SyncVisualState {
  const _SyncVisualState({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.dotColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color dotColor;
  final Color foregroundColor;
}
