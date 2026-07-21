import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/user_walkthrough_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/user_profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/news_feed_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../common/widgets/farm_scene_artwork.dart';

class PostAuthGateScreen extends ConsumerStatefulWidget {
  const PostAuthGateScreen({super.key});

  @override
  ConsumerState<PostAuthGateScreen> createState() => _PostAuthGateScreenState();
}

class _PostAuthGateScreenState extends ConsumerState<PostAuthGateScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<UserProfile?> profileAsync =
        ref.watch(userProfileProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    profileAsync.whenOrNull(
      data: (UserProfile? profile) {
        if (_navigated || !mounted) {
          return;
        }
        _handleNavigation(profile);
      },
      error: (_, __) {
        if (_navigated || !mounted) {
          return;
        }
        _navigated = true;
        _handleProfileError();
      },
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? <Color>[
                    const Color(0xFF07120C),
                    const Color(0xFF102219),
                    scheme.surface,
                  ]
                : const <Color>[
                    Color(0xFFFFFBF2),
                    Color(0xFFEFF8EA),
                    Color(0xFFDDEFD5),
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              scheme.surface.withOpacity(isDark ? 0.22 : 0.78),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Text(
                          'Preparing workspace',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isDark ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: scheme.outlineVariant),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.primary
                                .withOpacity(isDark ? 0.18 : 0.10),
                            blurRadius: 28,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: const FarmSceneArtwork(
                        height: 260,
                        variant: FarmArtworkVariant.dashboard,
                        borderRadius: BorderRadius.all(Radius.circular(32)),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Setting up FarmSync',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: isDark ? Colors.white : AppColors.primary,
                        fontSize: 34,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We are checking your profile, sync state, and walkthrough progress.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color:
                            isDark ? Colors.white70 : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: isDark ? Colors.white : AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Checks connectivity with a short timeout — if the platform channel
  /// stalls (seen on some devices during network-state transitions), treat
  /// that as offline rather than hanging navigation indefinitely.
  Future<bool> _checkOffline() async {
    try {
      final ConnectivityResult connectivity = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 3));
      return connectivity == ConnectivityResult.none;
    } catch (_) {
      return true;
    }
  }

  Future<void> _handleProfileError() async {
    final String? userId = ref.read(firebaseServiceProvider).currentUser?.uid;
    final bool isOffline = await _checkOffline();
    final bool hasCompletedWalkthrough = userId == null
        ? false
        : await UserWalkthroughPreferences.isCompleted(userId);
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isOffline) {
        context.go(hasCompletedWalkthrough ? '/dashboard' : '/app-tour');
        return;
      }
      context.go('/account-setup');
    });
  }

  Future<void> _handleNavigation(UserProfile? profile) async {
    _navigated = true;
    final String? userId = ref.read(firebaseServiceProvider).currentUser?.uid;
    final bool isOffline = await _checkOffline();
    if (!isOffline) {
      try {
        await Future.wait(<Future<void>>[
          ref.read(notificationsProvider.notifier).refresh(),
          ref.read(newsFeedProvider.notifier).refresh(),
          ref.read(transactionsProvider.notifier).refresh(),
        ]).timeout(const Duration(seconds: 10));
      } catch (_) {
        // Remote refresh is useful, but it should not block workspace entry.
      }
    }
    final bool hasCompletedWalkthrough = userId == null
        ? false
        : await UserWalkthroughPreferences.isCompleted(userId);
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (profile?.isDisabled == true) {
        context.go('/account-restricted');
        return;
      }
      if (isOffline) {
        context.go(hasCompletedWalkthrough ? '/dashboard' : '/app-tour');
        return;
      }
      if (profile?.isComplete != true) {
        context.go('/account-setup');
        return;
      }
      context.go(hasCompletedWalkthrough ? '/dashboard' : '/app-tour');
    });
  }
}
