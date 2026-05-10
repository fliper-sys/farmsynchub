import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

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
class MainScaffold extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

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
                _SyncStatusPill(syncStatus: syncStatus),
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
  const _SyncStatusPill({required this.syncStatus});

  final SyncStatus syncStatus;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final _SyncVisualState visualState = _resolveState(colorScheme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: visualState.dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              visualState.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: visualState.foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
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
