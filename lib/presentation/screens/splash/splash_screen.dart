import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/services/onboarding_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/remote/firebase_service.dart';
import '../../common/widgets/farm_scene_artwork.dart';

/// Splash screen with a soft illustrated brand reveal.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final AnimationController _scaleController;
  late final Animation<double> _scale;
  late final AnimationController _textController;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    _scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut));

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _textFade = CurvedAnimation(parent: _textController, curve: Curves.easeIn);

    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    await Future<void>.delayed(const Duration(milliseconds: 6000));
    final bool hasCompletedOnboarding = await OnboardingPreferences.isCompleted();
    final firebaseService = FirebaseService();
    if (!mounted) {
      return;
    }
    if (!hasCompletedOnboarding) {
      context.go('/onboarding');
      return;
    }

    final user = firebaseService.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    context.go(user.emailVerified ? '/post-auth' : '/verify-email');
  }

  @override
  void dispose() {
    _controller.dispose();
    _scaleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF4CAF50), // Green
              Color(0xFF8BC34A), // Light green
              Color(0xFFFFF8E1), // Cream
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.76),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Jos South',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    ScaleTransition(
                      scale: _scale,
                      child: const FarmSceneArtwork(
                        height: 320,
                        variant: FarmArtworkVariant.welcome,
                        showFarmer: true,
                        borderRadius: BorderRadius.all(Radius.circular(36)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeTransition(
                      opacity: _textFade,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.10),
                              blurRadius: 28,
                              offset: const Offset(0, 16),
                            ),
                          ]
                        ),
                        child: Column(
                        children: <Widget>[
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.12),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(AppAssets.appIcon),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'FarmSync',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 36,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nurturing farms, cultivating futures. Experience the harmony of nature and technology in modern agriculture.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List<Widget>.generate(
                              3,
                              (int index) => Container(
                                width: index == 0 ? 24 : 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: index == 0 ? AppColors.primaryMid : AppColors.borderLight,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                 
                 ) ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
