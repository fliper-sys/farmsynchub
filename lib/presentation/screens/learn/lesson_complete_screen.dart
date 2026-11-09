import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_preferences_provider.dart';
import '../../../providers/engagement_provider.dart';
import '../../../providers/learning_provider.dart';
import 'achievement_celebration.dart';
import 'engagement_widgets.dart';
import 'lesson_certificate_screen.dart';

/// Shown right after the last question of a lesson, like Duolingo's
/// "Lesson complete" screen: XP earned, accuracy, streak, then Continue.
///
/// Hook it up like this from your lesson screen:
///
/// ```dart
/// Navigator.of(context).pushReplacement(fluidRoute(LessonCompleteScreen(
///   lessonId: lesson.id,
///   lessonTitle: lesson.title,
///   correctAnswers: correct,
///   totalQuestions: total,
///   nextLessonTitle: next?.title,
///   onNextLesson: next == null
///       ? null
///       : () => Navigator.of(context)
///           .pushReplacement(fluidRoute(LessonScreen(lesson: next))),
/// )));
/// ```
class LessonCompleteScreen extends ConsumerStatefulWidget {
  const LessonCompleteScreen({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.correctAnswers,
    required this.totalQuestions,
    this.nextLessonTitle,
    this.onNextLesson,
  });

  final String lessonId;
  final String lessonTitle;
  final int correctAnswers;
  final int totalQuestions;

  /// Title of the lesson that follows, if there is one.
  final String? nextLessonTitle;

  /// Opens the next lesson. When null, Continue just closes this screen.
  final VoidCallback? onNextLesson;

  @override
  ConsumerState<LessonCompleteScreen> createState() =>
      _LessonCompleteScreenState();
}

class _LessonCompleteScreenState extends ConsumerState<LessonCompleteScreen> {
  LessonReward? _reward;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _record());
  }

  Future<void> _record() async {
    // Certificate, XP, streak and achievements are all paid out by the
    // learning provider, which hands the engagement record the result.
    final LessonReward reward =
        await ref.read(learningProvider.notifier).completeLesson(
              widget.lessonId,
              lessonTitle: widget.lessonTitle,
              correctAnswers: widget.correctAnswers,
              totalQuestions: widget.totalQuestions,
              requiredQuestions: widget.totalQuestions,
            );
    if (!mounted) return;
    setState(() => _reward = reward);

    if (reward.newAchievements.isNotEmpty) {
      // Let the XP count-up play before the pop-ups start.
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      if (!mounted) return;
      await showAchievementCelebrations(context, reward.newAchievements);
    }
  }

  void _continue() {
    if (widget.onNextLesson != null) {
      widget.onNextLesson!();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _openCertificate() {
    final CertificateRecord? record =
        ref.read(learningProvider).certificateForLesson(widget.lessonId);
    if (record == null) return;
    Navigator.of(context)
        .push(fluidRoute<void>(LessonCertificateScreen(record: record)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final LessonReward? reward = _reward;
    final int accuracy = widget.totalQuestions == 0
        ? 100
        : ((widget.correctAnswers / widget.totalQuestions) * 100).round();
    final int totalXp = reward == null ? 0 : reward.xpEarned + reward.bonusXp;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 12),
                child: Column(
                  children: <Widget>[
                    LottieOrIcon(
                      asset: LottieAssets.trophy,
                      fallbackIcon: Icons.emoji_events_rounded,
                      fallbackColor: EngagementColors.gold,
                      size: 170,
                      repeat: false,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      language.tr(
                          en: 'Lesson complete!',
                          ha: 'An kammala darasi!',
                          fr: 'Leçon terminée !'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: EngagementColors.gold,
                          fontSize: 28,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.lessonTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: EngagementColors.grayText,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 22),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _ResultTile(
                            color: EngagementColors.gold,
                            title: language.tr(
                                en: 'TOTAL XP', ha: 'JIMILLAR XP', fr: 'XP TOTAL'),
                            icon: Icons.bolt_rounded,
                            child: TweenAnimationBuilder<int>(
                              tween: IntTween(begin: 0, end: totalXp),
                              duration: const Duration(milliseconds: 1100),
                              curve: Curves.easeOutCubic,
                              builder: (_, int v, __) => Text('$v',
                                  style: const TextStyle(
                                      color: EngagementColors.gold,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ResultTile(
                            color: EngagementColors.green,
                            title: language.tr(
                                en: 'AMAZING', ha: 'MAI KYAU', fr: 'GÉNIAL'),
                            icon: Icons.track_changes_rounded,
                            child: Text('$accuracy%',
                                style: const TextStyle(
                                    color: EngagementColors.green,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                    if (reward != null && reward.bonusXp > 0) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        language.tr(
                            en: '+${reward.xpEarned} lesson XP  •  +${reward.bonusXp} award bonus',
                            ha: '+${reward.xpEarned} XP na darasi  •  +${reward.bonusXp} kyautar lambar yabo',
                            fr: '+${reward.xpEarned} XP de leçon  •  +${reward.bonusXp} bonus de récompense', pcm: '+${reward.xpEarned} lesson XP  •  +${reward.bonusXp} award bonus'),
                        style: const TextStyle(
                            color: EngagementColors.grayText,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (reward != null && !reward.firstTime) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        language.tr(
                            en: 'Replaying a lesson earns less XP.',
                            ha: 'Maimaita darasi yana ba da ƙarancin XP.',
                            fr: 'Rejouer une leçon rapporte moins d’XP.'),
                        style: const TextStyle(
                            color: EngagementColors.grayText, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 26),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: reward == null
                          ? const SizedBox(height: 120)
                          : _StreakPanel(reward: reward, language: language),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
              child: Column(
                children: <Widget>[
                  if (widget.nextLessonTitle != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        language.tr(
                            en: 'Up next: ${widget.nextLessonTitle}',
                            ha: 'Na gaba: ${widget.nextLessonTitle}',
                            fr: 'À suivre : ${widget.nextLessonTitle}', pcm: 'Next one: ${widget.nextLessonTitle}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: EngagementColors.grayText,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: EngagementColors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: reward == null ? null : _continue,
                      child: Text(
                        (widget.onNextLesson != null
                                ? language.tr(
                                    en: 'NEXT LESSON',
                                    ha: 'DARASI NA GABA',
                                    fr: 'LEÇON SUIVANTE')
                                : language.tr(
                                    en: 'CONTINUE',
                                    ha: 'CI GABA',
                                    fr: 'CONTINUER')),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: reward == null ? null : _openCertificate,
                    child: Text(language.tr(
                        en: 'View certificate',
                        ha: 'Duba takardar shaida',
                        fr: 'Voir le certificat')),
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

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.color,
    required this.title,
    required this.icon,
    required this.child,
  });

  final Color color;
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(2),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.8)),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, color: color, size: 26),
                const SizedBox(width: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakPanel extends StatelessWidget {
  const _StreakPanel({required this.reward, required this.language});

  final LessonReward reward;
  final AppLanguage language;

  String _message() {
    if (reward.restored) {
      return language.tr(
          en: 'Fire restored! ${reward.restorationsLeft} of ${EngagementState.maxRestorations} restorations left.',
          ha: 'An dawo da wuta! Saura dawowa ${reward.restorationsLeft} cikin ${EngagementState.maxRestorations}.',
          fr: 'Flamme rallumée ! Il reste ${reward.restorationsLeft} restauration(s) sur ${EngagementState.maxRestorations}.', pcm: 'Fire don come back! ${reward.restorationsLeft} of ${EngagementState.maxRestorations} restorations remain.');
    }
    if (reward.streakReset) {
      return language.tr(
          en: 'Your ${reward.lostStreak}-day streak ended. A fresh start - you have all ${EngagementState.maxRestorations} restorations again.',
          ha: 'Jerin kwanaki ${reward.lostStreak} ya ƙare. Sabon farawa - kana da dawowa ${EngagementState.maxRestorations} kuma.',
          fr: 'Votre série de ${reward.lostStreak} jours est terminée. Nouveau départ - vous avez de nouveau ${EngagementState.maxRestorations} restaurations.', pcm: 'Your ${reward.lostStreak}-day streak don end. Fresh start - you get all ${EngagementState.maxRestorations} restorations again.');
    }
    if (reward.freezesUsed > 0) {
      return language.tr(
          en: 'A streak freeze protected your streak while you were away.',
          ha: 'Daskarewar jere ta kare jerinka lokacin da ba ka nan.',
          fr: 'Un gel de série a protégé votre série pendant votre absence.');
    }
    return reward.streakExtended
        ? language.tr(
            en: 'Streak extended - keep it going!',
            ha: 'An ƙara jerin kwanaki - ci gaba!',
            fr: 'Série prolongée - continuez !')
        : language.tr(
            en: 'Already counted today. See you tomorrow!',
            ha: 'An riga an ƙirga yau. Sai gobe!',
            fr: 'Déjà compté aujourd’hui. À demain !');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<int>(reward.streakAfter),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: EngagementColors.gray, width: 2),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              LottieOrIcon(
                asset: LottieAssets.streakFire,
                fallbackIcon: Icons.local_fire_department_rounded,
                fallbackColor: EngagementColors.fire,
                size: 64,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TweenAnimationBuilder<int>(
                      tween: IntTween(
                          begin: reward.streakBefore, end: reward.streakAfter),
                      duration: const Duration(milliseconds: 900),
                      builder: (_, int v, __) => Text(
                        language.tr(
                            en: '$v day streak',
                            ha: 'Kwanaki $v a jere',
                            fr: 'Série de $v jours', pcm: '$v day streak'),
                        style: const TextStyle(
                            color: EngagementColors.fire,
                            fontSize: 22,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      _message(),
                      style: const TextStyle(
                          color: EngagementColors.grayText,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const WeekStrip(),
        ],
      ),
    );
  }
}
