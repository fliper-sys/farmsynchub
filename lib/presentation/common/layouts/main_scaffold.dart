import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/user_profile.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../providers/user_profile_provider.dart';

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
    final AppLanguage language = ref.watch(appLanguageProvider);
    final UserProfile? profile = ref.watch(userProfileProvider).valueOrNull;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isCompactNavigation = screenWidth < 420;
    final List<NavigationDestination> destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home_rounded),
        label: language.tr(en: AppStrings.home, ha: 'Gida', fr: 'Accueil'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.agriculture_outlined),
        selectedIcon: const Icon(Icons.agriculture_rounded),
        label: language.tr(en: AppStrings.farms, ha: 'Gonaki', fr: 'Fermes'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.grass_outlined),
        selectedIcon: const Icon(Icons.grass_rounded),
        label: language.tr(en: AppStrings.crops, ha: 'Amfanin gona', fr: 'Cultures'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.pets_outlined),
        selectedIcon: const Icon(Icons.pets),
        label: language.tr(en: AppStrings.livestock, ha: 'Dabbobi', fr: 'Bétail'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
        label: language.tr(en: AppStrings.finance, ha: 'Kudi', fr: 'Finance'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.newspaper_outlined),
        selectedIcon: const Icon(Icons.newspaper_rounded),
        label: language.tr(en: AppStrings.news, ha: 'Labarai', fr: 'Nouvelles'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline_rounded),
        selectedIcon: const Icon(Icons.person_rounded),
        label: language.tr(en: AppStrings.profile, ha: 'Bayanan kaina', fr: 'Profil'),
      ),
    ];

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
                  language: language,
                  pendingCount: syncOverview.pendingCount,
                  isSyncing: syncOverview.isSyncing,
                  onTap: () => _showSyncSheet(context, ref, syncOverview),
                ),
                const SizedBox(width: 10),
                _ProfileAvatarButton(
                  profile: profile,
                  onTap: () => context.go('/profile'),
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
          ? _PremiumBottomNavigation(
              currentIndex: currentIndex,
              destinations: destinations,
              isCompact: isCompactNavigation,
              onDestinationSelected: (int index) {
                final String featureKey = _featureKeyForIndex(index);
                if (profile?.restrictedFeatures.contains(featureKey) == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        language.tr(
                          en: 'This section is restricted for your account.',
                          ha: 'An takaita wannan sashe a asusun ka.',
                          fr: 'Cette section est restreinte pour votre compte.',
                        ),
                      ),
                    ),
                  );
                  return;
                }
                onDestinationSelected(index);
              },
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

String _featureKeyForIndex(int index) {
  switch (index) {
    case 1:
      return 'farms';
    case 2:
      return 'crops';
    case 3:
      return 'livestock';
    case 4:
      return 'finance';
    case 5:
      return 'news';
    case 6:
      return 'profile';
    default:
      return 'dashboard';
  }
}

class _PremiumBottomNavigation extends StatelessWidget {
  const _PremiumBottomNavigation({
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
    required this.isCompact,
  });

  final int currentIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final double height = isCompact ? 78 : 88;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: height,
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBottomNavigation.withOpacity(0.90)
                    : Colors.white.withOpacity(0.90),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : theme.colorScheme.outlineVariant,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: isDark
                        ? AppColors.premiumGreen.withOpacity(0.12)
                        : AppColors.primary.withOpacity(0.10),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Row(
                children: List<Widget>.generate(destinations.length, (int index) {
                  final NavigationDestination destination = destinations[index];
                  final bool selected = index == currentIndex;
                  return Expanded(
                    child: _PremiumNavItem(
                      selected: selected,
                      label: destination.label,
                      icon: selected
                          ? (destination.selectedIcon ?? destination.icon ?? const SizedBox.shrink())
                          : (destination.icon ?? const SizedBox.shrink()),
                      isCompact: isCompact,
                      onTap: () => onDestinationSelected(index),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumNavItem extends StatelessWidget {
  const _PremiumNavItem({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isCompact,
  });

  final bool selected;
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color inactive = isDark ? const Color(0xFF9CA3AF) : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: EdgeInsets.symmetric(horizontal: selected && !isCompact ? 10 : 6, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFF0B3D2D),
                    Color(0xFF102A26),
                  ],
                )
              : null,
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.premiumGreen.withOpacity(0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: IconTheme(
                data: IconThemeData(
                  color: selected ? AppColors.premiumGreen : inactive,
                  size: 24,
                ),
                child: icon,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              style: theme.textTheme.labelSmall!.copyWith(
                color: selected ? AppColors.premiumGreen : inactive,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: selected ? 11.5 : 11,
              ),
              child: Text(
                isCompact && !selected ? '' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
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
    required this.language,
    required this.pendingCount,
    required this.isSyncing,
    required this.onTap,
  });

  final SyncStatus syncStatus;
  final AppLanguage language;
  final int pendingCount;
  final bool isSyncing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final _SyncVisualState visualState = _resolveState(colorScheme, language);

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

  _SyncVisualState _resolveState(ColorScheme colorScheme, AppLanguage language) {
    switch (syncStatus) {
      case SyncStatus.synced:
        return _SyncVisualState(
          label: language.tr(en: AppStrings.syncStatusSynced, ha: 'An daidaita', fr: 'Synchronise'),
          backgroundColor: colorScheme.primary.withOpacity(0.10),
          borderColor: colorScheme.primary.withOpacity(0.18),
          dotColor: colorScheme.primary,
          foregroundColor: colorScheme.primary,
        );
      case SyncStatus.pending:
        return _SyncVisualState(
          label: language.tr(en: AppStrings.syncStatusPending, ha: 'Ana jira', fr: 'En attente'),
          backgroundColor: colorScheme.tertiary.withOpacity(0.12),
          borderColor: colorScheme.tertiary.withOpacity(0.20),
          dotColor: colorScheme.tertiary,
          foregroundColor: colorScheme.tertiary,
        );
      case SyncStatus.offline:
        return _SyncVisualState(
          label: language.tr(en: AppStrings.syncStatusOffline, ha: 'Babu layi', fr: 'Hors ligne'),
          backgroundColor: colorScheme.outlineVariant.withOpacity(0.26),
          borderColor: colorScheme.outlineVariant.withOpacity(0.40),
          dotColor: colorScheme.onSurfaceVariant,
          foregroundColor: colorScheme.onSurfaceVariant,
        );
    }
  }
}

class _ProfileAvatarButton extends StatelessWidget {
  const _ProfileAvatarButton({
    required this.profile,
    required this.onTap,
  });

  final UserProfile? profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String initials = _initialsFor(profile?.fullName ?? '');
    final Uint8List? imageBytes = _profileImageBytes(profile?.profileImageBase64);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: imageBytes != null
                    ? Image.memory(
                        imageBytes,
                        fit: BoxFit.cover,
                        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                          return Center(
                            child: Text(
                              initials,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
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

String _initialsFor(String name) {
  final List<String> parts = name.trim().split(RegExp(r'\s+')).where((String part) => part.isNotEmpty).toList();
  if (parts.isEmpty) {
    return 'U';
  }
  if (parts.length == 1) {
    final String value = parts.first.trim();
    return value.length >= 2 ? value.substring(0, 2).toUpperCase() : value.substring(0, 1).toUpperCase();
  }
  final String first = parts.first.trim();
  final String last = parts.last.trim();
  return '${first.isNotEmpty ? first[0] : 'U'}${last.isNotEmpty ? last[0] : 'U'}'.toUpperCase();
}

Uint8List? _profileImageBytes(String? base64Image) {
  final String value = base64Image?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}
