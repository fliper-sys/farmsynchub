import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/learning_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final LearningState learning = ref.watch(learningProvider);
    const List<LearningLesson> lessons = _learningLessons;
    const List<PracticeActivity> activities = _practiceActivities;
    final double lessonProgress = lessons.isEmpty
        ? 0
        : lessons.map((LearningLesson lesson) => _lessonProgress(learning, lesson)).fold<double>(0, (double sum, double value) => sum + value) / lessons.length;
    final int completedLessons = learning.completedLessons.length;
    final int completedPractices = learning.completedPractices.length;
    final int totalActions = lessons.length + activities.length;
    final double progress = totalActions == 0
        ? 0
        : ((lessonProgress * lessons.length) + completedPractices) / totalActions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go('/dashboard'),
              ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Share learning hub',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => _shareText(
              ref,
              'learning-hub',
              'I am using FarmSync Learn for crop, livestock, soil, weather, and market lessons. Progress: ${(progress * 100).round()}%.',
            ),
          ),
        ],
      ),
      body: SoftScreenScaffold(
        heroTitle: 'Learning hub',
        heroSubtitle:
            'Lessons, practice work, saved progress, awards, and shareable field guides for crop and livestock management.',
        heroIcon: Icons.menu_book_rounded,
        heroVariant: FarmArtworkVariant.field,
        heroBadge: '${learning.awardCount} awards earned',
        sections: <Widget>[
          const SoftSectionTitle(title: 'Learning progress'),
          Row(
            children: <Widget>[
              Expanded(
                child: SoftInfoChip(
                  label: AppStrings.lessons,
                  value: '${lessons.length}',
                  color: const Color(0xFFDFF1FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SoftInfoChip(
                  label: AppStrings.progress,
                  value: '${(progress * 100).round()}%',
                  color: const Color(0xFFE8F4D8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SoftInfoChip(
                  label: 'Awards',
                  value: '${learning.awardCount}',
                  color: const Color(0xFFFFEBCF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress.clamp(0.0, 1.0).toDouble(),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryMid),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Awards'),
          _AwardsBoard(learning: learning),
          const SizedBox(height: 18),
          SoftSectionTitle(
            title: AppStrings.continueLearning,
            action: Text(
              '$completedLessons completed',
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          ...lessons.map(
            (LearningLesson lesson) {
              final bool completed = learning.completedLessons.contains(lesson.id);
              final double currentProgress = _lessonProgress(learning, lesson);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LessonCard(
                  lesson: lesson,
                  completed: completed,
                  progress: currentProgress,
                  onTap: () => _openPage(
                    context,
                    LearnLessonDetailScreen(lesson: lesson),
                  ),
                  onShare: () => _shareText(ref, lesson.id, lesson.shareText),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Learning tracks'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            childAspectRatio: 1.08,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: _learningTracks
                .map(
                  (LearningTrack track) => _TopicCard(
                    track: track,
                    completedCount: lessons
                        .where(
                          (LearningLesson lesson) =>
                              lesson.track == track.title &&
                              learning.completedLessons.contains(lesson.id),
                        )
                        .length,
                    onTap: () => _openPage(
                      context,
                      LearnTrackDetailScreen(
                        track: track,
                        lessons: lessons
                            .where((LearningLesson lesson) => lesson.track == track.title)
                            .toList(),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          SoftSectionTitle(
            title: 'Practice activities',
            action: Text(
              '$completedPractices done',
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          ...activities.map(
            (PracticeActivity activity) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PracticeCard(
                activity: activity,
                completed: learning.completedPractices.contains(activity.id),
                onTap: () => _openPage(
                  context,
                  LearnPracticeDetailScreen(activity: activity),
                ),
                onShare: () => _shareText(ref, activity.id, activity.shareText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => page,
      ),
    );
  }
}

class LearnLessonDetailScreen extends ConsumerWidget {
  const LearnLessonDetailScreen({
    super.key,
    required this.lesson,
  });

  final LearningLesson lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LearningState learning = ref.watch(learningProvider);
    final bool completed = learning.completedLessons.contains(lesson.id);
    final bool skipped = learning.skippedLessons.contains(lesson.id);
    final int reviewedQuestions = lesson.questions
        .where(
          (LessonQuestion question) =>
              learning.reviewedQuestions.contains('${lesson.id}::${question.id}'),
        )
        .length;
    final double questionProgress = lesson.questions.isEmpty ? 0 : reviewedQuestions / lesson.questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Share to WhatsApp',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => _shareText(ref, lesson.id, lesson.shareText),
          ),
        ],
      ),
      body: SoftScreenScaffold(
        heroTitle: lesson.title,
        heroSubtitle: lesson.subtitle,
        heroIcon: lesson.icon,
        heroVariant: FarmArtworkVariant.crops,
        heroBadge: '${lesson.duration} - ${lesson.difficulty}',
        showArtwork: false,
        sections: <Widget>[
          _LessonImageHeader(lesson: lesson),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: SoftInfoChip(
                  label: 'Track',
                  value: lesson.track,
                  color: lesson.tint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SoftInfoChip(
                  label: 'Status',
                  value: completed
                      ? 'Completed'
                      : skipped
                          ? 'Skipped for now'
                          : reviewedQuestions == 0
                              ? 'Not started'
                              : '$reviewedQuestions checked',
                  color: const Color(0xFFE8F4D8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: questionProgress.clamp(0.0, 1.0).toDouble(),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(lesson.tint),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lesson.questions.isEmpty
                ? 'Lesson progress is based on the reading steps.'
                : '$reviewedQuestions of ${lesson.questions.length} understanding checks reviewed',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Overview'),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                lesson.overview,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Field steps'),
          ...lesson.steps.asMap().entries.map(
            (MapEntry<int, String> entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChecklistTile(
                index: entry.key + 1,
                text: entry.value,
                tint: lesson.tint,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Use this on the farm'),
          ...lesson.tools.map(
            (String tool) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ToolRow(text: tool, tint: lesson.tint),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Check your understanding'),
          if (lesson.questions.isEmpty)
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'This lesson does not have quiz questions yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ...lesson.questions.asMap().entries.map(
              (MapEntry<int, LessonQuestion> entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _QuizQuestionCard(
                  lessonId: lesson.id,
                  question: entry.value,
                  index: entry.key + 1,
                  tint: lesson.tint,
                ),
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton.secondary(
                  onPressed: () => _shareText(ref, lesson.id, lesson.shareText),
                  child: const Text('Share guide'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.primary(
                  onPressed: completed
                      ? null
                      : () async {
                          await ref.read(learningProvider.notifier).completeLesson(lesson.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lesson completed. Award progress updated.')),
                            );
                          }
                        },
                  child: Text(completed ? 'Completed' : 'Mark complete'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppButton.secondary(
              onPressed: skipped
                  ? null
                  : () async {
                      await ref.read(learningProvider.notifier).skipLesson(lesson.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lesson skipped for now. You can come back later.')),
                        );
                      }
                    },
              child: Text(skipped ? 'Skipped' : 'Skip lesson for now'),
            ),
          ),
        ],
      ),
    );
  }
}

class LearnTrackDetailScreen extends ConsumerWidget {
  const LearnTrackDetailScreen({
    super.key,
    required this.track,
    required this.lessons,
  });

  final LearningTrack track;
  final List<LearningLesson> lessons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LearningState learning = ref.watch(learningProvider);
    final int completed = lessons
        .where((LearningLesson lesson) => learning.completedLessons.contains(lesson.id))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(track.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SoftScreenScaffold(
        heroTitle: track.title,
        heroSubtitle: track.summary,
        heroIcon: track.icon,
        heroVariant: FarmArtworkVariant.field,
        heroBadge: '$completed of ${lessons.length} completed',
        sections: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: SoftInfoChip(
                  label: 'Lessons',
                  value: '${lessons.length}',
                  color: track.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SoftInfoChip(
                  label: 'Completed',
                  value: '$completed',
                  color: const Color(0xFFE8F4D8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Featured lessons'),
          if (lessons.isEmpty)
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'New lessons for this track are being prepared.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ...lessons.map(
              (LearningLesson lesson) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LessonCard(
                  lesson: lesson,
                  completed: learning.completedLessons.contains(lesson.id),
                  progress: _lessonProgress(learning, lesson),
                  onShare: () => _shareText(ref, lesson.id, lesson.shareText),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LearnLessonDetailScreen(lesson: lesson),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LearnPracticeDetailScreen extends ConsumerWidget {
  const LearnPracticeDetailScreen({
    super.key,
    required this.activity,
  });

  final PracticeActivity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool completed = ref.watch(learningProvider).completedPractices.contains(activity.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(activity.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Share to WhatsApp',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => _shareText(ref, activity.id, activity.shareText),
          ),
        ],
      ),
      body: SoftScreenScaffold(
        heroTitle: activity.title,
        heroSubtitle: activity.subtitle,
        heroIcon: activity.icon,
        heroVariant: FarmArtworkVariant.dashboard,
        heroBadge: completed ? 'Practice completed' : 'Practice activity',
        sections: <Widget>[
          const SoftSectionTitle(title: 'Action steps'),
          ...activity.checklist.asMap().entries.map(
            (MapEntry<int, String> entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChecklistTile(
                index: entry.key + 1,
                text: entry.value,
                tint: activity.color,
              ),
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: activity.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.lightbulb_outline_rounded),
              ),
              title: const Text('Why this matters'),
              subtitle: Text(
                activity.whyItMatters,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton.secondary(
                  onPressed: () => _shareText(ref, activity.id, activity.shareText),
                  child: const Text('Share'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.primary(
                  onPressed: completed
                      ? null
                      : () async {
                          await ref.read(learningProvider.notifier).completePractice(activity.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Practice completed.')),
                            );
                          }
                        },
                  child: Text(completed ? 'Completed' : 'Mark done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AwardsBoard extends StatelessWidget {
  const _AwardsBoard({required this.learning});

  final LearningState learning;

  @override
  Widget build(BuildContext context) {
    final List<_AwardData> awards = <_AwardData>[
      _AwardData(
        title: 'First Lesson',
        detail: 'Complete one lesson',
        unlocked: learning.completedLessons.isNotEmpty,
        icon: Icons.school_rounded,
        tint: const Color(0xFFDFF1FF),
      ),
      _AwardData(
        title: 'Crop Scholar',
        detail: 'Complete three lessons',
        unlocked: learning.completedLessons.length >= 3,
        icon: Icons.workspace_premium_rounded,
        tint: const Color(0xFFE8F4D8),
      ),
      _AwardData(
        title: 'Field Doer',
        detail: 'Finish two practices',
        unlocked: learning.completedPractices.length >= 2,
        icon: Icons.fact_check_rounded,
        tint: const Color(0xFFFFEBCF),
      ),
      _AwardData(
        title: 'Community Helper',
        detail: 'Share one guide',
        unlocked: learning.sharedItems.isNotEmpty,
        icon: Icons.groups_rounded,
        tint: const Color(0xFFEDE8FF),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.32,
      children: awards.map((_AwardData award) => _AwardCard(award: award)).toList(),
    );
  }
}

class _AwardCard extends StatelessWidget {
  const _AwardCard({required this.award});

  final _AwardData award;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: award.unlocked ? award.tint : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Icon(
                    award.unlocked ? award.icon : Icons.lock_outline_rounded,
                    color: award.unlocked ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Icon(
                  award.unlocked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: award.unlocked ? AppColors.primaryMid : theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const Spacer(),
            Text(
              award.title,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              award.detail,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonImageHeader extends StatelessWidget {
  const _LessonImageHeader({required this.lesson});

  final LearningLesson lesson;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: <Widget>[
            Image.asset(
              lesson.imageAsset,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => FarmSceneArtwork(
                height: 220,
                variant: FarmArtworkVariant.crops,
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.86),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  lesson.track,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.completed,
    required this.progress,
    required this.onTap,
    required this.onShare,
  });

  final LearningLesson lesson;
  final bool completed;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                lesson.imageAsset,
                width: 72,
                height: 82,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 72,
                  height: 82,
                  color: lesson.tint,
                  child: Icon(lesson.icon),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          lesson.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Share to WhatsApp',
                        onPressed: onShare,
                        icon: const Icon(Icons.ios_share_rounded),
                      ),
                    ],
                  ),
                  Text(
                    lesson.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: progress.clamp(0.0, 1.0).toDouble(),
                      backgroundColor: theme.colorScheme.surface,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completed ? AppColors.primaryMid : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MiniMeta(
                        text: completed ? 'Completed' : '${(progress * 100).round()}%',
                        color: completed ? const Color(0xFFE8F4D8) : lesson.tint,
                      ),
                      _MiniMeta(text: lesson.duration, color: const Color(0xFFDFF1FF)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.track,
    required this.completedCount,
    required this.onTap,
  });

  final LearningTrack track;
  final int completedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: track.color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(track.icon),
                ),
                const Spacer(),
                Text('$completedCount done', style: theme.textTheme.bodySmall),
              ],
            ),
            const Spacer(),
            Text(track.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(track.detail, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.activity,
    required this.completed,
    required this.onTap,
    required this.onShare,
  });

  final PracticeActivity activity;
  final bool completed;
  final VoidCallback onTap;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: activity.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(activity.icon),
        ),
        title: Text(
          activity.title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            activity.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            IconButton(
              tooltip: 'Share',
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_rounded),
            ),
            Icon(completed ? Icons.check_circle_rounded : Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.text,
    required this.tint,
  });

  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.build_circle_outlined, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _QuizQuestionCard extends ConsumerStatefulWidget {
  const _QuizQuestionCard({
    required this.lessonId,
    required this.question,
    required this.index,
    required this.tint,
  });

  final String lessonId;
  final LessonQuestion question;
  final int index;
  final Color tint;

  @override
  ConsumerState<_QuizQuestionCard> createState() => _QuizQuestionCardState();
}

class _QuizQuestionCardState extends ConsumerState<_QuizQuestionCard> {
  int? _selectedIndex;
  bool _revealed = false;
  bool? _isCorrect;
  bool _skipped = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.tint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index}',
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.question.prompt,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...widget.question.options.asMap().entries.map(
              (MapEntry<int, String> entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RadioListTile<int>(
                  value: entry.key,
                  groupValue: _selectedIndex,
                  onChanged: _revealed
                      ? null
                      : (int? value) {
                          setState(() => _selectedIndex = value);
                        },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  title: Text(entry.value),
                  dense: true,
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (_revealed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (_isCorrect ?? false) ? const Color(0xFFE8F4D8) : const Color(0xFFFFEBCF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  _skipped
                      ? 'Skipped for now. ${widget.question.explanation}'
                      : (_isCorrect ?? false)
                          ? 'Correct. ${widget.question.explanation}'
                          : 'Not quite. ${widget.question.explanation}',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton.secondary(
                    onPressed: _revealed
                        ? null
                        : () async {
                            await ref.read(learningProvider.notifier).markQuestionReviewed(
                                  lessonId: widget.lessonId,
                                  questionId: widget.question.id,
                                );
                            setState(() {
                              _skipped = true;
                              _revealed = true;
                              _isCorrect = null;
                            });
                          },
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton.primary(
                    onPressed: _revealed
                        ? null
                        : () async {
                            if (_selectedIndex == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Choose an answer or skip the question.')),
                              );
                              return;
                            }
                            final bool correct = _selectedIndex == widget.question.correctOptionIndex;
                            await ref.read(learningProvider.notifier).markQuestionReviewed(
                                  lessonId: widget.lessonId,
                                  questionId: widget.question.id,
                                );
                            setState(() {
                              _skipped = false;
                              _isCorrect = correct;
                              _revealed = true;
                            });
                          },
                    child: Text(_revealed ? 'Checked' : 'Check answer'),
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

class _MiniMeta extends StatelessWidget {
  const _MiniMeta({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.index,
    required this.text,
    required this.tint,
  });

  final int index;
  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _shareText(WidgetRef ref, String itemId, String text) async {
  await ref.read(learningProvider.notifier).markShared(itemId);
  final Uri uri = Uri.parse(
    'https://wa.me/?text=${Uri.encodeComponent(text)}',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

double _lessonProgress(LearningState learning, LearningLesson lesson) {
  if (lesson.questions.isEmpty) {
    return learning.completedLessons.contains(lesson.id) ? 1 : lesson.baseProgress;
  }

  final int reviewedQuestions = lesson.questions
      .where(
        (LessonQuestion question) =>
            learning.reviewedQuestions.contains('${lesson.id}::${question.id}'),
      )
      .length;
  if (learning.completedLessons.contains(lesson.id)) {
    return 1;
  }
  if (learning.skippedLessons.contains(lesson.id) && reviewedQuestions == 0) {
    return 0;
  }
  return reviewedQuestions / lesson.questions.length;
}

class _AwardData {
  const _AwardData({
    required this.title,
    required this.detail,
    required this.unlocked,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String detail;
  final bool unlocked;
  final IconData icon;
  final Color tint;
}

class LearningLesson {
  const LearningLesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.baseProgress,
    required this.duration,
    required this.tint,
    required this.track,
    required this.difficulty,
    required this.overview,
    required this.steps,
    required this.questions,
    required this.tools,
    required this.icon,
    required this.imageAsset,
  });

  final String id;
  final String title;
  final String subtitle;
  final double baseProgress;
  final String duration;
  final Color tint;
  final String track;
  final String difficulty;
  final String overview;
  final List<String> steps;
  final List<LessonQuestion> questions;
  final List<String> tools;
  final IconData icon;
  final String imageAsset;

  String get shareText {
    return 'FarmSync Learn: $title\n$subtitle\n\nTry this first: ${steps.first}';
  }
}

class LessonQuestion {
  const LessonQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
}

class LearningTrack {
  const LearningTrack({
    required this.title,
    required this.icon,
    required this.detail,
    required this.color,
    required this.summary,
  });

  final String title;
  final IconData icon;
  final String detail;
  final Color color;
  final String summary;
}

class PracticeActivity {
  const PracticeActivity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.checklist,
    required this.whyItMatters,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> checklist;
  final String whyItMatters;

  String get shareText {
    return 'FarmSync practice: $title\n$subtitle\n\nChecklist:\n- ${checklist.join('\n- ')}';
  }
}

const List<LearningLesson> _learningLessons = <LearningLesson>[
  LearningLesson(
    id: 'soil-moisture',
    title: 'Managing soil moisture',
    subtitle: 'A short field guide for dry-season irrigation balance.',
    baseProgress: 0.72,
    duration: '8 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.water_drop_rounded,
    imageAsset: AppAssets.uiLeafField,
    overview:
        'Learn how to observe moisture loss across the root zone, match watering to crop stage, and avoid wasting labour or water during dry periods. You will also learn how mulch, soil type, and drainage affect how long water stays available to the crop.',
    steps: <String>[
      'Check the top soil early in the morning before irrigation and note whether the soil is dusty, crusted, or still slightly cool.',
      'Group beds by crop stage so young plants get priority water.',
      'Mulch exposed areas to slow surface drying and reduce the heat stress that young roots feel at midday.',
      'Record stress signs like curling leaves or blossom drop.',
      'If the soil stays wet too long, inspect drainage channels and reduce the next watering cycle.',
      'Compare the moisture in shaded beds and open beds so you understand how the weather is changing field demand.',
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'soil-1',
        prompt: 'What should you check first before watering a field?',
        options: <String>[
          'Top soil moisture in the morning',
          'The sales record for last week',
          'The tractor tire pressure',
        ],
        correctOptionIndex: 0,
        explanation: 'Checking the top soil early helps you see whether the root zone actually needs water.',
      ),
      LessonQuestion(
        id: 'soil-2',
        prompt: 'Why should young plants get priority water?',
        options: <String>[
          'They always need more fertilizer',
          'They are more sensitive to stress and drying',
          'They do not need monitoring later',
        ],
        correctOptionIndex: 1,
        explanation: 'Young plants are more vulnerable to moisture stress, so they should be served first.',
      ),
      LessonQuestion(
        id: 'soil-3',
        prompt: 'What helps slow surface drying between irrigations?',
        options: <String>[
          'Mulching exposed beds',
          'Skipping field notes',
          'Watering only once a month',
        ],
        correctOptionIndex: 0,
        explanation: 'Mulch protects the soil surface and reduces water loss from heat and wind.',
      ),
      LessonQuestion(
        id: 'soil-4',
        prompt: 'What should you inspect if the field stays wet for too long?',
        options: <String>[
          'Drainage channels and the watering cycle',
          'The farm logo',
          'The number of crates in storage',
        ],
        correctOptionIndex: 0,
        explanation: 'Poor drainage can cause waterlogging, so you should check the flow paths and reduce watering.',
      ),
    ],
    tools: <String>[
      'Use a simple soil squeeze test before watering.',
      'Create a two-column note: dry beds and stable beds.',
      'Log rainfall and irrigation dates after every field visit.',
      'Mark beds that dry first so you can plan irrigation priority.',
    ],
  ),
  LearningLesson(
    id: 'livestock-vaccination',
    title: 'Livestock vaccination basics',
    subtitle: 'Simple health routines for smallholder teams.',
    baseProgress: 0.48,
    duration: '12 min',
    tint: Color(0xFFE9F4DB),
    track: AppStrings.animalHealth,
    difficulty: 'Essential',
    icon: Icons.pets_rounded,
    imageAsset: AppAssets.uiFieldSprayer,
    overview:
        'Build a reliable vaccination routine, reduce avoidable disease losses, and keep cleaner treatment records for every group. This lesson also explains cold-chain handling, batch tracking, and how to plan follow-up checks after each round of treatment.',
    steps: <String>[
      'Keep a dated vaccine calendar by species and age group.',
      'Store vaccines correctly in a cool box and avoid using expired doses or broken vials.',
      'Separate treated animals so follow-up is easier to track and sick animals can be watched closely.',
      'Log reactions, missed doses, batch numbers, and the next health action.',
      'Tell workers which animals still need the next booster before the next visit.',
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'livestock-1',
        prompt: 'What is the most reliable way to avoid missed vaccinations?',
        options: <String>[
          'A dated vaccine calendar',
          'Guessing by animal size',
          'Waiting for symptoms to appear',
        ],
        correctOptionIndex: 0,
        explanation: 'A dated calendar keeps each animal group on time and reduces missed doses.',
      ),
      LessonQuestion(
        id: 'livestock-2',
        prompt: 'Why should treated animals be separated?',
        options: <String>[
          'So follow-up is easier to track',
          'To hide them from buyers',
          'Because vaccines make animals invisible',
        ],
        correctOptionIndex: 0,
        explanation: 'Separation makes monitoring treatment results and follow-up much easier.',
      ),
      LessonQuestion(
        id: 'livestock-3',
        prompt: 'What should be logged after a vaccination event?',
        options: <String>[
          'Reactions, missed doses, and next action',
          'Only the number of workers present',
          'The weather forecast for next month',
        ],
        correctOptionIndex: 0,
        explanation: 'Those records help the team keep the health plan accurate and actionable.',
      ),
      LessonQuestion(
        id: 'livestock-4',
        prompt: 'Why is cold storage important for vaccines?',
        options: <String>[
          'It helps keep the vaccine effective',
          'It makes the bottle look cleaner',
          'It changes the animal color',
        ],
        correctOptionIndex: 0,
        explanation: 'Many vaccines lose strength if they are not kept at the right temperature.',
      ),
    ],
    tools: <String>[
      'Create one health note per animal group.',
      'Keep provider phone numbers attached to procurement records.',
      'Set a weekly check for feed, water, housing, and symptoms.',
      'Store batch numbers beside each treatment date.',
    ],
  ),
  LearningLesson(
    id: 'market-timing',
    title: 'Reading market timing',
    subtitle: 'When to sell produce and when to hold stock a little longer.',
    baseProgress: 0.23,
    duration: '10 min',
    tint: Color(0xFFFFEBCF),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.storefront_rounded,
    imageAsset: AppAssets.uiProduceMarket,
    overview:
        'Compare timing, spoilage risk, transport cost, and demand signals so you can choose better selling windows. You will also learn how to estimate net profit after transport and how to avoid rushing stock into a weak market.',
    steps: <String>[
      'Watch weekly price changes for your main produce and note the best and worst buyers.',
      'Estimate transport, loading, and handling before deciding to wait for a later sale.',
      'Compare buyers by reliability, payment speed, and location, not just headline price.',
      'Match harvest planning to expected demand peaks, festivals, and rainy-season road conditions.',
      'If stock is highly perishable, calculate how many days you can safely hold it before quality drops.',
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'market-1',
        prompt: 'What should you compare before choosing a buyer?',
        options: <String>[
          'Price, reliability, and transport cost',
          'Only the buyer logo',
          'How far their office is from the city center',
        ],
        correctOptionIndex: 0,
        explanation: 'The best buyer is not always the highest price; reliability and logistics matter too.',
      ),
      LessonQuestion(
        id: 'market-2',
        prompt: 'Why is transport cost important in market timing?',
        options: <String>[
          'It changes the real profit from the sale',
          'It replaces harvest planning',
          'It only matters for importers',
        ],
        correctOptionIndex: 0,
        explanation: 'A good sale price can still produce poor profit if transport eats the margin.',
      ),
      LessonQuestion(
        id: 'market-3',
        prompt: 'What should you record after every sale?',
        options: <String>[
          'Receipt, buyer, and quantity sold',
          'Only the market name',
          'The number of baskets unused',
        ],
        correctOptionIndex: 0,
        explanation: 'Sale records make future pricing and inventory decisions much easier.',
      ),
      LessonQuestion(
        id: 'market-4',
        prompt: 'What extra cost can reduce your real profit even when the sale price looks good?',
        options: <String>[
          'Transport and handling cost',
          'The color of the buyers car',
          'The size of your notebook',
        ],
        correctOptionIndex: 0,
        explanation: 'Transport and handling expenses can significantly reduce the profit from a sale.',
      ),
    ],
    tools: <String>[
      'Record every sale receipt with buyer and product quantity.',
      'Compare three buyer prices before large sales.',
      'Track unsold stock in inventory after each market day.',
      'Estimate your break-even price before agreeing to hold produce.',
    ],
  ),
  LearningLesson(
    id: 'crop-pest-scouting',
    title: 'Crop pest scouting',
    subtitle: 'Spot pest pressure early before it spreads across beds.',
    baseProgress: 0.12,
    duration: '9 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.bug_report_rounded,
    imageAsset: AppAssets.uiFarmLandscape,
    overview:
        'Use a repeatable scouting route to notice leaf damage, eggs, wilting, and disease patterns before yield is affected. This lesson shows you how to map hot spots, look for beneficial insects, and decide when a problem is serious enough to escalate.',
    steps: <String>[
      'Walk a zig-zag route through the field instead of checking one edge.',
      'Inspect the underside of leaves for eggs and small larvae.',
      'Compare affected plants with healthy plants nearby.',
      'Take a clear photo and ask the AI advisor before treatment or spraying.',
      'Mark the bed or row number so you can return to the same spot tomorrow.',
      'Look for beneficial insects as well as pests so you do not spray too early.',
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'pest-1',
        prompt: 'What scouting route helps you inspect more of the field?',
        options: <String>[
          'A zig-zag route',
          'Only the first row',
          'A route based on the biggest weeds',
        ],
        correctOptionIndex: 0,
        explanation: 'A zig-zag route covers more plants and gives a better picture of field conditions.',
      ),
      LessonQuestion(
        id: 'pest-2',
        prompt: 'Where do many pest eggs and larvae hide?',
        options: <String>[
          'On the underside of leaves',
          'Inside the soil only',
          'On the farm gate',
        ],
        correctOptionIndex: 0,
        explanation: 'The underside of leaves is a common place to find early pest signs.',
      ),
      LessonQuestion(
        id: 'pest-3',
        prompt: 'What is a good first response before spraying?',
        options: <String>[
          'Take a clear photo and confirm the issue',
          'Spray immediately without checking',
          'Wait until every plant is damaged',
        ],
        correctOptionIndex: 0,
        explanation: 'Confirming the pest or disease first helps prevent waste and wrong treatment.',
      ),
      LessonQuestion(
        id: 'pest-4',
        prompt: 'Why should you also look for beneficial insects?',
        options: <String>[
          'So you avoid spraying too early and harming useful insects',
          'Because they are always pests',
          'To make the field look brighter',
        ],
        correctOptionIndex: 0,
        explanation: 'Beneficial insects can help control pests, so identifying them prevents unnecessary spraying.',
      ),
    ],
    tools: <String>[
      'Carry a small notebook, phone camera, and hand lens if available.',
      'Record pest location by bed or section.',
      'Avoid spraying until the pest or disease signs are confirmed.',
      'Use one scouting route every week so comparisons stay consistent.',
    ],
  ),
  LearningLesson(
    id: 'weather-work-plan',
    title: 'Weather-based work planning',
    subtitle: 'Use rain, temperature, and humidity to schedule farm tasks.',
    baseProgress: 0.18,
    duration: '7 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.weatherForecast,
    difficulty: 'Planning',
    icon: Icons.cloud_queue_rounded,
    imageAsset: AppAssets.uiSmartFarm,
    overview:
        'Turn weather conditions into better daily decisions for spraying, irrigation, harvesting, drying, storage, and transport. The goal is to reduce avoidable losses by matching each job to the right part of the day and the right weather window.',
    steps: <String>[
      'Avoid spraying before expected rainfall or strong wind.',
      'Harvest early when afternoon heat can reduce produce quality.',
      'Move feed and harvested produce under cover before heavy rain.',
      'Use humidity and soil moisture readings to adjust irrigation.',
      'Shift labour-heavy jobs to cooler hours when heat stress is high.',
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'weather-1',
        prompt: 'When should spraying be avoided?',
        options: <String>[
          'Before rainfall or strong wind',
          'Only after sunrise',
          'Whenever the field is wet from dew',
        ],
        correctOptionIndex: 0,
        explanation: 'Rain and wind can wash away spray or drift it away from target crops.',
      ),
      LessonQuestion(
        id: 'weather-2',
        prompt: 'Why do many teams harvest early in hot weather?',
        options: <String>[
          'To reduce quality loss in the afternoon heat',
          'Because plants grow faster at noon',
          'So the work looks shorter on paper',
        ],
        correctOptionIndex: 0,
        explanation: 'Early harvesting helps maintain product quality and reduces heat stress.',
      ),
      LessonQuestion(
        id: 'weather-3',
        prompt: 'What readings help adjust irrigation properly?',
        options: <String>[
          'Humidity and soil moisture',
          'Phone battery level',
          'Receipt count from last market day',
        ],
        correctOptionIndex: 0,
        explanation: 'Humidity and soil moisture show whether the field actually needs water.',
      ),
      LessonQuestion(
        id: 'weather-4',
        prompt: 'Why should labour-heavy jobs move to cooler hours during heat stress?',
        options: <String>[
          'To reduce worker fatigue and crop damage',
          'Because the sun is prettier in the afternoon',
          'To avoid writing extra notes',
        ],
        correctOptionIndex: 0,
        explanation: 'Cooler hours reduce fatigue and help the team work more safely and efficiently.',
      ),
    ],
    tools: <String>[
      'Check the dashboard weather card before field work.',
      'Group tasks into morning, afternoon, and rain-delay lists.',
      'Share weather-sensitive plans with workers before they leave.',
      'Move harvested produce and feed under cover before storms arrive.',
    ],
  ),
  LearningLesson(
    id: 'post-harvest-handling',
    title: 'Post-harvest handling',
    subtitle: 'Keep produce fresher from the field to the buyer.',
    baseProgress: 0.16,
    duration: '11 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Practical',
    icon: Icons.emoji_food_beverage_rounded,
    imageAsset: AppAssets.uiProduceMarket,
    overview:
        'Learn how shade, cleaning, sorting, and careful packing reduce damage and improve the value of harvested produce. The lesson also covers how to reduce bruising, contamination, and moisture loss during the first few hours after harvest.',
    steps: <String>[
      'Harvest during the coolest part of the day when possible.',
      'Sort damaged produce separately before packing.',
      'Keep crates and bags clean and dry.',
      'Store harvested items away from direct sun and rain.',
      'Avoid overfilling bags or crates so the bottom layers do not get crushed.',
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'post-1',
        prompt: 'Why sort damaged produce before packing?',
        options: <String>[
          'To keep the best produce in the main pack',
          'To make the crate heavier',
          'To avoid checking quality',
        ],
        correctOptionIndex: 0,
        explanation: 'Sorting damaged items prevents them from reducing the quality of the whole batch.',
      ),
      LessonQuestion(
        id: 'post-2',
        prompt: 'What helps reduce post-harvest damage?',
        options: <String>[
          'Clean, dry crates and shade',
          'Leaving produce in direct sun',
          'Mixing wet and dry produce together',
        ],
        correctOptionIndex: 0,
        explanation: 'Shade and clean containers protect produce from heat and contamination.',
      ),
      LessonQuestion(
        id: 'post-3',
        prompt: 'When is harvesting usually safer for quality?',
        options: <String>[
          'During the coolest part of the day',
          'At the hottest midday hour',
          'Only after a long rain',
        ],
        correctOptionIndex: 0,
        explanation: 'Cooler hours reduce heat stress and help preserve freshness.',
      ),
    ],
    tools: <String>[
      'Use clean containers and quick sorting.',
      'Shade produce before transport.',
      'Record losses from bruising or spoilage.',
      'Keep harvest and washing tools separate from animal feed containers.',
    ],
  ),
  LearningLesson(
    id: 'record-keeping',
    title: 'Farm record keeping',
    subtitle: 'Build simple logs that improve decisions and finance access.',
    baseProgress: 0.34,
    duration: '10 min',
    tint: Color(0xFFDFF1FF),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.receipt_long_rounded,
    imageAsset: AppAssets.uiSmartFarm,
    overview:
        'Good records help you track costs, compare results across seasons, and support loans, partnerships, and farm planning. Clear logs also make it easier to prove what happened on the farm, assign responsibility, and spot repeat problems before they become expensive.',
    steps: <String>[
      'Record labour, inputs, sales, and major observations every week.',
      'Use one notebook or app section per farm activity.',
      'Separate income records from expenses.',
      'Review the records before planning the next cycle.',
      'Keep photos, receipts, and delivery notes beside the written log when possible.',
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'record-1',
        prompt: 'Why do farm records matter to lenders and partners?',
        options: <String>[
          'They show activity, costs, and repayment ability',
          'They replace the need for a farm plan',
          'They only matter for large commercial farms',
        ],
        correctOptionIndex: 0,
        explanation: 'Records make the farm easier to assess and support financing decisions.',
      ),
      LessonQuestion(
        id: 'record-2',
        prompt: 'What should be separated in the records?',
        options: <String>[
          'Income and expenses',
          'Morning and afternoon weather only',
          'Worker uniforms and field boots',
        ],
        correctOptionIndex: 0,
        explanation: 'Separating income and expenses keeps the farm\'s financial picture clear.',
      ),
      LessonQuestion(
        id: 'record-3',
        prompt: 'When is a good time to review records?',
        options: <String>[
          'Before planning the next cycle',
          'Only at the end of the year',
          'After you forget what happened',
        ],
        correctOptionIndex: 0,
        explanation: 'Reviewing records before the next cycle helps you improve the next plan.',
      ),
      LessonQuestion(
        id: 'record-4',
        prompt: 'What helps prove what happened on the farm when you review records later?',
        options: <String>[
          'Photos, receipts, and delivery notes',
          'Only the memory of one worker',
          'The color of the notebook cover',
        ],
        correctOptionIndex: 0,
        explanation: 'Supporting documents make the record clearer and easier to trust.',
      ),
    ],
    tools: <String>[
      'Use a simple weekly log.',
      'Store receipts and delivery notes together.',
      'Review costs before buying the next inputs.',
      'Give each farm activity its own record section.',
    ],
  ),
  LearningLesson(
    id: 'feeding-and-grazing',
    title: 'Feeding and grazing routine',
    subtitle: 'Keep animals healthy with a steady feed and water plan.',
    baseProgress: 0.41,
    duration: '9 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Practical',
    icon: Icons.set_meal_rounded,
    imageAsset: AppAssets.uiFieldSprayer,
    overview:
        'Balanced feeding and clean water support growth, reduce stress, and help animals maintain condition across seasons. This guide also shows you how to match feed quality to age group, monitor grazing pressure, and spot when the feed program needs a correction.',
    steps: <String>[
      'Feed on the same schedule each day.',
      'Keep water clean and available.',
      'Adjust feed based on animal age and purpose.',
      'Watch body condition and appetite for changes.',
      'Move animals before overgrazing damages the pasture.',
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'feed-1',
        prompt: 'What supports animal growth most consistently?',
        options: <String>[
          'A steady feed and water routine',
          'Skipping water on hot days',
          'Changing feed every day without reason',
        ],
        correctOptionIndex: 0,
        explanation: 'Stable routines help animals stay healthy and reduce stress.',
      ),
      LessonQuestion(
        id: 'feed-2',
        prompt: 'What should you adjust feed to match?',
        options: <String>[
          'Animal age and purpose',
          'The color of the feed bag only',
          'The time the buyer arrives',
        ],
        correctOptionIndex: 0,
        explanation: 'Different age groups and uses need different feeding plans.',
      ),
      LessonQuestion(
        id: 'feed-3',
        prompt: 'What should be watched to spot feeding problems early?',
        options: <String>[
          'Body condition and appetite',
          'The number of buckets in the store',
          'The farm gate paint color',
        ],
        correctOptionIndex: 0,
        explanation: 'Body condition and appetite are early signs of feed or health issues.',
      ),
    ],
    tools: <String>[
      'Keep feed and water routine charts.',
      'Note appetite changes quickly.',
      'Track condition by group, not by guesswork.',
      'Rotate grazing areas where pasture recovery is slow.',
    ],
  ),
  LearningLesson(
    id: 'soil-fertility-compost',
    title: 'Soil fertility and compost',
    subtitle: 'Simple ways to improve soil strength with organic matter and nutrient planning.',
    baseProgress: 0.19,
    duration: '9 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.grass_rounded,
    imageAsset: AppAssets.uiLeafField,
    overview:
        'Learn how compost, manure, and basic soil observations help you build healthier fields over time. The lesson explains how to tell when soil is tired, how to feed it again, and why repeated crop removal without replacement weakens future yields.',
    steps: <String>[
      'Observe whether the soil looks loose, cracked, compacted, or dark and crumbly.',
      'Apply compost or manure that has been properly decomposed before planting.',
      'Rotate crops so the same nutrients are not pulled from one bed season after season.',
      'Keep a simple note of what each field received and when.',
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'soil-fertility-1',
        prompt: 'Why is properly decomposed manure better than fresh manure?',
        options: <String>[
          'It is safer for crops and easier to apply',
          'It removes all need for watering',
          'It makes the soil turn blue',
        ],
        correctOptionIndex: 0,
        explanation: 'Decomposed manure is less harsh on crops and easier to manage in the field.',
      ),
      LessonQuestion(
        id: 'soil-fertility-2',
        prompt: 'What helps prevent the same nutrients from being removed repeatedly?',
        options: <String>[
          'Crop rotation',
          'Ignoring the field notes',
          'Using the same bed forever',
        ],
        correctOptionIndex: 0,
        explanation: 'Crop rotation spreads nutrient demand across different plants and seasons.',
      ),
      LessonQuestion(
        id: 'soil-fertility-3',
        prompt: 'What does dark, crumbly soil often suggest?',
        options: <String>[
          'Better organic matter and structure',
          'A field that should never be used',
          'A crop that does not need roots',
        ],
        correctOptionIndex: 0,
        explanation: 'Dark, crumbly soil often means the soil is holding organic matter well.',
      ),
    ],
    tools: <String>[
      'Keep a compost maturity note before field application.',
      'Record which bed received manure or compost.',
      'Compare crop performance after each soil improvement cycle.',
    ],
  ),
  LearningLesson(
    id: 'seedling-nursery-management',
    title: 'Seedling nursery management',
    subtitle: 'Raise stronger seedlings before transplanting them to the main field.',
    baseProgress: 0.27,
    duration: '10 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.yard_rounded,
    imageAsset: AppAssets.uiFarmLandscape,
    overview:
        'Learn how to prepare nursery beds, water gently, and harden seedlings before transplanting. Strong nursery habits reduce transplant shock, improve survival rates, and make the crop more uniform in the main field.',
    steps: <String>[
      'Prepare a clean nursery bed with fine soil and good drainage.',
      'Water lightly so seeds and young roots are not washed away.',
      'Thin weak seedlings early so stronger plants have room to grow.',
      'Harden seedlings by reducing water gradually before transplanting.',
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'nursery-1',
        prompt: 'Why harden seedlings before transplanting?',
        options: <String>[
          'To reduce transplant shock',
          'To make them grow underground',
          'To stop them from needing sunlight',
        ],
        correctOptionIndex: 0,
        explanation: 'Hardening prepares seedlings for field conditions and improves survival.',
      ),
      LessonQuestion(
        id: 'nursery-2',
        prompt: 'What kind of watering is best in a nursery bed?',
        options: <String>[
          'Light watering that does not wash seeds away',
          'Flooding the bed every hour',
          'Never watering after planting',
        ],
        correctOptionIndex: 0,
        explanation: 'Gentle watering protects seeds and young plants from being displaced.',
      ),
      LessonQuestion(
        id: 'nursery-3',
        prompt: 'Why thin weak seedlings early?',
        options: <String>[
          'So stronger plants have room and nutrients',
          'To make the nursery look empty',
          'Because weak seedlings can never be counted',
        ],
        correctOptionIndex: 0,
        explanation: 'Thinning reduces competition and gives healthier seedlings a better start.',
      ),
    ],
    tools: <String>[
      'Use fine seedbed soil and clean watering tools.',
      'Label nursery rows with crop name and planting date.',
      'Track germination percentage and weak seedling removal.',
    ],
  ),
  LearningLesson(
    id: 'farm-biosecurity',
    title: 'Farm biosecurity routines',
    subtitle: 'Simple steps that stop disease from moving between animals, people, and equipment.',
    baseProgress: 0.22,
    duration: '11 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Essential',
    icon: Icons.health_and_safety_rounded,
    imageAsset: AppAssets.uiFieldSprayer,
    overview:
        'Biosecurity is the habit of keeping disease out of the farm and limiting spread when a problem appears. You will learn how to control visitors, clean equipment, isolate sick animals, and keep safe entry routines for workers and partners.',
    steps: <String>[
      'Limit unnecessary movement between pens, barns, and other farms.',
      'Clean tools, boots, and transport crates after risky contact.',
      'Isolate sick animals immediately and watch their feed and temperature.',
      'Record visitor entries and any unusual symptoms seen that day.',
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'biosecurity-1',
        prompt: 'What is the main purpose of biosecurity?',
        options: <String>[
          'To keep disease out and slow its spread',
          'To make the farm look busier',
          'To replace treatment completely',
        ],
        correctOptionIndex: 0,
        explanation: 'Biosecurity is about prevention and limiting spread, not replacing treatment.',
      ),
      LessonQuestion(
        id: 'biosecurity-2',
        prompt: 'What should happen when an animal looks sick?',
        options: <String>[
          'Isolate it and watch it closely',
          'Move it through every pen',
          'Ignore it until market day',
        ],
        correctOptionIndex: 0,
        explanation: 'Isolation helps protect the rest of the herd or flock from possible spread.',
      ),
      LessonQuestion(
        id: 'biosecurity-3',
        prompt: 'Why clean boots and tools after risky contact?',
        options: <String>[
          'To stop germs from moving around the farm',
          'To make them brighter',
          'To save space in the store',
        ],
        correctOptionIndex: 0,
        explanation: 'Cleaning equipment reduces the chance of carrying pathogens to new areas.',
      ),
    ],
    tools: <String>[
      'Keep a visitor log for animal areas.',
      'Use a separate cleaning area for dirty tools.',
      'Mark sick pens clearly so workers avoid cross-contact.',
    ],
  ),
];

const List<LearningTrack> _learningTracks = <LearningTrack>[
  LearningTrack(
    title: AppStrings.cropAdvice,
    icon: Icons.spa_rounded,
    detail: 'Crop care',
    color: Color(0xFFE9F4DB),
    summary: 'Crop planning, field care, growth stages, pest scouting, and harvest-readiness lessons.',
  ),
  LearningTrack(
    title: AppStrings.animalHealth,
    icon: Icons.pets_rounded,
    detail: 'Animal health',
    color: Color(0xFFFFEBD0),
    summary: 'Vaccination routines, hygiene, feeding, breeding, and disease response basics.',
  ),
  LearningTrack(
    title: AppStrings.soilManagement,
    icon: Icons.landscape_rounded,
    detail: 'Soil care',
    color: Color(0xFFDFF1FF),
    summary: 'Moisture, fertility, structure, erosion prevention, and practical soil observations.',
  ),
  LearningTrack(
    title: AppStrings.weatherForecast,
    icon: Icons.wb_sunny_outlined,
    detail: 'Weather planning',
    color: Color(0xFFFFF0C9),
    summary: 'Weather interpretation, timing decisions, and work planning around field conditions.',
  ),
  LearningTrack(
    title: 'Market access',
    icon: Icons.storefront_rounded,
    detail: 'Sales skills',
    color: Color(0xFFEDE8FF),
    summary: 'Market timing, buyer comparison, receipt records, procurement, and stock decisions.',
  ),
];

const List<PracticeActivity> _practiceActivities = <PracticeActivity>[
  PracticeActivity(
    id: 'field-checklist',
    title: 'Field checklist',
    subtitle: 'Walk crop rows and mark irrigation stress, weed pressure, and flowering changes.',
    icon: Icons.fact_check_rounded,
    color: Color(0xFFE8F4D8),
    whyItMatters:
        'Practice activities turn lessons into observable farm actions, so learning becomes part of daily work.',
    checklist: <String>[
      'Inspect wilting, yellowing, and pest pressure by section.',
      'Mark beds that need irrigation or mulching first.',
      'Note any flowering or fruit set changes in the log.',
    ],
  ),
  PracticeActivity(
    id: 'weekly-quiz',
    title: 'Weekly quiz',
    subtitle: 'A quick five-question check on disease prevention and livestock hygiene.',
    icon: Icons.quiz_rounded,
    color: Color(0xFFDFF1FF),
    whyItMatters:
        'Short quizzes help farmers remember practical details before a real disease or pest issue appears.',
    checklist: <String>[
      'Answer five short questions from this week\'s lessons.',
      'Review missed answers and reopen the related lesson.',
      'Set one improvement action for the next farm week.',
    ],
  ),
  PracticeActivity(
    id: 'community-notes',
    title: 'Community notes',
    subtitle: 'Save what worked on your farm so the next lesson stays practical.',
    icon: Icons.edit_note_rounded,
    color: Color(0xFFFFEBD0),
    whyItMatters:
        'Local notes make the learning hub more useful because they preserve what worked in your own conditions.',
    checklist: <String>[
      'Write one local practice that worked well this week.',
      'Attach yield, animal, or weather context to the note.',
      'Share lessons worth repeating next season.',
    ],
  ),
  PracticeActivity(
    id: 'market-review',
    title: 'Market review',
    subtitle: 'Compare last sale price, buyer reliability, transport cost, and remaining inventory.',
    icon: Icons.receipt_long_rounded,
    color: Color(0xFFEDE8FF),
    whyItMatters:
        'Market reviews help turn sales receipts into better pricing and procurement decisions.',
    checklist: <String>[
      'Review the last three sales receipts.',
      'Compare buyers by price, payment timing, and transport burden.',
      'Update inventory before planning the next harvest sale.',
    ],
  ),
];
