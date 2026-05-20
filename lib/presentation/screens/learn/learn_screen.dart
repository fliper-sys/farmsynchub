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
    final List<LearningLesson> lessons = _learningLessons;
    final List<PracticeActivity> activities = _practiceActivities;
    final int completedLessons = learning.completedLessons.length;
    final int completedPractices = learning.completedPractices.length;
    final int totalActions = lessons.length + activities.length;
    final int completedActions = completedLessons + completedPractices;
    final double progress = totalActions == 0 ? 0 : completedActions / totalActions;

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
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LessonCard(
                  lesson: lesson,
                  completed: completed,
                  progress: completed ? 1 : lesson.baseProgress,
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
    final bool completed = ref.watch(learningProvider).completedLessons.contains(lesson.id);

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
                  value: completed ? 'Completed' : 'In progress',
                  color: const Color(0xFFE8F4D8),
                ),
              ),
            ],
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
                  progress: learning.completedLessons.contains(lesson.id) ? 1 : lesson.baseProgress,
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
  final List<String> tools;
  final IconData icon;
  final String imageAsset;

  String get shareText {
    return 'FarmSync Learn: $title\n$subtitle\n\nTry this first: ${steps.first}';
  }
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
        'Learn how to observe moisture loss, match watering to crop stage, and avoid wasting labour or water in dry periods.',
    steps: <String>[
      'Check the top soil early in the morning before irrigation.',
      'Group beds by crop stage so young plants get priority water.',
      'Mulch exposed areas to slow surface drying.',
      'Record stress signs like curling leaves or blossom drop.',
    ],
    tools: <String>[
      'Use a simple soil squeeze test before watering.',
      'Create a two-column note: dry beds and stable beds.',
      'Log rainfall and irrigation dates after every field visit.',
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
        'Build a reliable vaccination routine, reduce avoidable disease losses, and keep cleaner treatment records for every group.',
    steps: <String>[
      'Keep a dated vaccine calendar by species and age group.',
      'Store vaccines correctly and avoid using expired doses.',
      'Separate treated animals so follow-up is easier to track.',
      'Log reactions, missed doses, and the next health action.',
    ],
    tools: <String>[
      'Create one health note per animal group.',
      'Keep provider phone numbers attached to procurement records.',
      'Set a weekly check for feed, water, housing, and symptoms.',
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
        'Compare timing, spoilage risk, transport cost, and demand signals so you can choose better selling windows.',
    steps: <String>[
      'Watch weekly price changes for your main produce.',
      'Estimate transport and handling before deciding to wait.',
      'Compare buyers by reliability, not just headline price.',
      'Match harvest planning to expected market demand peaks.',
    ],
    tools: <String>[
      'Record every sale receipt with buyer and product quantity.',
      'Compare three buyer prices before large sales.',
      'Track unsold stock in inventory after each market day.',
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
        'Use a repeatable scouting route to notice leaf damage, eggs, wilting, and disease patterns before yield is affected.',
    steps: <String>[
      'Walk a zig-zag route through the field instead of checking one edge.',
      'Inspect the underside of leaves for eggs and small larvae.',
      'Compare affected plants with healthy plants nearby.',
      'Take a clear photo and ask the AI advisor before treatment.',
    ],
    tools: <String>[
      'Carry a small notebook, phone camera, and hand lens if available.',
      'Record pest location by bed or section.',
      'Avoid spraying until the pest or disease signs are confirmed.',
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
        'Turn weather conditions into better daily decisions for spraying, irrigation, harvesting, drying, storage, and transport.',
    steps: <String>[
      'Avoid spraying before expected rainfall or strong wind.',
      'Harvest early when afternoon heat can reduce produce quality.',
      'Move feed and harvested produce under cover before heavy rain.',
      'Use humidity and soil moisture readings to adjust irrigation.',
    ],
    tools: <String>[
      'Check the dashboard weather card before field work.',
      'Group tasks into morning, afternoon, and rain-delay lists.',
      'Share weather-sensitive plans with workers before they leave.',
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
