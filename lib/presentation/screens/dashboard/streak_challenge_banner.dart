import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/app_preferences_provider.dart';
import '../../../providers/engagement_provider.dart';

/// The Home-screen "Learning Streak Challenge" banner.
///
/// * Everything shown (days done, streak, countdowns) is derived from
///   [engagementProvider], which is stored on the device first - so it is
///   correct offline and matches what the cloud later merges.
/// * Time comes from the provider's ratcheted clock, so winding the phone
///   clock back does not reopen the week or the day.
/// * Joining and claiming go through the provider, which checks the
///   challenge, the goal and "already claimed" itself; the banner can only
///   ask. The reward can be collected once per week.
/// * Only built-in Flutter animation is used (no extra packages/assets).
class StreakChallengeBanner extends ConsumerStatefulWidget {
  const StreakChallengeBanner({super.key});

  @override
  ConsumerState<StreakChallengeBanner> createState() =>
      _StreakChallengeBannerState();
}

class _StreakChallengeBannerState extends ConsumerState<StreakChallengeBanner>
    with TickerProviderStateMixin {
  static const Color _forestDeep = Color(0xFF062A1F);
  static const Color _forest = Color(0xFF0E4D38);
  static const Color _forestLight = Color(0xFF1B7A55);
  static const Color _ember = Color(0xFFFF9600);
  static const Color _gold = Color(0xFFFFC800);
  static const Color _flameRed = Color(0xFFFF5A36);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  final ValueNotifier<DateTime> _clock = ValueNotifier<DateTime>(DateTime.now());
  Timer? _timer;
  String _shownDay = '';
  bool _busy = false;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final DateTime now =
          ref.read(engagementProvider.notifier).trustedNow();
      _clock.value = now;
      // New day or new week: rebuild so the days, goal and button reset.
      if (_shownDay.isNotEmpty && dayKey(now) != _shownDay) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool still = MediaQuery.of(context).disableAnimations;
    if (still == _still && (_pulse.isAnimating || still)) return;
    _still = still;
    if (still) {
      _pulse.stop();
      _drift.stop();
    } else {
      _pulse.repeat(reverse: true);
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.dispose();
    _pulse.dispose();
    _drift.dispose();
    _burst.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    final bool joined =
        await ref.read(engagementProvider.notifier).joinChallenge();
    if (joined && mounted && !_still) _burst.forward(from: 0);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _claim() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.heavyImpact();
    final bool ok = await ref.read(engagementProvider.notifier).claimChallenge();
    if (ok && mounted && !_still) _burst.forward(from: 0);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final EngagementState s = ref.watch(engagementProvider);
    final DateTime now = s.trusted(DateTime.now());
    _shownDay = dayKey(now);
    final StreakChallenge challenge = StreakChallenge.forDate(now);
    final StreakInfo streak = s.streakInfo(now);
    final int done = challenge.daysDone(s);
    final bool joined = s.joinedChallenges.contains(challenge.id);
    final bool claimed = s.claimedChallenges.contains(challenge.id);
    final bool complete = done >= StreakChallenge.goalDays;
    final bool learnedToday = s.isDoneToday(now);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[_forestDeep, _forest, _forestLight],
            stops: <double>[0, 0.55, 1],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _forest.withOpacity(0.45),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: <Widget>[
              // Floating embers behind the content.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _drift,
                    builder: (BuildContext context, Widget? child) =>
                        CustomPaint(painter: _EmberPainter(_drift.value)),
                  ),
                ),
              ),
              // Soft glow behind the flame.
              Positioned(
                top: -50,
                right: -40,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (BuildContext context, Widget? child) => Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: <Color>[
                          _ember.withOpacity(0.30 + 0.18 * _pulse.value),
                          _ember.withOpacity(0),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _header(language, streak, now),
                    const SizedBox(height: 18),
                    _weekRow(s, challenge, now),
                    const SizedBox(height: 16),
                    _progressBar(done, complete),
                    const SizedBox(height: 16),
                    _countdownRow(language, challenge, streak, learnedToday),
                    const SizedBox(height: 16),
                    _cta(language, joined, claimed, complete, learnedToday),
                    const SizedBox(height: 12),
                    _trustLine(language),
                  ],
                ),
              ),
              // One-shot celebration when joining or claiming.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _burst,
                    builder: (BuildContext context, Widget? child) =>
                        CustomPaint(painter: _BurstPainter(_burst.value)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Sections
  // -------------------------------------------------------------------------

  Widget _header(AppLanguage language, StreakInfo streak, DateTime now) {
    final String title = language.tr(
      en: 'Learning Streak Challenge',
      ha: 'Gasar Karatu Kullum',
      fr: "Défi d'apprentissage",
    );
    final String subtitle = language.tr(
      en: 'Learn on ${StreakChallenge.goalDays} of 7 days this week',
      ha: 'Yi karatu kwana ${StreakChallenge.goalDays} cikin 7 a wannan mako',
      fr: 'Apprenez ${StreakChallenge.goalDays} jours sur 7 cette semaine',
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  language
                      .tr(en: 'WEEKLY CHALLENGE', ha: 'GASAR MAKO', fr: 'DÉFI HEBDO'),
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _flameBadge(streak),
      ],
    );
  }

  Widget _flameBadge(StreakInfo streak) {
    final bool lit = streak.status == StreakStatus.doneToday ||
        streak.status == StreakStatus.alive;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedBuilder(
          animation: _pulse,
          builder: (BuildContext context, Widget? child) {
            final double scale = lit ? 1 + 0.06 * _pulse.value : 1;
            return Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 54,
                height: 66,
                child: CustomPaint(
                  painter: _FlamePainter(
                    flicker: _pulse.value,
                    lit: lit,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: streak.count),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, int value, Widget? child) => Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        Text(
          ref.read(appLanguageProvider).tr(en: 'day streak', ha: 'kwanaki', fr: 'jours'),
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _weekRow(EngagementState s, StreakChallenge challenge, DateTime now) {
    const List<String> letters = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final DateTime today = dateOnly(now);
    final List<DateTime> days = challenge.days;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        for (int i = 0; i < 7; i++)
          _DayDot(
            letter: letters[i],
            delay: i * 70,
            done: s.hasActivityOn(days[i]),
            frozen: s.isFrozenDay(days[i]) && !s.hasActivityOn(days[i]),
            isToday: days[i] == today,
            isFuture: days[i].isAfter(today),
            pulse: _pulse,
          ),
      ],
    );
  }

  Widget _progressBar(int done, bool complete) {
    final double target =
        (done / StreakChallenge.goalDays).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '$done / ${StreakChallenge.goalDays}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Icon(
              complete ? Icons.emoji_events_rounded : Icons.flag_rounded,
              size: 16,
              color: complete ? _gold : Colors.white54,
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: target),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double value, Widget? child) {
            return Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: value <= 0 ? 0.0 : math.max(value, 0.06),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: const LinearGradient(
                        colors: <Color>[_gold, _ember, _flameRed],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: _ember.withOpacity(0.55),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _countdownRow(AppLanguage language, StreakChallenge challenge,
      StreakInfo streak, bool learnedToday) {
    final bool atRisk = !learnedToday &&
        (streak.status == StreakStatus.alive ||
            streak.status == StreakStatus.frozen) &&
        streak.count > 0;
    return ValueListenableBuilder<DateTime>(
      valueListenable: _clock,
      builder: (BuildContext context, DateTime raw, Widget? child) {
        // `raw` only triggers the once-a-second rebuild; the time itself
        // always goes through the ratcheted clock.
        final DateTime now =
            ref.read(engagementProvider).trusted(DateTime.now());
        final Duration weekLeft = challenge.remaining(now);
        final Duration dayLeft =
            addDays(dateOnly(now), 1).difference(now);
        final bool urgent = atRisk && dayLeft.inHours < 3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.timer_outlined,
                    size: 15, color: Colors.white.withOpacity(0.75)),
                const SizedBox(width: 6),
                Text(
                  language.tr(
                      en: 'Challenge ends in',
                      ha: 'Gasar ta ƙare nan da',
                      fr: 'Le défi se termine dans'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _timeBoxes(language, weekLeft),
            if (atRisk) ...<Widget>[
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: (urgent ? _flameRed : _ember).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (urgent ? _flameRed : _ember).withOpacity(0.55),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (BuildContext context, Widget? child) =>
                          Transform.scale(
                        scale: 1 + (urgent ? 0.25 : 0.12) * _pulse.value,
                        child: Icon(Icons.local_fire_department_rounded,
                            size: 18, color: urgent ? _flameRed : _gold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        language.tr(
                          en: 'Keep your ${streak.count}-day streak alive: ${_hms(dayLeft)} left today',
                          ha: 'Ci gaba da kwanaki ${streak.count}: saura ${_hms(dayLeft)} a yau',
                          fr: 'Sauvez votre série de ${streak.count} jours : ${_hms(dayLeft)} restantes',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _timeBoxes(AppLanguage language, Duration left) {
    final int d = left.inDays;
    final int h = left.inHours % 24;
    final int m = left.inMinutes % 60;
    final int sec = left.inSeconds % 60;
    return Row(
      children: <Widget>[
        if (d > 0) ...<Widget>[
          _TimeBox(value: d, label: language.tr(en: 'days', ha: 'kwana', fr: 'j')),
          const _Colon(),
        ],
        _TimeBox(value: h, label: language.tr(en: 'hrs', ha: 'awa', fr: 'h')),
        const _Colon(),
        _TimeBox(value: m, label: language.tr(en: 'min', ha: 'min', fr: 'min')),
        const _Colon(),
        _TimeBox(value: sec, label: language.tr(en: 'sec', ha: 'dak', fr: 's')),
      ],
    );
  }

  Widget _cta(AppLanguage language, bool joined, bool claimed, bool complete,
      bool learnedToday) {
    late final String label;
    late final IconData icon;
    VoidCallback? onTap;
    bool gold = false;
    if (!joined) {
      label = language.tr(
          en: 'Join the challenge', ha: 'Shiga gasar', fr: 'Rejoindre le défi');
      icon = Icons.rocket_launch_rounded;
      onTap = _join;
    } else if (complete && !claimed) {
      label = language.tr(
        en: 'Claim +${StreakChallenge.rewardXp} XP  •  +${StreakChallenge.rewardGems} gems',
        ha: 'Karɓi +${StreakChallenge.rewardXp} XP  •  +${StreakChallenge.rewardGems}',
        fr: 'Récupérer +${StreakChallenge.rewardXp} XP  •  +${StreakChallenge.rewardGems}',
      );
      icon = Icons.card_giftcard_rounded;
      onTap = _claim;
      gold = true;
    } else if (claimed) {
      label = language.tr(
          en: 'Reward collected - see you next week',
          ha: 'An karɓi kyauta - sai mako mai zuwa',
          fr: 'Récompense reçue - à la semaine prochaine');
      icon = Icons.verified_rounded;
      onTap = null;
    } else if (!learnedToday) {
      label = language.tr(
          en: 'Learn today', ha: 'Yi karatu yau', fr: "Apprendre aujourd'hui");
      icon = Icons.play_arrow_rounded;
      onTap = () => context.go('/learn');
    } else {
      label = language.tr(
          en: "Today's lesson done - keep going",
          ha: 'An yi karatun yau - ci gaba',
          fr: "Leçon du jour faite - continuez");
      icon = Icons.menu_book_rounded;
      onTap = () => context.go('/learn');
    }

    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? child) {
        final bool glow = onTap != null && (gold || !joined);
        return Opacity(
          opacity: _busy ? 0.7 : 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: glow
                  ? <BoxShadow>[
                      BoxShadow(
                        color: (gold ? _gold : _ember)
                            .withOpacity(0.25 + 0.30 * _pulse.value),
                        blurRadius: 12 + 10 * _pulse.value,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: onTap == null
                      ? LinearGradient(colors: <Color>[
                          Colors.white.withOpacity(0.16),
                          Colors.white.withOpacity(0.10),
                        ])
                      : LinearGradient(
                          colors: gold
                              ? const <Color>[Color(0xFFFFE27A), _gold, _ember]
                              : const <Color>[_gold, _ember],
                        ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(icon,
                            size: 20,
                            color: onTap == null
                                ? Colors.white70
                                : const Color(0xFF3A1F00)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              label,
                              key: ValueKey<String>(label),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: onTap == null
                                    ? Colors.white70
                                    : const Color(0xFF3A1F00),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _trustLine(AppLanguage language) {
    return Row(
      children: <Widget>[
        Icon(Icons.verified_user_rounded,
            size: 13, color: Colors.white.withOpacity(0.6)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            language.tr(
              en: 'Counted from your saved learning days. Works offline and syncs when you are back online.',
              ha: 'Ana ƙirga daga kwanakin karatunka da aka adana. Yana aiki ba intanet.',
              fr: 'Compté à partir de vos jours d\'étude enregistrés. Fonctionne hors ligne.',
            ),
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  static String _hms(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
}

// ---------------------------------------------------------------------------
// Small widgets
// ---------------------------------------------------------------------------

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.letter,
    required this.delay,
    required this.done,
    required this.frozen,
    required this.isToday,
    required this.isFuture,
    required this.pulse,
  });

  final String letter;
  final int delay;
  final bool done;
  final bool frozen;
  final bool isToday;
  final bool isFuture;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    const Color gold = Color(0xFFFFC800);
    const Color ember = Color(0xFFFF9600);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double t, Widget? child) =>
          Transform.scale(scale: t.clamp(0.0, 1.15).toDouble(), child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            letter,
            style: TextStyle(
              color: isToday ? gold : Colors.white.withOpacity(0.65),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: pulse,
            builder: (BuildContext context, Widget? child) {
              final double ring = isToday && !done ? pulse.value : 0;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: done
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[gold, ember],
                        )
                      : null,
                  color: done
                      ? null
                      : frozen
                          ? const Color(0xFF49C0F8).withOpacity(0.25)
                          : Colors.white.withOpacity(isFuture ? 0.06 : 0.12),
                  border: Border.all(
                    color: isToday && !done
                        ? gold.withOpacity(0.55 + 0.45 * ring)
                        : Colors.white.withOpacity(done ? 0 : 0.14),
                    width: isToday && !done ? 2 : 1,
                  ),
                  boxShadow: done
                      ? <BoxShadow>[
                          BoxShadow(
                              color: ember.withOpacity(0.5), blurRadius: 10),
                        ]
                      : isToday
                          ? <BoxShadow>[
                              BoxShadow(
                                color: gold.withOpacity(0.35 * ring),
                                blurRadius: 4 + 10 * ring,
                                spreadRadius: 1 + 2 * ring,
                              ),
                            ]
                          : const <BoxShadow>[],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget c, Animation<double> a) =>
                        ScaleTransition(scale: a, child: c),
                    child: done
                        ? const Icon(Icons.check_rounded,
                            key: ValueKey<String>('done'),
                            size: 20,
                            color: Color(0xFF3A1F00))
                        : frozen
                            ? const Icon(Icons.ac_unit_rounded,
                                key: ValueKey<String>('frozen'),
                                size: 17,
                                color: Color(0xFF49C0F8))
                            : const SizedBox.shrink(
                                key: ValueKey<String>('empty')),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final String text = value.toString().padLeft(2, '0');
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (Widget child, Animation<double> anim) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.35),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              );
            },
            child: Text(
              text,
              key: ValueKey<String>('$label$text'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Colon extends StatelessWidget {
  const _Colon();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Text(
          ':',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.flicker, required this.lit});

  final double flicker;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double sway = (flicker - 0.5) * 0.10 * w;

    Path flame(double scale, double dx) {
      final double cx = w * 0.5 + dx;
      final double top = h * (1 - scale);
      final double half = w * 0.46 * scale;
      return Path()
        ..moveTo(cx + sway * scale, top)
        ..cubicTo(cx + half * 1.15, top + (h - top) * 0.40, cx + half,
            top + (h - top) * 0.82, cx, h)
        ..cubicTo(cx - half, top + (h - top) * 0.82, cx - half * 1.15,
            top + (h - top) * 0.42, cx + sway * scale, top)
        ..close();
    }

    final Rect rect = Offset.zero & size;
    if (!lit) {
      final Paint grey = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFB8C2BC), Color(0xFF6E7B74)],
        ).createShader(rect);
      canvas.drawPath(flame(0.92, 0), grey);
      return;
    }
    canvas.drawPath(
      flame(1, 0),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFFFC800), Color(0xFFFF9600), Color(0xFFFF4B2B)],
        ).createShader(rect),
    );
    canvas.drawPath(
      flame(0.62, -sway * 0.3),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFFFF3B0), Color(0xFFFFC800)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _FlamePainter old) =>
      old.flicker != flicker || old.lit != lit;
}

/// Slowly rising embers. Deterministic: positions come from the index, so
/// there is no randomness to allocate per frame.
class _EmberPainter extends CustomPainter {
  _EmberPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const int count = 14;
    final Paint paint = Paint();
    for (int i = 0; i < count; i++) {
      final double phase = i / count;
      final double life = (t + phase) % 1.0;
      final double x = size.width * (0.08 + 0.84 * ((i * 0.37) % 1.0)) +
          math.sin((t + phase) * math.pi * 2) * 6;
      final double y = size.height * (1.02 - life * 1.0);
      final double fade = math.sin(life * math.pi);
      final double r = 1.2 + (i % 3) * 0.9;
      paint.color = Color.lerp(
        const Color(0xFFFFC800),
        const Color(0xFFFF7A00),
        life,
      )!
          .withOpacity(0.55 * fade);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberPainter old) => old.t != t;
}

/// One-shot radial sparkle used when joining or claiming.
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final Offset c = Offset(size.width * 0.5, size.height * 0.82);
    final double eased = Curves.easeOutCubic.transform(t);
    final Paint paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    const int rays = 18;
    for (int i = 0; i < rays; i++) {
      final double a = (i / rays) * math.pi * 2;
      final double inner = 10 + eased * 70;
      final double outer = inner + 16 * (1 - t);
      paint.color = (i.isEven ? const Color(0xFFFFC800) : const Color(0xFFFF9600))
          .withOpacity((1 - t).clamp(0.0, 1.0).toDouble());
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * inner,
        c + Offset(math.cos(a), math.sin(a)) * outer,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}
