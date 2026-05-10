import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/user_walkthrough_preferences.dart';
import '../../../providers/auth_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/farm_scene_artwork.dart';

class AppTourScreen extends ConsumerStatefulWidget {
  const AppTourScreen({super.key});

  @override
  ConsumerState<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends ConsumerState<AppTourScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_TourStep> _steps = const <_TourStep>[
    _TourStep(
      title: 'This is your farm command center',
      subtitle: 'The dashboard pulls together farms, crops, livestock, finance, and alerts so new users know where daily work starts.',
      badge: 'Home',
      icon: Icons.home_rounded,
      tint: Color(0xFFE9F4DB),
      variant: FarmArtworkVariant.dashboard,
    ),
    _TourStep(
      title: 'Use the bottom navigation to move fast',
      subtitle: 'Jump between farms, crops, livestock, finance, and profile without losing context.',
      badge: 'Navigation',
      icon: Icons.navigation_rounded,
      tint: Color(0xFFDFF1FF),
      variant: FarmArtworkVariant.field,
    ),
    _TourStep(
      title: 'Add records first, then let the app connect them',
      subtitle: 'Create farms, then attach crop plans, animal groups, income, and expenses to the right operation.',
      badge: 'Workflow',
      icon: Icons.account_tree_rounded,
      tint: Color(0xFFFFEBD0),
      variant: FarmArtworkVariant.crops,
    ),
    _TourStep(
      title: 'Reach support anytime',
      subtitle: 'Settings now includes email support and a WhatsApp shortcut so help is always within reach.',
      badge: 'Support',
      icon: Icons.support_agent_rounded,
      tint: Color(0xFFEDE8FF),
      variant: FarmArtworkVariant.welcome,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLast = _currentIndex == _steps.length - 1;
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              scheme.surface,
              scheme.surfaceContainerHighest.withOpacity(0.92),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'FarmSync tour',
                      style: theme.textTheme.titleLarge,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _finishTour,
                      child: const Text('Skip'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _steps.length,
                    onPageChanged: (int value) => setState(() => _currentIndex = value),
                    itemBuilder: (BuildContext context, int index) {
                      final _TourStep step = _steps[index];
                      return AppCard(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: step.tint,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(step.badge),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                step.title,
                                style: theme.textTheme.headlineSmall?.copyWith(fontSize: 30),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                step.subtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                              ),
                              const SizedBox(height: 22),
                              Expanded(
                                child: Stack(
                                  children: <Widget>[
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        width: 84,
                                        height: 84,
                                        decoration: BoxDecoration(
                                          color: step.tint.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(28),
                                        ),
                                        child: Icon(step.icon, size: 36, color: theme.colorScheme.primary),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: FarmSceneArtwork(
                                        height: 260,
                                        variant: step.variant,
                                        borderRadius: const BorderRadius.all(Radius.circular(32)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(
                    _steps.length,
                    (int index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: index == _currentIndex ? 26 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index == _currentIndex ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton.secondary(
                        onPressed: _currentIndex == 0 ? _finishTour : _goBack,
                        child: Text(_currentIndex == 0 ? 'Skip' : 'Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppButton.primary(
                        onPressed: isLast ? _finishTour : _goNext,
                        child: Text(isLast ? 'Enter app' : 'Next'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goNext() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _goBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishTour() async {
    final String? userId = ref.read(firebaseServiceProvider).currentUser?.uid;
    if (userId != null) {
      await UserWalkthroughPreferences.markCompleted(userId);
    }
    if (!mounted) {
      return;
    }
    context.go('/dashboard');
  }
}

class _TourStep {
  const _TourStep({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.tint,
    required this.variant,
  });

  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color tint;
  final FarmArtworkVariant variant;
}
