import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/learning_provider.dart';
import 'engagement_widgets.dart';
import 'learn_screen.dart';
import 'lesson_complete_screen.dart';

enum _Kind { intro, step, question, finish }

class _Card {
  const _Card(this.kind, {this.step, this.stepNumber = 0, this.question});

  final _Kind kind;
  final String? step;
  final int stepNumber;
  final LessonQuestion? question;
}

enum _Result { none, correct, wrong, skipped }

/// A lesson as a journey of cards: intro -> one idea per card -> one
/// question per card -> finish. Questions must be answered to move on (or
/// skipped, which earns nothing). Streak and XP are only paid when every
/// question was answered.
class LessonFlowScreen extends ConsumerStatefulWidget {
  const LessonFlowScreen({super.key, required this.lesson});

  final LearningLesson lesson;

  @override
  ConsumerState<LessonFlowScreen> createState() => _LessonFlowScreenState();
}

class _LessonFlowScreenState extends ConsumerState<LessonFlowScreen> {
  final PageController _pages = PageController();
  late final List<_Card> _cards;
  final Map<String, _Result> _results = <String, _Result>{};
  final Map<String, int> _picked = <String, int>{};
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final LearningLesson l = widget.lesson;
    _cards = <_Card>[
      const _Card(_Kind.intro),
      for (int i = 0; i < l.steps.length; i++)
        _Card(_Kind.step, step: l.steps[i], stepNumber: i + 1),
      for (final LessonQuestion q in l.questions)
        _Card(_Kind.question, question: q),
      const _Card(_Kind.finish),
    ];
    // Resume: questions answered earlier stay answered.
    final LearningState learning = ref.read(learningProvider);
    for (final LessonQuestion q in l.questions) {
      final String key = '${l.id}::${q.id}';
      if (learning.reviewedQuestions.contains(key)) {
        _results[q.id] = learning.correctQuestions.contains(key)
            ? _Result.correct
            : _Result.wrong;
        _picked[q.id] = learning.correctQuestions.contains(key)
            ? q.correctOptionIndex
            : -1;
      }
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool _canAdvance(_Card card) {
    if (card.kind != _Kind.question) return true;
    final _Result r = _results[card.question!.id] ?? _Result.none;
    return r != _Result.none;
  }

  Future<void> _go(int target) async {
    if (target < 0 || target >= _cards.length) return;
    setState(() => _index = target);
    await _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  int get _answered => widget.lesson.questions
      .where((LessonQuestion q) {
        final _Result r = _results[q.id] ?? _Result.none;
        return r == _Result.correct || r == _Result.wrong;
      })
      .length;

  int get _correct => widget.lesson.questions
      .where((LessonQuestion q) => _results[q.id] == _Result.correct)
      .length;

  Future<bool> _confirmLeave() async {
    if (_index == 0 || _index == _cards.length - 1) return true;
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Leave this lesson?'),
        content: const Text(
            'Your answers so far are saved. You can pick up again later, but the streak is only earned when you finish with every question answered.'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep going')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Leave')),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _answer(LessonQuestion q, int option) async {
    final bool correct = option == q.correctOptionIndex;
    HapticFeedback.lightImpact();
    setState(() {
      _picked[q.id] = option;
      _results[q.id] = correct ? _Result.correct : _Result.wrong;
    });
    await ref.read(learningProvider.notifier).recordAnswer(
          lessonId: widget.lesson.id,
          questionId: q.id,
          correct: correct,
        );
  }

  Future<void> _skip(LessonQuestion q) async {
    setState(() => _results[q.id] = _Result.skipped);
    await ref.read(learningProvider.notifier).skipQuestion(
          lessonId: widget.lesson.id,
          questionId: q.id,
        );
    await _go(_index + 1);
  }

  void _finish() {
    final LearningLesson l = widget.lesson;
    Navigator.of(context).pushReplacement(
      fluidRoute<void>(
        LessonCompleteScreen(
          lessonId: l.id,
          lessonTitle: l.title,
          correctAnswers: _correct,
          totalQuestions: l.questions.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LearningLesson lesson = widget.lesson;
    final _Card current = _cards[_index];
    final bool isFinish = current.kind == _Kind.finish;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final NavigatorState nav = Navigator.of(context);
        if (await _confirmLeave()) nav.pop();
      },
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                lesson.tint.withOpacity(0.28),
                theme.colorScheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () async {
                          final NavigatorState nav = Navigator.of(context);
                          if (await _confirmLeave()) nav.pop();
                        },
                      ),
                      Expanded(child: _ProgressBar(
                        total: _cards.length,
                        current: _index,
                        color: lesson.tint,
                      )),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _cards.length,
                    itemBuilder: (BuildContext context, int i) =>
                        _buildCard(context, _cards[i]),
                  ),
                ),
                if (!isFinish)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Row(
                      children: <Widget>[
                        if (_index > 0)
                          IconButton.filledTonal(
                            onPressed: () => _go(_index - 1),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        if (_index > 0) const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: lesson.tint,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: _canAdvance(current)
                                ? () => _go(_index + 1)
                                : null,
                            child: Text(
                              current.kind == _Kind.intro
                                  ? 'Start lesson'
                                  : current.kind == _Kind.question &&
                                          !_canAdvance(current)
                                      ? 'Choose an answer'
                                      : 'Continue',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, _Card card) {
    switch (card.kind) {
      case _Kind.intro:
        return _IntroCard(lesson: widget.lesson);
      case _Kind.step:
        return _StepCard(
          lesson: widget.lesson,
          text: card.step!,
          number: card.stepNumber,
          total: widget.lesson.steps.length,
        );
      case _Kind.question:
        final LessonQuestion q = card.question!;
        return _QuestionCard(
          key: ValueKey<String>(q.id),
          question: q,
          tint: widget.lesson.tint,
          picked: _picked[q.id],
          result: _results[q.id] ?? _Result.none,
          onPick: (int option) => _answer(q, option),
          onSkip: () => _skip(q),
        );
      case _Kind.finish:
        final int total = widget.lesson.questions.length;
        final int skipped = total - _answered;
        return _FinishCard(
          lesson: widget.lesson,
          correct: _correct,
          answered: _answered,
          total: total,
          onFinish: skipped == 0 ? _finish : null,
          onReviewSkipped: skipped == 0
              ? null
              : () {
                  final int target = _cards.indexWhere((_Card c) =>
                      c.kind == _Kind.question &&
                      !(<_Result>[_Result.correct, _Result.wrong]
                          .contains(_results[c.question!.id])));
                  if (target >= 0) _go(target);
                },
          onLeave: () => Navigator.of(context).pop(),
        );
    }
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar(
      {required this.total, required this.current, required this.color});

  final int total;
  final int current;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < total; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              height: i == current ? 8 : 6,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: i <= current
                    ? color
                    : Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shared entrance: the card content floats up and fades in.
class _Rise extends StatelessWidget {
  const _Rise({required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? c) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(offset: Offset(0, (1 - t) * 24), child: c),
      ),
      child: child,
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.lesson});

  final LearningLesson lesson;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: _Rise(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lesson.tint.withOpacity(0.18),
                ),
                child: Icon(lesson.icon, size: 56, color: lesson.tint),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              children: <Widget>[
                _pill(context, lesson.track, lesson.tint),
                _pill(context, lesson.difficulty, lesson.tint),
                _pill(context, lesson.duration, lesson.tint),
              ],
            ),
            const SizedBox(height: 14),
            Text(lesson.title,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900, height: 1.1)),
            const SizedBox(height: 8),
            Text(lesson.subtitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Text(lesson.overview,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.local_fire_department_rounded,
                      color: Color(0xFFFF9600)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${lesson.steps.length} quick ideas, ${lesson.questions.length} questions. Answer every question to keep your streak - skipped questions earn nothing.',
                      style: theme.textTheme.bodySmall,
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

  Widget _pill(BuildContext context, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.16),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 12)),
      );
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.lesson,
    required this.text,
    required this.number,
    required this.total,
  });

  final LearningLesson lesson;
  final String text;
  final int number;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: _Rise(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(32),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: lesson.tint.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: lesson.tint,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('Idea $number of $total',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 22),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800, height: 1.35),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.question,
    required this.tint,
    required this.picked,
    required this.result,
    required this.onPick,
    required this.onSkip,
  });

  final LessonQuestion question;
  final Color tint;
  final int? picked;
  final _Result result;
  final ValueChanged<int> onPick;
  final VoidCallback onSkip;

  bool get _locked =>
      result == _Result.correct || result == _Result.wrong;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: _Rise(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(question.prompt,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900, height: 1.25)),
            const SizedBox(height: 20),
            for (int i = 0; i < question.options.length; i++)
              _option(context, i),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: _locked
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (result == _Result.correct
                                ? const Color(0xFF2E9E5B)
                                : const Color(0xFFE0524A))
                            .withOpacity(0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            result == _Result.correct
                                ? 'Correct!'
                                : 'Not quite',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: result == _Result.correct
                                  ? const Color(0xFF2E9E5B)
                                  : const Color(0xFFE0524A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(question.explanation,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(height: 1.5)),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (!_locked)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onSkip,
                  child: const Text('Skip (earns nothing)'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _option(BuildContext context, int i) {
    final ThemeData theme = Theme.of(context);
    final bool isPicked = picked == i;
    final bool isRight = i == question.correctOptionIndex;
    Color border = theme.colorScheme.outlineVariant;
    Color fill = theme.colorScheme.surfaceContainerHighest;
    if (_locked) {
      if (isRight) {
        border = const Color(0xFF2E9E5B);
        fill = const Color(0xFF2E9E5B).withOpacity(0.14);
      } else if (isPicked) {
        border = const Color(0xFFE0524A);
        fill = const Color(0xFFE0524A).withOpacity(0.14);
      }
    }
    final Widget tile = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: _locked && (isRight || isPicked) ? 2 : 1),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint.withOpacity(0.16),
            ),
            child: Text(String.fromCharCode(65 + i),
                style: TextStyle(color: tint, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(question.options[i],
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (_locked && isRight)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF2E9E5B)),
          if (_locked && isPicked && !isRight)
            const Icon(Icons.cancel_rounded, color: Color(0xFFE0524A)),
        ],
      ),
    );
    // Wrong picks shake once.
    final Widget animated = (_locked && isPicked && !isRight)
        ? TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            builder: (BuildContext context, double t, Widget? c) =>
                Transform.translate(
                    offset: Offset(math.sin(t * math.pi * 4) * 8 * (1 - t), 0),
                    child: c),
            child: tile,
          )
        : tile;
    return GestureDetector(
      onTap: _locked ? null : () => onPick(i),
      child: animated,
    );
  }
}

class _FinishCard extends StatelessWidget {
  const _FinishCard({
    required this.lesson,
    required this.correct,
    required this.answered,
    required this.total,
    required this.onFinish,
    required this.onReviewSkipped,
    required this.onLeave,
  });

  final LearningLesson lesson;
  final int correct;
  final int answered;
  final int total;
  final VoidCallback? onFinish;
  final VoidCallback? onReviewSkipped;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int skipped = total - answered;
    final bool ready = skipped == 0;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _Rise(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              ready ? Icons.emoji_events_rounded : Icons.flag_rounded,
              size: 88,
              color: ready ? const Color(0xFFFFB300) : lesson.tint,
            ),
            const SizedBox(height: 18),
            Text(
              ready ? 'Lesson finished!' : 'Almost there',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              ready
                  ? 'You got $correct of $total right. Claim your XP and extend your streak.'
                  : '$skipped question${skipped == 1 ? '' : 's'} still unanswered. Skipped questions earn no XP and do not count towards your streak - answer them to finish.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: ready ? const Color(0xFF2E9E5B) : lesson.tint,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: ready ? onFinish : onReviewSkipped,
                child: Text(
                  ready ? 'Claim rewards' : 'Answer skipped questions',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
            if (!ready)
              TextButton(
                  onPressed: onLeave, child: const Text('Leave without rewards')),
          ],
        ),
      ),
    );
  }
}
