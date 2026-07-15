import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/services/onboarding_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/remote/firebase_service.dart';

/// Leaf-forward splash screen aligned with the redesigned auth flow.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _pulseController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fade = CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic));
    _pulse = Tween<double>(begin: 0.96, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    await Future<void>.delayed(const Duration(milliseconds: 4300));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? adminSessionEmail = prefs.getString('admin_session_email');
    final bool hasCompletedOnboarding = await OnboardingPreferences.isCompleted();
    final FirebaseService firebaseService = FirebaseService();
    if (!mounted) {
      return;
    }
    if (adminSessionEmail != null && adminSessionEmail.trim().isNotEmpty) {
      if (!mounted) {
        return;
      }
      context.go('/admin-dashboard');
      return;
    }
    if (!hasCompletedOnboarding) {
      if (!mounted) {
        return;
      }
      context.go('/onboarding');
      return;
    }

    User? user = firebaseService.currentUser;
    if (user == null) {
      try {
        user = await firebaseService.authStateChanges
            .where((User? authUser) => authUser != null)
            .timeout(const Duration(seconds: 5))
            .first;
      } catch (_) {
        user = firebaseService.currentUser;
      }
    }

    if (user == null) {
      if (!mounted) {
        return;
      }
      context.go('/login');
      return;
    }

    if (!mounted) {
      return;
    }
    final bool shouldVerify = user.email?.isNotEmpty == true && !user.emailVerified;
    context.go(shouldVerify ? '/verify-email' : '/post-auth');
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(
              AppAssets.uiLeafBackground,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? <Color>[
                          Colors.black.withOpacity(0.34),
                          const Color(0xFF062014).withOpacity(0.82),
                          Colors.black.withOpacity(0.94),
                        ]
                      : <Color>[
                          Colors.white.withOpacity(0.02),
                          const Color(0xFF0F3E2A).withOpacity(0.30),
                          Colors.white.withOpacity(0.86),
                        ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 46,
                            height: 46,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.34)),
                            ),
                            child: Image.asset(AppAssets.appIcon),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'FarmSync Hub',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withOpacity(0.26)),
                            ),
                            child: Text(
                              'Nigeria',
                              style: theme.textTheme.labelMedium?.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Center(
                        child: ScaleTransition(
                          scale: _pulse,
                          child: Container(
                            width: 246,
                            padding: const EdgeInsets.fromLTRB(24, 34, 24, 26),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.40),
                              borderRadius: BorderRadius.circular(38),
                              border: Border.all(color: Colors.white.withOpacity(0.18)),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.32),
                                  blurRadius: 36,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Image.asset(AppAssets.appIcon, width: 58, height: 58),
                                const SizedBox(height: 26),
                                Text(
                                  'Your smart farm companion',
                                  textAlign: TextAlign.left,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 30,
                                    height: 1.15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                Container(
                                  height: 48,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.20),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Loading',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Center(
                        child: SizedBox(
                          width: 38,
                          height: 38,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: isDark ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Preparing your farm workspace',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isDark ? Colors.white70 : AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
