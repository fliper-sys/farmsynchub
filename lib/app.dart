import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'domain/models/crop.dart';
import 'domain/models/farm.dart';
import 'domain/models/farm_activity.dart';
import 'domain/models/livestock.dart';
import 'domain/models/notification.dart' as domain;
import 'domain/models/user_profile.dart';
import 'data/remote/firebase_service.dart';
import 'core/data/fun_facts.dart';
import 'core/services/farm_notification_service.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/services/fun_fact_popup_preferences.dart';
import 'core/theme/app_theme.dart';
import 'presentation/common/layouts/main_scaffold.dart';
import 'presentation/common/widgets/fun_fact_popup.dart';
import 'presentation/screens/ai_advisor/ai_advisor_screen.dart';
import 'presentation/screens/auth/forgot_password_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/account_restricted_screen.dart';
import 'presentation/screens/auth/post_auth_gate_screen.dart';
import 'presentation/screens/auth/phone_auth_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/auth/invite_accept_screen.dart';
import 'presentation/screens/auth/verify_email_screen.dart';
import 'presentation/screens/admin/admin_dashboard_screen.dart';
import 'presentation/screens/admin/admin_login_screen.dart';
import 'presentation/screens/admin/admin_notifications_screen.dart';
import 'presentation/screens/admin/admin_news_screen.dart';
import 'presentation/screens/admin/admin_notes_screen.dart';
import 'presentation/screens/admin/admin_recovery_screen.dart';
import 'presentation/screens/admin/admin_admins_screen.dart';
import 'presentation/screens/admin/admin_metrics_screen.dart';
import 'presentation/screens/admin/admin_verified_badges_screen.dart';
import 'presentation/screens/admin/admin_user_detail_screen.dart';
import 'presentation/screens/admin/admin_users_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/farms/farms_screen.dart';
import 'presentation/screens/farms/farm_tasks_screen.dart';
import 'presentation/screens/crops/crops_screen.dart';
import 'presentation/screens/learn/learn_screen.dart';
import 'presentation/screens/livestock/livestock_screen.dart';
import 'presentation/screens/finance/finance_screen.dart';
import 'presentation/screens/finance/finance_ai_recap_screen.dart';
import 'presentation/screens/finance/market_trends_screen.dart';
import 'presentation/screens/finance/expense_tracking_screen.dart';
import 'presentation/screens/finance/sales_information_screen.dart';
import 'presentation/screens/sales/sales_desk_screen.dart';
import 'presentation/screens/procurement/procurement_screen.dart';
import 'presentation/screens/news/news_screen.dart';
import 'presentation/screens/schedule/schedule_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/profile/account_setup_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/onboarding/app_tour_screen.dart';
import 'presentation/screens/notifications/notifications_screen.dart';
import 'presentation/screens/notifications/notification_detail_screen.dart';
import 'providers/app_preferences_provider.dart';
import 'providers/crop_provider.dart';
import 'providers/farm_provider.dart';
import 'providers/livestock_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_profile_provider.dart';

/// The root widget of the Farmsync application.
class FarmsyncApp extends ConsumerStatefulWidget {
  const FarmsyncApp({super.key});

  @override
  ConsumerState<FarmsyncApp> createState() => _FarmsyncAppState();
}

class _FarmsyncAppState extends ConsumerState<FarmsyncApp> {
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _appOpenSubscription;

  @override
  void initState() {
    super.initState();
    _initializeMessaging();
  }

  Future<void> _initializeMessaging() async {
    try {
      await ref.read(firebaseMessagingServiceProvider).initialize();
      _messageSubscription =
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      _appOpenSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpen);
      final RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpen(initialMessage);
      }
    } catch (error) {
      debugPrint('[Messaging] Startup initialization skipped: $error');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final String title = message.notification?.title ??
        message.data['title'] as String? ??
        'FarmSync update';
    final String body = message.notification?.body ??
        message.data['body'] as String? ??
        message.data['message'] as String? ??
        '';
    final String? actionUrl = message.data['actionUrl'] as String? ??
        message.data['click_action'] as String?;

    ref.read(notificationsProvider.notifier).addNotification(
      title: title,
      message: body,
      actionUrl: actionUrl,
      type: domain.NotificationType.info,
      metadata: <String, dynamic>{
        'source': 'fcm',
        if (message.data.isNotEmpty) 'data': message.data,
      },
    );

    final bool notificationsEnabled =
        ref.read(appSettingsProvider).notificationsEnabled;
    if (notificationsEnabled) {
      await FarmNotificationService.instance.showNow(
        id: message.messageId?.hashCode.abs() ??
            DateTime.now().millisecondsSinceEpoch,
        title: title,
        body: body,
        payload: actionUrl,
      );
    }
  }

  void _handleMessageOpen(RemoteMessage message) {
    final String? actionUrl = message.data['actionUrl'] as String? ??
        message.data['click_action'] as String?;
    if (actionUrl != null && mounted) {
      context.go(actionUrl);
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _appOpenSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = ref.watch(themeProvider);
    final AppLanguage language = ref.watch(appLanguageProvider);
    final Locale materialLocale = _materialLocaleFor(language);

    return MaterialApp.router(
      title: 'Farmsync',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: materialLocale,
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('fr'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? child) {
        return StartupResumePrompt(child: child ?? const SizedBox.shrink());
      },
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class StartupResumePrompt extends ConsumerStatefulWidget {
  const StartupResumePrompt({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<StartupResumePrompt> createState() =>
      _StartupResumePromptState();
}

class _StartupResumePromptState extends ConsumerState<StartupResumePrompt> {
  bool _shownThisLaunch = false;

  @override
  void initState() {
    super.initState();
    // Route navigation alone doesn't always trigger a rebuild of this
    // wrapper (it sits above the router's Navigator), so listen directly
    // for the moment the user actually lands on the home dashboard.
    _router.routerDelegate.addListener(_recheckOnRouteChange);
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_recheckOnRouteChange);
    super.dispose();
  }

  void _recheckOnRouteChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowPrompt(
        notifications: ref.read(notificationsProvider),
        farms: ref.read(farmsProvider).valueOrNull ?? <Farm>[],
        crops: ref.read(cropsProvider).valueOrNull ?? <Crop>[],
        livestock: ref.read(livestockProvider).valueOrNull ?? <Livestock>[],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<domain.Notification> notifications =
        ref.watch(notificationsProvider);
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final List<Crop> crops = ref.watch(cropsProvider).valueOrNull ?? <Crop>[];
    final List<Livestock> livestock =
        ref.watch(livestockProvider).valueOrNull ?? <Livestock>[];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowPrompt(
        notifications: notifications,
        farms: farms,
        crops: crops,
        livestock: livestock,
      );
    });

    return widget.child;
  }

  Future<void> _maybeShowPrompt({
    required List<domain.Notification> notifications,
    required List<Farm> farms,
    required List<Crop> crops,
    required List<Livestock> livestock,
  }) async {
    if (_shownThisLaunch || !mounted) {
      return;
    }
    // Wait until the user has actually reached the home dashboard. Showing
    // the resume prompt or daily fun fact over the splash screen or the
    // auth flow gives them no time to read it before it's navigated away.
    final String location =
        _router.routerDelegate.currentConfiguration.uri.path;
    if (!location.startsWith('/dashboard')) {
      return;
    }
    final User? user = FirebaseService().currentUser;
    if (user == null ||
        (user.email?.isNotEmpty == true && !user.emailVerified)) {
      return;
    }
    _shownThisLaunch = true;

    final _ResumeSummary summary = _buildResumeSummary(
      notifications: notifications,
      farms: farms,
      crops: crops,
      livestock: livestock,
    );
    if (summary.hasContent) {
      final BuildContext? navigatorContext = _rootNavigatorKey.currentContext;
      if (navigatorContext == null) {
        return;
      }
      final String? route = await showDialog<String>(
        context: navigatorContext,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) =>
            _ResumeDialog(summary: summary),
      );
      if (!mounted) {
        return;
      }
      if (route != null && route.isNotEmpty) {
        // Use navigatorContext, not this State's own context: this widget
        // wraps the router's builder from the outside, so it sits above
        // GoRouter's Router in the tree and context.go() here would throw
        // "No GoRouter found in context". navigatorContext comes from
        // _rootNavigatorKey, which IS inside GoRouter's navigator.
        navigatorContext.go(route);
      }
    }

    await _maybeShowFunFactPopup(user: user, farms: farms);
  }

  Future<void> _maybeShowFunFactPopup({
    required User user,
    required List<Farm> farms,
  }) async {
    if (!mounted) {
      return;
    }
    final UserProfile? profile = ref.read(userProfileProvider).valueOrNull;
    if (profile != null && !profile.dailyUpdatesEnabled) {
      return;
    }
    final bool shouldShow =
        await FunFactPopupPreferences.shouldShowToday(user.uid);
    if (!shouldShow || !mounted) {
      return;
    }

    final bool hasCrops = farms.any((Farm farm) => farm.supportsCrops);
    final bool hasLivestock = farms.any((Farm farm) => farm.supportsLivestock);
    final FunFactCategory category = hasCrops && hasLivestock
        ? (math.Random().nextBool()
            ? FunFactCategory.crop
            : FunFactCategory.livestock)
        : hasCrops
            ? FunFactCategory.crop
            : hasLivestock
                ? FunFactCategory.livestock
                : FunFactCategory.general;
    final FunFact fact = pickRandomFunFact(category);

    final BuildContext? navigatorContext = _rootNavigatorKey.currentContext;
    if (navigatorContext == null) {
      return;
    }
    await showDialog<void>(
      context: navigatorContext,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => FunFactPopup(fact: fact),
    );
    await FunFactPopupPreferences.markShownToday(user.uid);
  }
}

class _ResumeSummary {
  const _ResumeSummary({
    required this.latestAction,
    required this.upcomingSchedules,
    required this.openTodos,
    required this.primaryRoute,
  });

  final _ResumeItem? latestAction;
  final List<_ResumeItem> upcomingSchedules;
  final List<_ResumeItem> openTodos;
  final String primaryRoute;

  bool get hasContent =>
      latestAction != null ||
      upcomingSchedules.isNotEmpty ||
      openTodos.isNotEmpty;
}

class _ResumeItem {
  const _ResumeItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.date,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final DateTime date;
}

_ResumeSummary _buildResumeSummary({
  required List<domain.Notification> notifications,
  required List<Farm> farms,
  required List<Crop> crops,
  required List<Livestock> livestock,
}) {
  final DateTime now = DateTime.now();
  final domain.Notification? latestNotification =
      notifications.isEmpty ? null : notifications.first;
  final _ResumeItem? latestAction = latestNotification == null
      ? null
      : _ResumeItem(
          title: latestNotification.title,
          subtitle: latestNotification.message,
          icon: Icons.notifications_active_rounded,
          route: latestNotification.actionUrl?.isNotEmpty == true
              ? latestNotification.actionUrl!
              : '/notifications',
          date: latestNotification.timestamp,
        );

  final List<_ResumeItem> schedules = farms
      .expand(
        (Farm farm) => farm.workspaceTasks
            .where((FarmWorkspaceTask task) =>
                !task.isCompleted &&
                task.dueAt.isAfter(now.subtract(const Duration(hours: 2))))
            .map(
              (FarmWorkspaceTask task) => _ResumeItem(
                title: task.title,
                subtitle: '${farm.name} - ${_friendlyDueLabel(task.dueAt)}',
                icon: Icons.schedule_rounded,
                route: '/farms',
                date: task.dueAt,
              ),
            ),
      )
      .toList()
    ..sort((_ResumeItem a, _ResumeItem b) => a.date.compareTo(b.date));

  final List<_ResumeItem> todos = <_ResumeItem>[
    ...crops.expand(
      (Crop crop) =>
          crop.todoItems.where((FarmTodoItem item) => !item.isCompleted).map(
                (FarmTodoItem item) => _ResumeItem(
                  title: item.title,
                  subtitle: '${crop.name} - ${_friendlyDueLabel(item.dueDate)}',
                  icon: Icons.spa_rounded,
                  route: '/crops',
                  date: item.dueDate,
                ),
              ),
    ),
    ...livestock.expand(
      (Livestock item) =>
          item.todoItems.where((FarmTodoItem task) => !task.isCompleted).map(
                (FarmTodoItem task) => _ResumeItem(
                  title: task.title,
                  subtitle:
                      '${_speciesLabelForResume(item.species)} - ${_friendlyDueLabel(task.dueDate)}',
                  icon: Icons.pets_rounded,
                  route: '/livestock',
                  date: task.dueDate,
                ),
              ),
    ),
  ]..sort((_ResumeItem a, _ResumeItem b) => a.date.compareTo(b.date));

  final String primaryRoute = schedules.isNotEmpty
      ? schedules.first.route
      : todos.isNotEmpty
          ? todos.first.route
          : latestAction?.route ?? '/dashboard';

  return _ResumeSummary(
    latestAction: latestAction,
    upcomingSchedules: schedules.take(3).toList(growable: false),
    openTodos: todos.take(3).toList(growable: false),
    primaryRoute: primaryRoute,
  );
}

class _ResumeDialog extends StatelessWidget {
  const _ResumeDialog({required this.summary});

  final _ResumeSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.playlist_add_check_circle_rounded,
                        color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Welcome back',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text('Your latest farm work is ready to continue.',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (summary.latestAction != null) ...<Widget>[
                const _ResumeSectionTitle(label: 'Most recent action'),
                _ResumeTile(item: summary.latestAction!),
                const SizedBox(height: 14),
              ],
              if (summary.upcomingSchedules.isNotEmpty) ...<Widget>[
                const _ResumeSectionTitle(label: 'Upcoming schedules'),
                ...summary.upcomingSchedules
                    .map((item) => _ResumeTile(item: item)),
                const SizedBox(height: 14),
              ],
              if (summary.openTodos.isNotEmpty) ...<Widget>[
                const _ResumeSectionTitle(label: 'Open todos'),
                ...summary.openTodos.map((item) => _ResumeTile(item: item)),
                const SizedBox(height: 16),
              ],
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pop(summary.primaryRoute),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumeSectionTitle extends StatelessWidget {
  const _ResumeSectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

class _ResumeTile extends StatelessWidget {
  const _ResumeTile({required this.item});

  final _ResumeItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon,
                color: theme.colorScheme.onPrimaryContainer, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _friendlyDueLabel(DateTime date) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime dueDay = DateTime(date.year, date.month, date.day);
  final int dayDelta = dueDay.difference(today).inDays;
  final String time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  if (dayDelta < 0) {
    return 'Overdue';
  }
  if (dayDelta == 0) {
    return 'Today at $time';
  }
  if (dayDelta == 1) {
    return 'Tomorrow at $time';
  }
  return '${date.day}/${date.month}/${date.year} at $time';
}

String _speciesLabelForResume(LivestockSpecies species) {
  switch (species) {
    case LivestockSpecies.goat:
      return 'Goats';
    case LivestockSpecies.chicken:
      return 'Chickens';
    case LivestockSpecies.pig:
      return 'Pigs';
    case LivestockSpecies.cattle:
      return 'Cattle';
    case LivestockSpecies.sheep:
      return 'Sheep';
    case LivestockSpecies.rabbit:
      return 'Rabbits';
    case LivestockSpecies.duck:
      return 'Ducks';
    case LivestockSpecies.fish:
      return 'Fish';
    case LivestockSpecies.snail:
      return 'Snails';
  }
}

Locale _materialLocaleFor(AppLanguage language) {
  switch (language) {
    case AppLanguage.french:
      return const Locale('fr');
    case AppLanguage.hausa:
    case AppLanguage.english:
      return const Locale('en');
  }
}

/// A navigator key used for showing dialogs from outside the GoRouter widget tree
/// (e.g., from the MaterialApp.router builder which sits outside the router's Navigator).
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter configuration for the app navigation.
final GoRouter _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
      redirect: (context, state) {
        return _postAuthRouteForUser(FirebaseService().currentUser);
      },
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
      redirect: (context, state) {
        return _postAuthRouteForUser(FirebaseService().currentUser);
      },
    ),
    GoRoute(
      path: '/invite/:token',
      builder: (context, state) {
        final String token = state.pathParameters['token'] ?? '';
        return InviteAcceptScreen(token: token);
      },
    ),
    GoRoute(
      path: '/phone-auth',
      builder: (context, state) => const PhoneAuthScreen(),
      redirect: (context, state) {
        final User? user = FirebaseService().currentUser;
        if (user == null) {
          return null;
        }
        if (user.email?.isNotEmpty == true && !user.emailVerified) {
          return '/verify-email';
        }
        return '/post-auth';
      },
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/admin-login',
      builder: (context, state) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: '/admin-recovery',
      builder: (context, state) => const AdminRecoveryScreen(),
    ),
    GoRoute(
      path: '/admin-dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin-users',
      builder: (context, state) => const AdminUsersScreen(),
    ),
    GoRoute(
      path: '/admin-users/:id',
      builder: (context, state) {
        final String userId = state.pathParameters['id'] ?? '';
        return AdminUserDetailScreen(userId: userId);
      },
    ),
    GoRoute(
      path: '/admin-admins',
      builder: (context, state) => const AdminAdminsScreen(),
    ),
    GoRoute(
      path: '/admin-news',
      builder: (context, state) => const AdminNewsScreen(),
    ),
    GoRoute(
      path: '/admin-verified-badges',
      builder: (context, state) => const AdminVerifiedBadgesScreen(),
    ),
    GoRoute(
      path: '/admin-notes',
      builder: (context, state) => const AdminNotesScreen(),
    ),
    GoRoute(
      path: '/admin-notifications',
      builder: (context, state) => const AdminNotificationsScreen(),
    ),
    GoRoute(
      path: '/admin-metrics',
      builder: (context, state) => const AdminMetricsScreen(),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (context, state) => const VerifyEmailScreen(),
      redirect: (context, state) {
        final User? user = FirebaseService().currentUser;
        if (user == null) {
          return '/login';
        }
        if (user.email?.isNotEmpty == true && !user.emailVerified) {
          return null;
        }
        return '/post-auth';
      },
    ),
    GoRoute(
      path: '/post-auth',
      builder: (context, state) => const PostAuthGateScreen(),
      redirect: (context, state) {
        final User? user = FirebaseService().currentUser;
        if (user == null) {
          return '/login';
        }
        if (user.email?.isNotEmpty == true && !user.emailVerified) {
          return '/verify-email';
        }
        return null;
      },
    ),
    GoRoute(
      path: '/account-restricted',
      builder: (context, state) => const AccountRestrictedScreen(),
      redirect: _authRedirect,
    ),
    GoRoute(
      path: '/account-setup',
      builder: (context, state) => const AccountSetupScreen(),
      redirect: _authRedirect,
    ),
    GoRoute(
      path: '/app-tour',
      builder: (context, state) => const AppTourScreen(),
      redirect: _authRedirect,
    ),
    ShellRoute(
      builder: (context, state, child) {
        final currentIndex = _getCurrentIndex(state.uri.path);
        return MainScaffold(
          currentIndex: currentIndex,
          child: child,
          onDestinationSelected: (index) {
            final path = _getPathForIndex(index);
            context.go(path);
          },
        );
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
          redirect: _authRedirect,
        ),
        GoRoute(
          path: '/farms',
          builder: (context, state) => const FarmsScreen(),
          redirect: _authRedirect,
        ),
        GoRoute(
          path: '/crops',
          builder: (context, state) => const CropsScreen(),
          redirect: _authRedirect,
        ),
        GoRoute(
          path: '/livestock',
          builder: (context, state) => const LivestockScreen(),
          redirect: _authRedirect,
        ),
        GoRoute(
          path: '/finance',
          builder: (context, state) => const FinanceScreen(),
          redirect: _authRedirect,
        ),
        GoRoute(
          path: '/market-trends',
          builder: (context, state) => const MarketTrendsScreen(),
          redirect: _authRedirect,
        ),
        GoRoute(
          path: '/news',
          builder: (context, state) => const NewsScreen(),
          redirect: _authRedirect,
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
          redirect: _authRedirect,
        ),
      ],
    ),
    GoRoute(
      path: '/ai-advisor',
      builder: (context, state) => const AiAdvisorScreen(),
      redirect: _authRedirect,
    ),
    GoRoute(
      path: '/learn',
      builder: (context, state) => const LearnScreen(),
      redirect: _authRedirect,
    ),
    GoRoute(
      path: '/learn/lesson/:id',
      builder: (context, state) {
        final LearningLesson? lesson =
            findLearningLessonById(state.pathParameters['id'] ?? '');
        return lesson == null
            ? const LearnScreen()
            : LearnLessonDetailScreen(lesson: lesson);
      },
      redirect: _authRedirect,
    ),
    GoRoute(
      path: '/procurement',
      builder: (context, state) => const ProcurementScreen(),
      redirect: _authRedirect,
    ),
    GoRoute(
      path: '/expenses',
      builder: (context, state) => const ExpenseTrackingScreen(),
      redirect: _authRedirect,
    ),
    GoRoute(
      path: '/farm-tasks',
      builder: (context, state) => const FarmTasksScreen(),
      redirect: _authRedirect,
    ),
    GoRoute(
      path: '/schedule',
      builder: (context, state) => const ScheduleScreen(),
      redirect: _authRedirect,
    ),
    GoRoute(
      path: FinanceAiRecapScreen.routeName,
      builder: (context, state) => const FinanceAiRecapScreen(),
      redirect: _authRedirect,
    ),
    GoRoute(
      path: SalesDeskScreen.routeName,
      builder: (context, state) => const SalesDeskScreen(),
      redirect: _authRedirect,
    ),
    GoRoute(
      path: '/sales/receipt/:receiptNumber',
      builder: (context, state) {
        final String receiptNumber =
            state.pathParameters['receiptNumber'] ?? '';
        return SalesReceiptScreen(receiptNumber: receiptNumber);
      },
      redirect: _authRedirect,
    ),
    GoRoute(
      path: SalesInformationScreen.routeName,
      builder: (context, state) => const SalesInformationScreen(),
      redirect: _authRedirect,
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
      redirect: _authRedirect,
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
      redirect: _authRedirect,
    ),
    GoRoute(
      path: '/notifications/:id',
      builder: (context, state) {
        final notification = state.extra as domain.Notification?;
        if (notification == null) {
          // Handle error or redirect
          return const NotificationsScreen();
        }
        return NotificationDetailScreen(notification: notification);
      },
    ),
    // Add more routes as needed
  ],
);

String? _authRedirect(BuildContext context, GoRouterState state) {
  final user = FirebaseService().currentUser;
  if (user == null) {
    return '/login';
  }
  if (user.email?.isNotEmpty == true && !user.emailVerified) {
    return '/verify-email';
  }
  return null;
}

String? _postAuthRouteForUser(User? user) {
  if (user == null) {
    return null;
  }
  if (user.email?.isNotEmpty == true && !user.emailVerified) {
    return '/verify-email';
  }
  return '/post-auth';
}

int _getCurrentIndex(String path) {
  switch (path) {
    case '/dashboard':
      return 0;
    case '/farms':
      return 1;
    case '/crops':
      return 2;
    case '/livestock':
      return 3;
    case '/finance':
      return 4;
    case '/news':
      return 5;
    case '/profile':
      return 6;
    default:
      return 0;
  }
}

String _getPathForIndex(int index) {
  switch (index) {
    case 0:
      return '/dashboard';
    case 1:
      return '/farms';
    case 2:
      return '/crops';
    case 3:
      return '/livestock';
    case 4:
      return '/finance';
    case 5:
      return '/news';
    case 6:
      return '/profile';
    default:
      return '/dashboard';
  }
}
