import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'domain/models/notification.dart' as domain;
import 'data/remote/firebase_service.dart';
import 'core/services/farm_notification_service.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/common/layouts/main_scaffold.dart';
import 'presentation/screens/ai_advisor/ai_advisor_screen.dart';
import 'presentation/screens/auth/forgot_password_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/account_restricted_screen.dart';
import 'presentation/screens/auth/post_auth_gate_screen.dart';
import 'presentation/screens/auth/phone_auth_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
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
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/profile/account_setup_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/onboarding/app_tour_screen.dart';
import 'presentation/screens/notifications/notifications_screen.dart';
import 'presentation/screens/notifications/notification_detail_screen.dart';
import 'providers/app_preferences_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';

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
    await ref.read(firebaseMessagingServiceProvider).initialize();
    _messageSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _appOpenSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpen);
    final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpen(initialMessage);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final String title = message.notification?.title ?? message.data['title'] as String? ?? 'FarmSync update';
    final String body = message.notification?.body ?? message.data['body'] as String? ?? message.data['message'] as String? ?? '';
    final String? actionUrl = message.data['actionUrl'] as String? ?? message.data['click_action'] as String?;

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

    final bool notificationsEnabled = ref.read(appSettingsProvider).notificationsEnabled;
    if (notificationsEnabled) {
      await FarmNotificationService.instance.showNow(
        id: message.messageId?.hashCode.abs() ?? DateTime.now().millisecondsSinceEpoch,
        title: title,
        body: body,
        payload: actionUrl,
      );
    }
  }

  void _handleMessageOpen(RemoteMessage message) {
    final String? actionUrl = message.data['actionUrl'] as String? ?? message.data['click_action'] as String?;
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
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
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

/// GoRouter configuration for the app navigation.
final GoRouter _router = GoRouter(
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
        final String receiptNumber = state.pathParameters['receiptNumber'] ?? '';
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
