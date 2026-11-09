import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/services/onboarding_preferences.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../common/wizard/wizard_models.dart' show LocalizedText;
import '../learn/engagement_widgets.dart' show LottieOrIcon;

/// First-launch introduction.
///
/// Full-screen farm photos crossfade and drift as the person swipes, an
/// animated illustration floats over a frosted panel, and the text and
/// feature chips rise in one after another. Everything is available in
/// English, Hausa and French, switchable from the top bar.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const List<_Page> _pages = <_Page>[
    _Page(
      photo: AppAssets.uiFarmLandscape,
      animation: AppAssets.onboardingWelcomeAnimation,
      icon: Icons.agriculture_rounded,
      title: LocalizedText(
        'Run every farm from one place',
        ha: 'Ka gudanar da kowace gona daga wuri ɗaya',
        fr: 'Gérez chaque ferme depuis un seul endroit',
      ),
      body: LocalizedText(
        'Create farms, keep records and see what needs doing today, even with a weak signal. Record work offline and keep daily learning streaks growing.',
        ha: 'Ƙirƙiri gonaki, adana bayanai ka ga abin da ya kamata a yi a yau, ko da sigina ba ta da ƙarfi.',
        fr: 'Créez vos fermes, tenez vos registres et voyez ce qu’il faut faire aujourd’hui, même avec un signal faible.',
      ),
      chips: <_Chip>[
        _Chip(
          Icons.home_work_rounded,
          LocalizedText('Farm profiles', ha: 'Bayanan gona', fr: 'Fiches de ferme'),
        ),
        _Chip(
          Icons.cloud_off_rounded,
          LocalizedText('Works offline', ha: 'Yana aiki ba intanet', fr: 'Hors ligne'),
        ),
      ],
    ),
    _Page(
      photo: AppAssets.uiGallery03,
      animation: AppAssets.onboardingSyncAnimation,
      icon: Icons.eco_rounded,
      title: LocalizedText(
        'Crops, animals and money together',
        ha: 'Amfanin gona, dabbobi da kuɗi a wuri ɗaya',
        fr: 'Cultures, animaux et argent réunis',
      ),
      body: LocalizedText(
        'Follow a crop from planting to harvest, look after your animals and see what you earn and spend.',
        ha: 'Bi amfanin gona daga shuka zuwa girbi, kula da dabbobinka ka ga abin da kake samu da kashewa.',
        fr: 'Suivez une culture de la plantation à la récolte, prenez soin de vos animaux et voyez vos revenus et dépenses.',
      ),
      chips: <_Chip>[
        _Chip(
          Icons.grass_rounded,
          LocalizedText('Crops', ha: 'Amfanin gona', fr: 'Cultures'),
        ),
        _Chip(
          Icons.pets_rounded,
          LocalizedText('Livestock', ha: 'Dabbobi', fr: 'Élevage'),
        ),
        _Chip(
          Icons.payments_rounded,
          LocalizedText('Finance', ha: 'Kuɗi', fr: 'Finances'),
        ),
      ],
    ),
    _Page(
      photo: AppAssets.uiSmartFarm,
      animation: AppAssets.onboardingSuccessAnimation,
      icon: Icons.auto_awesome_rounded,
      title: LocalizedText(
        'Learn and get advice in your language',
        ha: 'Koyi ka samu shawara da harshenka',
        fr: 'Apprenez et conseillez-vous dans votre langue',
      ),
      body: LocalizedText(
        'Short lessons, weather tips, farm news and an AI advisor that speaks English, Hausa and French.',
        ha: 'Gajerun darussa, shawarwarin yanayi, labaran noma da mai ba da shawara na AI da ke jin Turanci, Hausa da Faransanci.',
        fr: 'Leçons courtes, conseils météo, actualités agricoles et un conseiller IA qui parle anglais, haoussa et français.',
      ),
      chips: <_Chip>[
        _Chip(
          Icons.school_rounded,
          LocalizedText('Lessons', ha: 'Darussa', fr: 'Leçons'),
        ),
        _Chip(
          Icons.newspaper_rounded,
          LocalizedText('News', ha: 'Labarai', fr: 'Actualités'),
        ),
        _Chip(
          Icons.chat_rounded,
          LocalizedText('AI advisor', ha: 'Mai ba da shawara', fr: 'Conseiller IA'),
        ),
      ],
    ),
  ];

  final PageController _controller = PageController();
  int _current = 0;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  // Rebuilds the photo layer while swiping so it crossfades with the finger.
  void _onScroll() => setState(() {});

  double get _page => _controller.hasClients && _controller.page != null
      ? _controller.page!
      : _current.toDouble();

  void _go(int index) => _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );

  Future<void> _finish() async {
    if (_completing) {
      return;
    }
    setState(() => _completing = true);
    await OnboardingPreferences.markCompleted();
    if (!mounted) {
      return;
    }
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final bool isLast = _current == _pages.length - 1;
    final double page = _page;

    return Scaffold(
      backgroundColor: const Color(0xFF06281A),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Photos: crossfade and drift with the swipe.
          for (int i = 0; i < _pages.length; i++)
            Opacity(
              opacity: (1 - (page - i).abs()).clamp(0.0, 1.0).toDouble(),
              child: Transform.translate(
                offset: Offset((i - page) * -40, 0),
                child: Transform.scale(
                  scale: 1.18,
                  child: Image.asset(_pages[i].photo, fit: BoxFit.cover),
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withOpacity(0.45),
                  Colors.black.withOpacity(0.25),
                  const Color(0xFF06281A).withOpacity(0.92),
                ],
                stops: const <double>[0, 0.35, 0.78],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                _TopBar(
                  language: language,
                  skipLabel:
                      language.tr(en: 'Skip', ha: 'Tsallake', fr: 'Passer'),
                  onLanguage: (AppLanguage value) => ref
                      .read(appLanguageProvider.notifier)
                      .setLanguage(value),
                  onSkip: _finish,
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (int value) =>
                        setState(() => _current = value),
                    itemBuilder: (BuildContext context, int index) {
                      return _PageView(
                        data: _pages[index],
                        language: language,
                        active: index == _current,
                      );
                    },
                  ),
                ),
                _Controls(
                  current: _current,
                  count: _pages.length,
                  completing: _completing,
                  nextLabel: isLast
                      ? language.tr(
                          en: 'Get started',
                          ha: 'Fara yanzu',
                          fr: 'Commencer')
                      : language.tr(en: 'Next', ha: 'Na gaba', fr: 'Suivant'),
                  backLabel:
                      language.tr(en: 'Back', ha: 'Koma baya', fr: 'Retour'),
                  onBack: _current == 0 ? null : () => _go(_current - 1),
                  onNext: isLast ? _finish : () => _go(_current + 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.language,
    required this.skipLabel,
    required this.onLanguage,
    required this.onSkip,
  });

  final AppLanguage language;
  final String skipLabel;
  final ValueChanged<AppLanguage> onLanguage;
  final VoidCallback onSkip;

  static const Map<AppLanguage, String> _short = <AppLanguage, String>{
    AppLanguage.english: 'EN',
    AppLanguage.hausa: 'HA',
    AppLanguage.french: 'FR',
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(AppAssets.appIcon),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'FarmSyncHub',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // Language switcher: three tiny pills so the very first screen can
          // already be read in the farmer's own language.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Row(
              children: <Widget>[
                for (final AppLanguage value in AppLanguage.values)
                  Semantics(
                    button: true,
                    selected: value == language,
                    label: value.label,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onLanguage(value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: value == language
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          _short[value]!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: value == language
                                ? const Color(0xFF0B7F4D)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text(skipLabel),
          ),
        ],
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({
    required this.data,
    required this.language,
    required this.active,
  });

  final _Page data;
  final AppLanguage language;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double art = math.min(box.maxHeight * 0.38, 230);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                _Rise(
                  active: active,
                  delay: 0,
                  child: _FloatingArt(data: data, size: art),
                ),
                const SizedBox(height: 18),
                _Rise(
                  active: active,
                  delay: 140,
                  child: _Glass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          data.title.resolve(language),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data.body.resolve(language),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.92),
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (int i = 0; i < data.chips.length; i++)
                              _Rise(
                                active: active,
                                delay: 320 + i * 110,
                                child: _FeatureChip(
                                  chip: data.chips[i],
                                  language: language,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The illustration, bobbing gently inside a frosted circle.
class _FloatingArt extends StatefulWidget {
  const _FloatingArt({required this.data, required this.size});

  final _Page data;
  final double size;

  @override
  State<_FloatingArt> createState() => _FloatingArtState();
}

class _FloatingArtState extends State<_FloatingArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (BuildContext context, Widget? child) => Transform.translate(
        offset: Offset(0, math.sin(_bob.value * math.pi) * -9),
        child: child,
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        padding: EdgeInsets.all(widget.size * 0.1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.16),
          border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: LottieOrIcon(
          asset: widget.data.animation,
          fallbackIcon: widget.data.icon,
          fallbackColor: Colors.white,
          size: widget.size * 0.8,
        ),
      ),
    );
  }
}

/// Fades and lifts its child in, [delay] ms after its page becomes active.
class _Rise extends StatefulWidget {
  const _Rise({
    required this.active,
    required this.delay,
    required this.child,
  });

  final bool active;
  final int delay;
  final Widget child;

  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _play();
    }
  }

  @override
  void didUpdateWidget(_Rise old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _play();
    } else if (!widget.active && old.active) {
      _c.value = 0;
    }
  }

  void _play() {
    _c.value = 0;
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted && widget.active) {
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
            .animate(_a),
        child: widget.child,
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            // Dark enough that white text reads over any photo.
            color: Colors.black.withOpacity(0.48),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.chip, required this.language});

  final _Chip chip;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(chip.icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            chip.label.resolve(language),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.current,
    required this.count,
    required this.completing,
    required this.nextLabel,
    required this.backLabel,
    required this.onBack,
    required this.onNext,
  });

  final int current;
  final int count;
  final bool completing;
  final String nextLabel;
  final String backLabel;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 92,
            child: onBack == null
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: completing ? null : onBack,
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.white),
                    child: Text(backLabel),
                  ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < count; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: i == current ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == current
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
          ),
          FilledButton(
            onPressed: completing ? null : onNext,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0B7F4D),
              minimumSize: const Size(116, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99)),
            ),
            child: Text(
              nextLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class _Page {
  const _Page({
    required this.photo,
    required this.animation,
    required this.icon,
    required this.title,
    required this.body,
    required this.chips,
  });

  final String photo;
  final String animation;
  final IconData icon;
  final LocalizedText title;
  final LocalizedText body;
  final List<_Chip> chips;
}

@immutable
class _Chip {
  const _Chip(this.icon, this.label);

  final IconData icon;
  final LocalizedText label;
}
