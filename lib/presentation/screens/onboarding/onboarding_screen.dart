import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/services/onboarding_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_button.dart';

/// Theme-aware onboarding carousel for the first app launch.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  final List<OnboardingPageData> _pages = const <OnboardingPageData>[
    OnboardingPageData(
      title: 'Manage every farm from one workspace',
      subtitle:
          'Create farms, track fields, store documents, and keep environmental readings close to the work.',
      animationAsset: AppAssets.onboardingWelcomeAnimation,
      accentColor: Color(0xFF5F9D58),
      chips: <OnboardingChipData>[
        OnboardingChipData(
            label: 'Farm profiles', assetPath: AppAssets.uiGallery05),
        OnboardingChipData(
            label: 'Field records', assetPath: AppAssets.uiGallery06),
      ],
    ),
    OnboardingPageData(
      title: 'Connect crops, animals, inventory, and sales',
      subtitle:
          'Follow produce from planning to buyer receipt, with livestock and procurement records in the same flow.',
      animationAsset: AppAssets.onboardingSyncAnimation,
      accentColor: Color(0xFFCE9B3A),
      chips: <OnboardingChipData>[
        OnboardingChipData(label: 'Produce', assetPath: AppAssets.uiGallery07),
        OnboardingChipData(label: 'Market', assetPath: AppAssets.uiGallery08),
        OnboardingChipData(
            label: 'Logistics', assetPath: AppAssets.uiGallery09),
      ],
    ),
    OnboardingPageData(
      title: 'Learn, ask AI, and act with confidence',
      subtitle:
          'Use lessons, field prompts, weather guidance, and notifications to keep farm decisions moving.',
      animationAsset: AppAssets.onboardingSuccessAnimation,
      accentColor: Color(0xFF3D6FA8),
      chips: <OnboardingChipData>[
        OnboardingChipData(label: 'Insights', assetPath: AppAssets.uiGallery10),
        OnboardingChipData(label: 'Harvest', assetPath: AppAssets.uiGallery01),
      ],
      isLastPage: true,
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
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const <Color>[
                    AppColors.darkPrimaryBackground,
                    Color(0xFF0E1A15),
                    AppColors.darkPrimaryBackground,
                  ]
                : const <Color>[
                    Color(0xFFFFFBF2),
                    Color(0xFFEFF8EA),
                    Color(0xFFE4F1DD),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkElevatedCard
                            : scheme.surface.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : scheme.outlineVariant),
                        boxShadow: isDark
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      child: Image.asset(AppAssets.appIcon),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'FarmSync Hub',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark ? Colors.white : AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (int page) =>
                      setState(() => _currentPage = page),
                  itemBuilder: (BuildContext context, int index) {
                    return _OnboardingPage(data: _pages[index]);
                  },
                ),
              ),
              _BottomControls(
                currentPage: _currentPage,
                pageCount: _pages.length,
                isCompleting: _isCompleting,
                onBack: _currentPage == 0 ? _completeOnboarding : _previousPage,
                onNext: _currentPage == _pages.length - 1
                    ? _completeOnboarding
                    : _nextPage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) {
      return;
    }

    setState(() => _isCompleting = true);
    await OnboardingPreferences.markCompleted();
    if (!mounted) {
      return;
    }
    context.go('/login');
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.currentPage,
    required this.pageCount,
    required this.isCompleting,
    required this.onBack,
    required this.onNext,
  });

  final int currentPage;
  final int pageCount;
  final bool isCompleting;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool isLastPage = currentPage == pageCount - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const <Color>[AppColors.darkCard, AppColors.darkElevatedCard]
                : <Color>[
                    theme.colorScheme.surfaceContainerHighest,
                    theme.colorScheme.surfaceContainer,
                  ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(isDark ? 0.42 : 0.10),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    isLastPage
                        ? 'Ready to begin'
                        : 'Step ${currentPage + 1} of $pageCount',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: AppColors.primary),
                  ),
                ),
                Row(
                  children: List<Widget>.generate(
                    pageCount,
                    (int index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      width: currentPage == index ? 26 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: currentPage == index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton.secondary(
                    onPressed: isCompleting ? null : onBack,
                    child: Text(currentPage == 0 ? 'Skip' : 'Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AppButton.primary(
                    onPressed: isCompleting ? null : onNext,
                    child: Text(isLastPage ? 'Enter FarmSync' : 'Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPageData {
  const OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.animationAsset,
    required this.accentColor,
    required this.chips,
    this.isLastPage = false,
  });

  final String title;
  final String subtitle;
  final String animationAsset;
  final Color accentColor;
  final List<OnboardingChipData> chips;
  final bool isLastPage;
}

class OnboardingChipData {
  const OnboardingChipData({
    required this.label,
    required this.assetPath,
  });

  final String label;
  final String assetPath;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const <Color>[
                          AppColors.darkCard,
                          AppColors.darkElevatedCard
                        ]
                      : <Color>[
                          theme.colorScheme.surfaceContainerHighest,
                          theme.colorScheme.surfaceContainer,
                        ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: theme.colorScheme.shadow
                        .withOpacity(isDark ? 0.45 : 0.10),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: data.accentColor.withOpacity(isDark ? 0.12 : 0.07),
                    blurRadius: 32,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _FeaturePill(
                        icon: data.isLastPage
                            ? Icons.check_circle_rounded
                            : Icons.auto_awesome_rounded,
                        label: data.isLastPage ? 'Ready' : 'Farm workflow',
                        tint: data.accentColor,
                      ),
                      const Spacer(),
                      Icon(Icons.swipe_rounded,
                          color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            data.accentColor.withOpacity(isDark ? 0.16 : 0.11),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Lottie.asset(
                          data.animationAsset,
                          fit: BoxFit.contain,
                          repeat: !data.isLastPage,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: data.chips
                        .map(
                          (OnboardingChipData chip) => _AssetChip(
                            chip: chip,
                            tint: data.accentColor,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 31,
              color: isDark ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.55,
              color:
                  isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: tint.withOpacity(isDark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withOpacity(isDark ? 0.4 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon,
              size: 17, color: isDark ? tint : theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isDark ? Colors.white : null,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetChip extends StatelessWidget {
  const _AssetChip({
    required this.chip,
    required this.tint,
  });

  final OnboardingChipData chip;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        // A tier *lighter* than the parent card (not `colorScheme.surface`,
        // which is darker in dark mode and reads as a hole cut into the card).
        color: isDark ? AppColors.darkElevatedCard : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark
                ? AppColors.darkBorder
                : theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: tint.withOpacity(isDark ? 0.24 : 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(chip.assetPath, fit: BoxFit.contain),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              chip.label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
