import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/user_walkthrough_preferences.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_profile_provider.dart';

class PostAuthGateScreen extends ConsumerStatefulWidget {
  const PostAuthGateScreen({super.key});

  @override
  ConsumerState<PostAuthGateScreen> createState() => _PostAuthGateScreenState();
}

class _PostAuthGateScreenState extends ConsumerState<PostAuthGateScreen> {
  bool _navigated = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    profileAsync.whenOrNull(
      data: (profile) {
        if (_navigated || !mounted) {
          return;
        }
        _handleNavigation(profile?.isComplete == true);
      },
      error: (_, __) {
        if (_navigated || !mounted) {
          return;
        }
        _navigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go('/account-setup');
        });
      },
    );

    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.8),
        ),
      ),
    );
  }

  Future<void> _handleNavigation(bool isComplete) async {
    _navigated = true;
    final String? userId = ref.read(firebaseServiceProvider).currentUser?.uid;
    final bool hasCompletedWalkthrough = userId == null
        ? false
        : await UserWalkthroughPreferences.isCompleted(userId);
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isComplete) {
        context.go('/account-setup');
        return;
      }
      context.go(hasCompletedWalkthrough ? '/dashboard' : '/app-tour');
    });
  }
}
