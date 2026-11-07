import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../screens/learn/engagement_widgets.dart' show LottieOrIcon;
import '../wizard/wizard_models.dart' show LocalizedText;

/// Registry of on-screen widgets a tour step can point at.
///
/// A screen wraps a widget in `KeyedSubtree(key: TourTargets.keyFor('id'))`;
/// a [TourStep] with the same `targetId` then spotlights it. Each id must be
/// attached to one widget at a time.
abstract final class TourTargets {
  static final Map<String, GlobalKey> _keys = <String, GlobalKey>{};

  /// The key to attach to the widget called [id].
  static GlobalKey keyFor(String id) =>
      _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'tour:$id'));

  /// The widget's on-screen rectangle, or null when it is not on screen.
  static Rect? rectOf(String id) {
    final BuildContext? context = _keys[id]?.currentContext;
    final RenderObject? box = context?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// One stop of the tour.
@immutable
class TourStep {
  /// Creates a step. Without a [targetId] the step is a centred message.
  const TourStep({
    required this.title,
    required this.body,
    required this.icon,
    this.targetId,
    this.celebrate = false,
  });

  /// Short heading.
  final LocalizedText title;

  /// One or two friendly sentences.
  final LocalizedText body;

  /// Icon shown on the card.
  final IconData icon;

  /// Which [TourTargets] widget to spotlight, if any.
  final String? targetId;

  /// Shows a confetti burst (used on the last step).
  final bool celebrate;
}

/// The tour shown on the dashboard after a person's first sign-in.
abstract final class AppTourSteps {
  /// Steps for the dashboard (with the bottom bar visible).
  static const List<TourStep> dashboard = <TourStep>[
    TourStep(
      icon: Icons.waving_hand_rounded,
      title: LocalizedText(
        'Welcome to FarmSyncHub!',
        ha: 'Barka da zuwa FarmSyncHub!',
        fr: 'Bienvenue sur FarmSyncHub !',
      ),
      body: LocalizedText(
        'Take a one-minute tour of the places you will use every day. You can skip any time.',
        ha: 'Yi yawon minti ɗaya na wuraren da za ka yi amfani da su kowace rana. Za ka iya tsallakewa a kowane lokaci.',
        fr: 'Faites un tour d’une minute des endroits que vous utiliserez chaque jour. Vous pouvez passer à tout moment.',
      ),
    ),
    TourStep(
      targetId: 'dash_hero',
      icon: Icons.home_rounded,
      title: LocalizedText(
        'Your farm at a glance',
        ha: 'Gonarka a kallo ɗaya',
        fr: 'Votre ferme en un coup d’œil',
      ),
      body: LocalizedText(
        'This is your home screen. It greets you and shows the farm you are working on.',
        ha: 'Wannan ita ce allon gidanka. Yana gaishe ka kuma yana nuna gonar da kake aiki a kai.',
        fr: 'Voici votre écran d’accueil. Il vous salue et montre la ferme sur laquelle vous travaillez.',
      ),
    ),
    TourStep(
      targetId: 'dash_tasks',
      icon: Icons.checklist_rounded,
      title: LocalizedText(
        'Today’s tasks',
        ha: 'Ayyukan yau',
        fr: 'Tâches du jour',
      ),
      body: LocalizedText(
        'Planting, feeding, vaccines and more show up here when they are due, so nothing is forgotten.',
        ha: 'Shuka, ciyarwa, alluran rigakafi da sauransu suna bayyana a nan idan lokacinsu ya yi, don kada a manta da komai.',
        fr: 'Plantation, alimentation, vaccins et plus apparaissent ici à l’échéance, pour ne rien oublier.',
      ),
    ),
    TourStep(
      targetId: 'dash_news',
      icon: Icons.newspaper_rounded,
      title: LocalizedText(
        'Latest farm news',
        ha: 'Sabbin labaran noma',
        fr: 'Dernières nouvelles agricoles',
      ),
      body: LocalizedText(
        'Swipe through the newest updates from the community. Tap a card to read more.',
        ha: 'Zazzaga ka duba sabbin labarai daga al’umma. Danna kati don karanta ƙari.',
        fr: 'Faites défiler les dernières nouvelles de la communauté. Touchez une carte pour en savoir plus.',
      ),
    ),
    TourStep(
      targetId: 'dash_ai',
      icon: Icons.auto_awesome_rounded,
      title: LocalizedText(
        'Ask the AI advisor',
        ha: 'Tambayi mai ba da shawara na AI',
        fr: 'Demandez au conseiller IA',
      ),
      body: LocalizedText(
        'Stuck on a crop or animal problem? Ask a question in your own language and get practical advice.',
        ha: 'Kana da matsala game da amfanin gona ko dabba? Yi tambaya da harshenka ka samu shawara mai amfani.',
        fr: 'Un souci avec une culture ou un animal ? Posez votre question dans votre langue et recevez des conseils pratiques.',
      ),
    ),
    TourStep(
      targetId: 'nav_bar',
      icon: Icons.swipe_rounded,
      title: LocalizedText(
        'Seven tabs, one swipe away',
        ha: 'Shafuka bakwai, zazzagawa ɗaya',
        fr: 'Sept onglets, à un glissement',
      ),
      body: LocalizedText(
        'Home, Farms, Crops, Livestock, Finance, News and Profile. Slide the bar sideways to see them all.',
        ha: 'Gida, Gonaki, Amfanin gona, Dabbobi, Kuɗi, Labarai da Bayanan martaba. Zazzaga mashayar zuwa gefe don ganin su duka.',
        fr: 'Accueil, Fermes, Cultures, Élevage, Finances, Actualités et Profil. Faites glisser la barre pour tout voir.',
      ),
    ),
    TourStep(
      icon: Icons.celebration_rounded,
      celebrate: true,
      title: LocalizedText(
        'You are ready to farm smarter!',
        ha: 'Ka shirya don yin noma cikin hikima!',
        fr: 'Vous êtes prêt à cultiver plus malin !',
      ),
      body: LocalizedText(
        'Start by opening the Farms tab and adding your first farm. We will guide you step by step.',
        ha: 'Fara da buɗe shafin Gonaki ka ƙara gonarka ta farko. Za mu jagorance ka mataki-mataki.',
        fr: 'Commencez par ouvrir l’onglet Fermes et ajoutez votre première ferme. Nous vous guiderons pas à pas.',
      ),
    ),
  ];
}

/// Dims the screen, spotlights real widgets one at a time and explains each.
abstract final class AppSpotlightTour {
  /// Shows the tour on top of everything (including the bottom bar).
  static void show(
    BuildContext context, {
    required AppLanguage language,
    List<TourStep> steps = AppTourSteps.dashboard,
    VoidCallback? onFinished,
  }) {
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext context) => _TourOverlay(
        steps: steps,
        language: language,
        onClose: () {
          entry.remove();
          onFinished?.call();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _TourOverlay extends StatefulWidget {
  const _TourOverlay({
    required this.steps,
    required this.language,
    required this.onClose,
  });

  final List<TourStep> steps;
  final AppLanguage language;
  final VoidCallback onClose;

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  int _index = 0;
  Rect? _target;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusStep());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  TourStep get _step => widget.steps[_index];
  bool get _isLast => _index == widget.steps.length - 1;

  /// Scrolls the target into view (if it sits in a list), then measures it.
  Future<void> _focusStep() async {
    final String? id = _step.targetId;
    if (id == null) {
      if (mounted) {
        setState(() => _target = null);
      }
      return;
    }

    final BuildContext? targetContext = TourTargets.keyFor(id).currentContext;
    if (targetContext != null && Scrollable.maybeOf(targetContext) != null) {
      try {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.3,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
        );
      } catch (_) {
        // Measuring below still works if scrolling is not possible.
      }
    }
    if (!mounted) {
      return;
    }
    // Wait a frame so the measurement happens after any scrolling settled.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    setState(() => _target = TourTargets.rectOf(id));
  }

  void _go(int next) {
    if (next < 0 || next >= widget.steps.length) {
      return;
    }
    setState(() {
      _index = next;
      _target = null;
    });
    _focusStep();
  }

  void _close() {
    if (_closing) {
      return;
    }
    _closing = true;
    widget.onClose();
  }

  String _t(LocalizedText text) => text.resolve(widget.language);

  String _label({required String en, required String ha, required String fr}) =>
      widget.language.tr(en: en, ha: ha, fr: fr);

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Rect? target = _target;
    final Rect hole = target ??
        Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0);
    final bool hasHole = target != null;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          // Swallow taps so the app underneath cannot be used mid-tour.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: hole),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeInOutCubic,
                builder: (BuildContext context, Rect? animated, Widget? _) {
                  return AnimatedBuilder(
                    animation: _pulse,
                    builder: (BuildContext context, Widget? _) => CustomPaint(
                      painter: _SpotlightPainter(
                        hole: animated ?? hole,
                        pulse: _pulse.value,
                        ringColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _positionedCard(context, size, safe, target, hasHole),
        ],
      ),
    );
  }

  Widget _positionedCard(
    BuildContext context,
    Size size,
    EdgeInsets safe,
    Rect? target,
    bool hasHole,
  ) {
    final Widget card = AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _TourCard(
        key: ValueKey<int>(_index),
        step: _step,
        language: widget.language,
        index: _index,
        count: widget.steps.length,
        onNext: _isLast ? _close : () => _go(_index + 1),
        onBack: _index == 0 ? null : () => _go(_index - 1),
        onSkip: _close,
        nextLabel: _isLast
            ? _label(en: 'Let’s go', ha: 'Mu tafi', fr: 'C’est parti')
            : _label(en: 'Next', ha: 'Na gaba', fr: 'Suivant'),
        backLabel: _label(en: 'Back', ha: 'Koma baya', fr: 'Retour'),
        skipLabel: _label(en: 'Skip tour', ha: 'Tsallake', fr: 'Passer'),
        title: _t(_step.title),
        body: _t(_step.body),
        stepLabel: _label(
          en: 'Step ${_index + 1} of ${widget.steps.length}',
          ha: 'Mataki ${_index + 1} cikin ${widget.steps.length}',
          fr: 'Étape ${_index + 1} sur ${widget.steps.length}',
        ),
      ),
    );

    const double margin = 20;
    if (!hasHole || target == null) {
      return Positioned(
        left: margin,
        right: margin,
        top: 0,
        bottom: 0,
        child: Center(child: SingleChildScrollView(child: card)),
      );
    }

    // Put the card on whichever side of the spotlight has more room.
    final bool placeAbove = target.center.dy > size.height * 0.55;
    if (placeAbove) {
      return Positioned(
        left: margin,
        right: margin,
        bottom: math.max(safe.bottom, size.height - target.top + 18),
        child: card,
      );
    }
    return Positioned(
      left: margin,
      right: margin,
      top: math.max(safe.top + 8, target.bottom + 18),
      child: card,
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.hole,
    required this.pulse,
    required this.ringColor,
  });

  final Rect hole;
  final double pulse;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    Path dim = Path()..addRect(Offset.zero & size);
    final bool hasHole = hole.width > 1 && hole.height > 1;
    RRect? rounded;
    if (hasHole) {
      rounded = RRect.fromRectAndRadius(
        hole.inflate(8),
        const Radius.circular(18),
      );
      dim = Path.combine(PathOperation.difference, dim, Path()..addRRect(rounded));
    }
    canvas.drawPath(dim, Paint()..color = Colors.black.withOpacity(0.78));

    if (rounded != null) {
      canvas.drawRRect(
        rounded.inflate(2 + pulse * 5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white.withOpacity(0.85 - pulse * 0.5),
      );
      canvas.drawRRect(
        rounded,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ringColor.withOpacity(0.95),
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.pulse != pulse || old.ringColor != ringColor;
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    super.key,
    required this.step,
    required this.language,
    required this.index,
    required this.count,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.nextLabel,
    required this.backLabel,
    required this.skipLabel,
    required this.title,
    required this.body,
    required this.stepLabel,
  });

  final TourStep step;
  final AppLanguage language;
  final int index;
  final int count;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;
  final String nextLabel;
  final String backLabel;
  final String skipLabel;
  final String title;
  final String body;
  final String stepLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (step.celebrate)
            Center(
              child: LottieOrIcon(
                asset: AppAssets.confettiAnimation,
                fallbackIcon: step.icon,
                fallbackColor: scheme.primary,
                size: 110,
                repeat: false,
              ),
            )
          else
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(step.icon, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stepLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              for (int i = 0; i < count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  width: i == index ? 22 : 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: i == index ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              TextButton(onPressed: onSkip, child: Text(skipLabel)),
              const Spacer(),
              if (onBack != null)
                TextButton(onPressed: onBack, child: Text(backLabel)),
              const SizedBox(width: 6),
              FilledButton(onPressed: onNext, child: Text(nextLabel)),
            ],
          ),
        ],
      ),
    );
  }
}
