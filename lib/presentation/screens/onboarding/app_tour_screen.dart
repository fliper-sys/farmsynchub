import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/services/user_walkthrough_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/app_tour_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../learn/engagement_widgets.dart' show LottieOrIcon;

/// Shown once after a person's first sign-in.
///
/// A warm, animated welcome that offers a guided tour. "Start the tour"
/// opens the real dashboard and spotlights its widgets one by one (see
/// `AppSpotlightTour`); "Skip" goes straight in. Either way the welcome is
/// not shown again for this account; the tour can be replayed from Settings.
class AppTourScreen extends ConsumerStatefulWidget {
  const AppTourScreen({super.key});

  @override
  ConsumerState<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends ConsumerState<AppTourScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  bool _leaving = false;

  @override
  void dispose() {
    _enter.dispose();
    _float.dispose();
    super.dispose();
  }

  /// A fade + rise that starts [from] of the way through the entrance.
  Animation<double> _stagger(double from, double to) => CurvedAnimation(
        parent: _enter,
        curve: Interval(from, to, curve: Curves.easeOutCubic),
      );

  Widget _reveal(Animation<double> a, Widget child) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
                  .animate(a),
          child: child,
        ),
      );

  Future<void> _continue({required bool tour}) async {
    if (_leaving) {
      return;
    }
    setState(() => _leaving = true);
    final String? userId = ref.read(firebaseServiceProvider).currentUser?.uid;
    if (userId != null) {
      await UserWalkthroughPreferences.markCompleted(userId);
    }
    if (!mounted) {
      return;
    }
    ref.read(appTourRequestedProvider.notifier).state = tour;
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLanguage language = ref.watch(appLanguageProvider);
    final String? profileName =
        ref.watch(userProfileProvider).valueOrNull?.fullName.trim();
    final String name = (profileName != null && profileName.isNotEmpty)
        ? profileName.split(' ').first
        : ref.watch(firebaseServiceProvider).currentUser?.displayName
                ?.trim()
                .split(' ')
                .first ??
            '';

    final List<_Highlight> highlights = <_Highlight>[
      _Highlight(
        Icons.agriculture_rounded,
        language.tr(
            en: 'Farms, crops and livestock',
            ha: 'Gonaki, amfanin gona da dabbobi',
            fr: 'Fermes, cultures et élevage'),
        language.tr(
            en: 'Guided steps make adding records easy',
            ha: 'Matakai masu jagora suna sauƙaƙa ƙara bayanai',
            fr: 'Des étapes guidées simplifient la saisie'),
      ),
      _Highlight(
        Icons.payments_rounded,
        language.tr(
            en: 'Sales, costs and profit',
            ha: 'Sayarwa, kuɗin da aka kashe da riba',
            fr: 'Ventes, coûts et bénéfices'),
        language.tr(
            en: 'See how your farm is really doing',
            ha: 'Ka ga yadda gonarka take tafiya da gaske',
            fr: 'Voyez comment va vraiment votre ferme'),
      ),
      _Highlight(
        Icons.auto_awesome_rounded,
        language.tr(
            en: 'AI advice in your language',
            ha: 'Shawarar AI da harshenka',
            fr: 'Conseils IA dans votre langue'),
        language.tr(
            en: 'English, Hausa and French',
            ha: 'Turanci, Hausa da Faransanci',
            fr: 'Anglais, haoussa et français'),
      ),
    ];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Slowly drifting farm photo behind everything.
          AnimatedBuilder(
            animation: _float,
            builder: (BuildContext context, Widget? child) => Transform.scale(
              scale: 1.08 + _float.value * 0.05,
              child: child,
            ),
            child: Image.asset(AppAssets.uiFarmLandscape, fit: BoxFit.cover),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withOpacity(0.35),
                  Colors.black.withOpacity(0.55),
                  const Color(0xFF06281A).withOpacity(0.94),
                ],
                stops: const <double>[0, 0.4, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed:
                          _leaving ? null : () => _continue(tour: false),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.white),
                      child: Text(language.tr(
                          en: 'Skip', ha: 'Tsallake', fr: 'Passer')),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            ScaleTransition(
                              scale: Tween<double>(begin: 0.6, end: 1).animate(
                                CurvedAnimation(
                                  parent: _enter,
                                  curve: const Interval(0, 0.5,
                                      curve: Curves.elasticOut),
                                ),
                              ),
                              child: AnimatedBuilder(
                                animation: _float,
                                builder: (BuildContext context, Widget? child) {
                                  return Transform.translate(
                                    offset: Offset(
                                        0,
                                        math.sin(_float.value * math.pi) *
                                            -8),
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.14),
                                    border: Border.all(
                                        color:
                                            Colors.white.withOpacity(0.3)),
                                  ),
                                  child: LottieOrIcon(
                                    asset: AppAssets.confettiAnimation,
                                    fallbackIcon: Icons.celebration_rounded,
                                    fallbackColor: Colors.white,
                                    size: 150,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _reveal(
                              _stagger(0.25, 0.65),
                              Text(
                                name.isEmpty
                                    ? language.tr(
                                        en: 'Welcome aboard!',
                                        ha: 'Barka da zuwa!',
                                        fr: 'Bienvenue à bord !')
                                    : language.tr(
                                        en: 'Welcome, $name!',
                                        ha: 'Barka da zuwa, $name!',
                                        fr: 'Bienvenue, $name !'),
                                textAlign: TextAlign.center,
                                style:
                                    theme.textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _reveal(
                              _stagger(0.35, 0.75),
                              Text(
                                language.tr(
                                  en: 'Your account is ready. Here is what you can do:',
                                  ha: 'Asusunka ya shirya. Ga abin da za ka iya yi:',
                                  fr: 'Votre compte est prêt. Voici ce que vous pouvez faire :',
                                ),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            for (int i = 0; i < highlights.length; i++)
                              _reveal(
                                _stagger(0.45 + i * 0.12, 0.85 + i * 0.05),
                                _HighlightRow(item: highlights[i]),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _reveal(
                    _stagger(0.7, 1),
                    Column(
                      children: <Widget>[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                _leaving ? null : () => _continue(tour: true),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryDeep,
                              minimumSize: const Size.fromHeight(54),
                            ),
                            icon: const Icon(Icons.play_circle_rounded),
                            label: Text(language.tr(
                                en: 'Take the quick tour',
                                ha: 'Yi yawon gaggawa',
                                fr: 'Faire la visite rapide')),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed:
                              _leaving ? null : () => _continue(tour: false),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.white),
                          child: Text(language.tr(
                              en: 'I will explore on my own',
                              ha: 'Zan bincika da kaina',
                              fr: 'Je vais explorer seul')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Highlight {
  const _Highlight(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.item});

  final _Highlight item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.38),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    item.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.82),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
