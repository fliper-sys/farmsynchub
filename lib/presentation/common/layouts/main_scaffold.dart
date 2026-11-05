import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/navigation/app_destinations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/user_profile.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/engagement_provider.dart';
import '../../../providers/learning_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../screens/learn/engagement_widgets.dart';
import '../../screens/learn/streak_calendar_screen.dart';
import 'app_menu_drawer.dart';

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
    this.currentPath = '',
    this.floatingActionButton,
    this.drawer,
    this.actions,
    this.syncStatus = SyncStatus.synced,
    this.showAppBar = true,
    this.showBottomNavigation = true,
    this.extendBody = false,
  });

  /// The active bottom-bar tab, or -1 when the page on screen is not one of
  /// the tabs (for example News or Profile), so no tab looks selected.
  final int currentIndex;

  /// The content rendered above the bottom navigation.
  final Widget child;

  /// Callback fired when a bottom destination is selected.
  final ValueChanged<int> onDestinationSelected;

  /// Optional app bar title.
  final String? title;

  /// Optional floating action button for the active screen.
  final Widget? floatingActionButton;

  /// Route on screen, used to highlight the current item in the menu.
  final String currentPath;

  /// Navigation drawer. Defaults to the full app menu so every screen is one
  /// tap away from anywhere.
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
    // Watching the learning record at the shell starts the offline-first
    // cloud sync as soon as the app opens, not only when Learn is visited.
    ref.watch(learningProvider.select((LearningState s) => s.isLoaded));
    final EngagementState engagement = ref.watch(engagementProvider);
    final DateTime nowTrusted = engagement.trusted(DateTime.now());
    final StreakInfo streakInfo = engagement.streakInfo(nowTrusted);
    final bool streakAtRisk = streakInfo.count > 0 &&
        (streakInfo.status == StreakStatus.alive ||
            streakInfo.status == StreakStatus.frozen);
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isCompactNavigation = screenWidth < 420;
    // Five labelled tabs; every other screen is reachable from the menu.
    final List<NavigationDestination> destinations = AppDestinations.tabs
        .map(
          (AppDestination destination) => NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label(language),
          ),
        )
        .toList();

    final Widget menuDrawer = drawer ?? AppMenuDrawer(currentPath: currentPath);

    return Scaffold(
      extendBody: extendBody,
      drawer: menuDrawer,
      appBar: showAppBar
          ? AppBar(
              title: title == null ? null : Text(title!),
              leading: Builder(
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
                const SizedBox(width: 8),
                _StreakPill(info: streakInfo, atRisk: streakAtRisk),
                const SizedBox(width: 8),
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
              badgedIndex: streakAtRisk ? 0 : null,
              onDestinationSelected: (int index) {
                if (index != currentIndex) HapticFeedback.selectionClick();
                final String featureKey = AppDestinations.tabs[index].featureKey;
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
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
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
                  title:
                      '${overview.pendingCount} pending item${overview.pendingCount == 1 ? '' : 's'}',
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
                      : MaterialLocalizations.of(sheetContext)
                          .formatFullDate(overview.lastAttemptAt!),
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: canSync
                            ? () async {
                                await ref
                                    .read(syncOverviewProvider.notifier)
                                    .runSync();
                                Navigator.of(sheetContext).pop();
                              }
                            : null,
                        icon: overview.isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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
                        await ref
                            .read(syncOverviewProvider.notifier)
                            .refreshOverview();
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

class _PremiumBottomNavigation extends StatelessWidget {
  const _PremiumBottomNavigation({
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
    required this.isCompact,
    this.badgedIndex,
  });

  final int currentIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final bool isCompact;

  /// Tab that shows a small attention dot (Home, when the streak needs a
  /// lesson today).
  final int? badgedIndex;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    const double height = 72;
    final int count = destinations.length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: height,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBottomNavigation.withOpacity(0.92)
                    : Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : theme.colorScheme.outlineVariant,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.45)
                        : const Color(0xFF0B3D2D).withOpacity(0.14),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  final double slot = box.maxWidth / count;
                  return Stack(
                    children: <Widget>[
                      // One pill that glides to the selected tab. It is hidden
                      // on pages that are not one of the tabs.
                      if (currentIndex >= 0)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutBack,
                          left: slot * currentIndex,
                          top: 0,
                          bottom: 0,
                          width: slot,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: <Color>[
                                  Color(0xFF0E5A41),
                                  Color(0xFF0B3D2D),
                                ],
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color:
                                      AppColors.premiumGreen.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Row(
                        children: List<Widget>.generate(count, (int index) {
                          final NavigationDestination destination =
                              destinations[index];
                          final bool selected = index == currentIndex;
                          return Expanded(
                            child: _PremiumNavItem(
                              selected: selected,
                              label: destination.label,
                              badge: badgedIndex == index && !selected,
                              icon: selected
                                  ? (destination.selectedIcon ??
                                      destination.icon)
                                  : destination.icon,
                              onTap: () => onDestinationSelected(index),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
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
    this.badge = false,
  });

  final bool selected;
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color inactive =
        isDark ? const Color(0xFF9CA3AF) : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedScale(
                  scale: selected ? 1.12 : 1,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  child: IconTheme(
                    data: IconThemeData(
                      color: selected ? AppColors.premiumGreen : inactive,
                      size: 24,
                    ),
                    child: icon,
                  ),
                ),
                // Every tab always shows its name: an icon alone is easy to
                // misread, especially for first-time users. With five tabs
                // there is room; long names (e.g. in Hausa) scale down.
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 3, 2, 0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall!.copyWith(
                        color: selected ? AppColors.premiumGreen : inactive,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (badge)
              const Positioned(
                top: 10,
                right: 10,
                child: _AttentionDot(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small pulsing orange dot used to say "something needs you here".
class _AttentionDot extends StatefulWidget {
  const _AttentionDot();

  @override
  State<_AttentionDot> createState() => _AttentionDotState();
}

class _AttentionDotState extends State<_AttentionDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? child) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: const Color(0xFFFF9600),
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFFFF9600).withOpacity(0.6 * _c.value),
              blurRadius: 8,
              spreadRadius: 2 * _c.value,
            ),
          ],
        ),
      ),
    );
  }
}

/// Flame + streak count in the top bar. Warm and pulsing while the streak
/// still needs a lesson today; ice blue when frozen; grey when there is none.
/// Tap opens the streak calendar.
class _StreakPill extends StatefulWidget {
  const _StreakPill({required this.info, required this.atRisk});

  final StreakInfo info;
  final bool atRisk;

  @override
  State<_StreakPill> createState() => _StreakPillState();
}

class _StreakPillState extends State<_StreakPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _StreakPill old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final bool still = MediaQuery.of(context).disableAnimations;
    if (widget.atRisk && !still) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final StreakStatus status = widget.info.status;
    final bool frozen = status == StreakStatus.frozen;
    final bool lit =
        status == StreakStatus.doneToday || status == StreakStatus.alive;
    final Color color = lit
        ? EngagementColors.fire
        : frozen
            ? EngagementColors.ice
            : EngagementColors.grayText;
    return Semantics(
      button: true,
      label: '${widget.info.count} day learning streak',
      child: GestureDetector(
        onTap: () => Navigator.of(context)
            .push(fluidRoute<void>(const StreakCalendarScreen())),
        child: AnimatedBuilder(
          animation: _c,
          builder: (BuildContext context, Widget? child) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: color.withOpacity(0.35 + 0.35 * _c.value)),
              boxShadow: widget.atRisk
                  ? <BoxShadow>[
                      BoxShadow(
                        color: color.withOpacity(0.35 * _c.value),
                        blurRadius: 12,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Transform.scale(
                  scale: 1 + 0.15 * _c.value,
                  child: Icon(
                    frozen
                        ? Icons.ac_unit_rounded
                        : Icons.local_fire_department_rounded,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  '${widget.info.count}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
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
                Text(
                  pendingCount > 0
                      ? '${visualState.label} · $pendingCount'
                      : visualState.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: visualState.foregroundColor,
                        fontWeight: FontWeight.w700,
                      ),
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

  _SyncVisualState _resolveState(
      ColorScheme colorScheme, AppLanguage language) {
    switch (syncStatus) {
      case SyncStatus.synced:
        return _SyncVisualState(
          label: language.tr(
              en: AppStrings.syncStatusSynced,
              ha: 'An daidaita',
              fr: 'Synchronise'),
          backgroundColor: colorScheme.primary.withOpacity(0.10),
          borderColor: colorScheme.primary.withOpacity(0.18),
          dotColor: colorScheme.primary,
          foregroundColor: colorScheme.primary,
        );
      case SyncStatus.pending:
        return _SyncVisualState(
          label: language.tr(
              en: AppStrings.syncStatusPending,
              ha: 'Ana jira',
              fr: 'En attente'),
          backgroundColor: colorScheme.tertiary.withOpacity(0.12),
          borderColor: colorScheme.tertiary.withOpacity(0.20),
          dotColor: colorScheme.tertiary,
          foregroundColor: colorScheme.tertiary,
        );
      case SyncStatus.offline:
        return _SyncVisualState(
          label: language.tr(
              en: AppStrings.syncStatusOffline,
              ha: 'Babu layi',
              fr: 'Hors ligne'),
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
    final Uint8List? imageBytes =
        _profileImageBytes(profile?.profileImageBase64);

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
                        errorBuilder: (BuildContext context, Object error,
                            StackTrace? stackTrace) {
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
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
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
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'U';
  }
  if (parts.length == 1) {
    final String value = parts.first.trim();
    return value.length >= 2
        ? value.substring(0, 2).toUpperCase()
        : value.substring(0, 1).toUpperCase();
  }
  final String first = parts.first.trim();
  final String last = parts.last.trim();
  return '${first.isNotEmpty ? first[0] : 'U'}${last.isNotEmpty ? last[0] : 'U'}'
      .toUpperCase();
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
