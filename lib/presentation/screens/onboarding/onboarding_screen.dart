import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/services/onboarding_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_button.dart';

/// Onboarding screen with a branded carousel introduction.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  final List<OnboardingPageData> _pages = <OnboardingPageData>[
    const OnboardingPageData(
      title: 'Run your farm from one calm workspace',
      subtitle: 'Track crops, livestock, records, and daily work without the clutter.',
      animationAsset: AppAssets.onboardingWelcomeAnimation,
      accentColor: AppColors.primaryMid,
      chips: const <OnboardingChipData>[
        OnboardingChipData(label: 'Field plans', assetPath: AppAssets.onboardingField),
        OnboardingChipData(label: 'Farm records', assetPath: AppAssets.onboardingFarm),
      ],
    ),
    const OnboardingPageData(
      title: 'Stay on top of tasks, harvests, and market flow',
      subtitle: 'Organize activities, monitor produce, and keep everyone aligned from planting to pickup.',
      animationAsset: AppAssets.onboardingSyncAnimation,
      accentColor: AppColors.amberAccent,
      chips: const <OnboardingChipData>[
        OnboardingChipData(label: 'Produce', assetPath: AppAssets.onboardingProduce),
        OnboardingChipData(label: 'Market', assetPath: AppAssets.onboardingMarket),
        OnboardingChipData(label: 'Logistics', assetPath: AppAssets.onboardingLogistics),
      ],
    ),
    const OnboardingPageData(
      title: 'Start with clarity and grow with confidence',
      subtitle: 'Make smarter decisions with a simple dashboard built for real farm operations.',
      animationAsset: AppAssets.onboardingSuccessAnimation,
      accentColor: AppColors.primary,
      chips: const <OnboardingChipData>[
        OnboardingChipData(label: 'Insights', assetPath: AppAssets.onboardingStrategy),
        OnboardingChipData(label: 'Harvest', assetPath: AppAssets.onboardingHarvest),
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

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              const Color(0xFFE8F6EA),
              Colors.white,
              AppColors.surfaceLight,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.86),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 32,
                            height: 32,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Image.asset(AppAssets.appIcon),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'AgriCare',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                'Field-ready onboarding',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        _completeOnboarding();
                      },
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (int page) => setState(() => _currentPage = page),
                  itemBuilder: (BuildContext context, int index) {
                    return _OnboardingPage(data: _pages[index]);
                  },
                ),
              ),
              _buildBottomSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLastPage = _currentPage == _pages.length - 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 14),
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
                  isLastPage ? 'Everything is ready' : 'Step ${_currentPage + 1} of ${_pages.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              Text(
                isLastPage ? 'Let\'s go' : 'Swipe or tap next',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(
              _pages.length,
              (int index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: _currentPage == index ? 26 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _currentPage == index ? AppColors.primaryMid : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton(
                  onPressed: _currentPage == 0
                      ? () {
                          _completeOnboarding();
                        }
                      : _previousPage,
                  child: Text(_currentPage == 0 ? 'Skip' : 'Back'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: AppButton.primary(
                  onPressed: _isCompleting
                      ? null
                      : (_currentPage == _pages.length - 1
                          ? () {
                              _completeOnboarding();
                            }
                          : _nextPage),
                  child: Text(_currentPage == _pages.length - 1 ? 'Enter dashboard' : 'Next'),
                ),
              ),
            ],
          ),
        ],
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(38),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: data.accentColor.withOpacity(0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _MetricPill(
                        icon: Icons.auto_awesome_rounded,
                        label: data.isLastPage ? 'Ready to launch' : 'Smart farm flow',
                        tint: data.accentColor,
                      ),
                      const Spacer(),
                      Container(
                        width: 54,
                        height: 54,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Image.asset(AppAssets.appIcon),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            data.accentColor.withOpacity(0.16),
                            Colors.white,
                          ],
                        ),
                      ),
                      child: Stack(
                        children: <Widget>[
                          Positioned(
                            top: -12,
                            right: -8,
                            child: Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                color: data.accentColor.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Lottie.asset(
                                data.animationAsset,
                                fit: BoxFit.contain,
                                repeat: !data.isLastPage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: data.chips
                        .map((OnboardingChipData chip) => _AssetChip(
                              chip: chip,
                              tint: data.accentColor,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: <Widget>[
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 32,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  data.subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
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

    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: tint.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(chip.assetPath, fit: BoxFit.contain),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              chip.label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
