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
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';
import 'lesson_certificate_screen.dart';

class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LearningState learning = ref.watch(learningProvider);
    final String query = _searchController.text.trim().toLowerCase();
    final List<LearningLesson> lessons = _learningLessons.where((LearningLesson lesson) {
      final String haystack = '${lesson.title} ${lesson.subtitle} ${lesson.overview} ${lesson.track} ${lesson.difficulty} ${lesson.steps.join(' ')} ${lesson.tools.join(' ')} ${lesson.questions.map((q) => '${q.prompt} ${q.options.join(' ')}').join(' ')}'.toLowerCase();
      if (query.isEmpty) return true;
      if (haystack.contains(query)) return true;
      final List<String> tokens = query.split(RegExp('\\\\s+')).where((t) => t.isNotEmpty).toList();
      return tokens.every((String token) => haystack.contains(token));
    }).toList(growable: false);
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
        leading: IconButton(
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
            'Lessons, practice work, saved progress, awards, shareable certificates, and field guides for crop, livestock, soil, weather, and finance topics.',
        heroIcon: Icons.menu_book_rounded,
        heroVariant: FarmArtworkVariant.field,
        heroBadge: '${learning.awardCount} awards earned',
        sections: <Widget>[
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: AppTextField(
                controller: _searchController,
                label: 'Search lessons',
                hint: 'Search by title, track, topic, or difficulty',
                prefix: const Icon(Icons.search_rounded),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(height: 18),
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
            title: lessons.length == _learningLessons.length ? AppStrings.continueLearning : 'Search results',
            action: Text(
              '$completedLessons completed',
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          if (lessons.isEmpty)
            AppCard(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Text('No lessons match your search. Try a different keyword or clear the search box.'),
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
    final ThemeData theme = Theme.of(context);
    final LearningState learning = ref.watch(learningProvider);
    final bool completed = learning.completedLessons.contains(lesson.id);
    final bool skipped = learning.skippedLessons.contains(lesson.id);
    final CertificateRecord? certificate = learning.certificateForLesson(lesson.id);
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
          if (lesson.youtubeVideoId != null) ...<Widget>[
            const SizedBox(height: 18),
            const SoftSectionTitle(title: 'Watch video'),
            AppCard(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: <Color>[
                            lesson.tint.withOpacity(0.96),
                            Color.alphaBlend(lesson.tint.withOpacity(0.58), theme.colorScheme.surface),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.24),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.play_circle_fill_rounded,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Video lesson',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Watch a short demonstration to reinforce the field steps.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withOpacity(0.92),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppButton.primary(
                      onPressed: () async {
                        await _launchExternalUrl(
                          'https://www.youtube.com/watch?v=${lesson.youtubeVideoId}',
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.ondemand_video_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Open in YouTube'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (lesson.websiteUrl != null) ...<Widget>[
            const SizedBox(height: 18),
            const SoftSectionTitle(title: 'Learn more'),
            AppCard(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Visit an external resource for additional details, images, and practical guidance.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    AppButton.secondary(
                      onPressed: () async {
                        await _launchExternalUrl(lesson.websiteUrl!);
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.open_in_new_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Visit website'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                          await ref.read(learningProvider.notifier).completeLesson(
                                lesson.id,
                                lessonTitle: lesson.title,
                              );
                          final CertificateRecord? record =
                              ref.read(learningProvider).certificateForLesson(lesson.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lesson completed. Award progress updated.')),
                            );
                            if (record != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => LessonCertificateScreen(
                                    record: record,
                                    recipientName: 'FarmSync learner',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  child: Text(completed ? 'Completed' : 'Mark complete'),
                ),
              ),
            ],
          ),
          if (certificate != null) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AppButton.secondary(
                onPressed: () => _openCertificate(context, certificate),
                child: const Text('View certificate'),
              ),
            ),
          ],
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

  void _openCertificate(BuildContext context, CertificateRecord certificate) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonCertificateScreen(
          record: certificate,
          recipientName: 'FarmSync learner',
        ),
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
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background = isDark ? Color.alphaBlend(color.withOpacity(0.24), theme.colorScheme.surface) : color;
    final Color foreground = isDark ? theme.colorScheme.onSurface : const Color(0xFF284231);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isDark ? color.withOpacity(0.44) : color.withOpacity(0.85)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
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
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color badgeColor = isDark ? Color.alphaBlend(tint.withOpacity(0.24), theme.colorScheme.surface) : tint;
    final Color badgeText = isDark ? theme.colorScheme.onSurface : AppColors.primary;

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
                color: badgeColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? tint.withOpacity(0.44) : tint.withOpacity(0.85)),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: badgeText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _launchExternalUrl(String url) async {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || !await canLaunchUrl(uri)) {
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    this.websiteUrl,
    this.youtubeVideoId,
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
  final String? websiteUrl;
  final String? youtubeVideoId;

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

final List<LearningLesson> _learningLessons = <LearningLesson>[
  const LearningLesson(
    id: 'soil-moisture',
    title: 'Managing soil moisture',
    subtitle: 'A short field guide for dry-season irrigation balance.',
    baseProgress: 0.72,
    duration: '8 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.water_drop_rounded,
    imageAsset: AppAssets.uiGallery01,
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
  const LearningLesson(
    id: 'livestock-vaccination',
    title: 'Livestock vaccination basics',
    subtitle: 'Simple health routines for smallholder teams.',
    baseProgress: 0.48,
    duration: '12 min',
    tint: Color(0xFFE9F4DB),
    track: AppStrings.animalHealth,
    difficulty: 'Essential',
    icon: Icons.pets_rounded,
    imageAsset: AppAssets.uiGallery02,
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
  const LearningLesson(
    id: 'market-timing',
    title: 'Reading market timing',
    subtitle: 'When to sell produce and when to hold stock a little longer.',
    baseProgress: 0.23,
    duration: '10 min',
    tint: Color(0xFFFFEBCF),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.storefront_rounded,
    imageAsset: AppAssets.uiGallery03,
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
  const LearningLesson(
    id: 'crop-pest-scouting',
    title: 'Crop pest scouting',
    subtitle: 'Spot pest pressure early before it spreads across beds.',
    baseProgress: 0.12,
    duration: '9 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.bug_report_rounded,
    imageAsset: AppAssets.uiGallery04,
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
  const LearningLesson(
    id: 'weather-work-plan',
    title: 'Weather-based work planning',
    subtitle: 'Use rain, temperature, and humidity to schedule farm tasks.',
    baseProgress: 0.18,
    duration: '7 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.weatherForecast,
    difficulty: 'Planning',
    icon: Icons.cloud_queue_rounded,
    imageAsset: AppAssets.uiGallery05,
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
  const LearningLesson(
    id: 'post-harvest-handling',
    title: 'Post-harvest handling',
    subtitle: 'Keep produce fresher from the field to the buyer.',
    baseProgress: 0.16,
    duration: '11 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Practical',
    icon: Icons.emoji_food_beverage_rounded,
    imageAsset: AppAssets.uiGallery06,
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
  const LearningLesson(
    id: 'record-keeping',
    title: 'Farm record keeping',
    subtitle: 'Build simple logs that improve decisions and finance access.',
    baseProgress: 0.34,
    duration: '10 min',
    tint: Color(0xFFDFF1FF),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.receipt_long_rounded,
    imageAsset: AppAssets.uiGallery07,
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
  const LearningLesson(
    id: 'feeding-and-grazing',
    title: 'Feeding and grazing routine',
    subtitle: 'Keep animals healthy with a steady feed and water plan.',
    baseProgress: 0.41,
    duration: '9 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Practical',
    icon: Icons.set_meal_rounded,
    imageAsset: AppAssets.uiGallery08,
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
  const LearningLesson(
    id: 'soil-fertility-compost',
    title: 'Soil fertility and compost',
    subtitle: 'Simple ways to improve soil strength with organic matter and nutrient planning.',
    baseProgress: 0.19,
    duration: '9 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.grass_rounded,
    imageAsset: AppAssets.uiGallery09,
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
  const LearningLesson(
    id: 'seedling-nursery-management',
    title: 'Seedling nursery management',
    subtitle: 'Raise stronger seedlings before transplanting them to the main field.',
    baseProgress: 0.27,
    duration: '10 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.yard_rounded,
    imageAsset: AppAssets.uiGallery10,
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
  const LearningLesson(
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
  const LearningLesson(
    id: 'drip-irrigation',
    title: 'Drip irrigation planning',
    subtitle: 'Schedule water more accurately and reduce waste on each bed.',
    baseProgress: 0.24,
    duration: '8 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.water_drop_outlined,
    imageAsset: AppAssets.uiSmartFarm,
    overview:
        'Plan irrigation around crop stage, bed spacing, and soil response so water reaches roots without unnecessary loss. The lesson also helps you track irrigation cycles, avoid overwatering, and spot blocked lines early.',
    steps: <String>[
      'Check the soil before every irrigation cycle instead of watering by guesswork.',
      'Group beds by crop stage so the driest or youngest plants can be served first.',
      'Inspect drip lines and emitters for blockages or leaks.',
      'Log each watering cycle so you can compare the field response later.',
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'drip-1',
        prompt: 'What should you check before every irrigation cycle?',
        options: <String>[
          'The soil condition',
          'The farm signboard',
          'The number of messages on your phone',
        ],
        correctOptionIndex: 0,
        explanation: 'Checking the soil helps you avoid watering when the crop does not need it.',
      ),
      LessonQuestion(
        id: 'drip-2',
        prompt: 'Why inspect drip lines regularly?',
        options: <String>[
          'To catch blockages or leaks early',
          'To make the pipes look new',
          'To replace crop scouting',
        ],
        correctOptionIndex: 0,
        explanation: 'Blocked or leaking lines reduce irrigation efficiency and can stress the crop.',
      ),
      LessonQuestion(
        id: 'drip-3',
        prompt: 'Why keep irrigation logs?',
        options: <String>[
          'To compare watering cycles and crop response later',
          'To avoid planning next week',
          'To replace harvest notes',
        ],
        correctOptionIndex: 0,
        explanation: 'Logs help you learn which irrigation schedule works best for the field.',
      ),
    ],
    tools: <String>[
      'Record irrigation date, time, and bed section.',
      'Keep a quick checklist for leaks and blocked emitters.',
      'Review water use after each weather change.',
    ],
  ),
  const LearningLesson(
    id: 'poultry-housing',
    title: 'Poultry housing and ventilation',
    subtitle: 'Keep birds cooler, cleaner, and easier to manage.',
    baseProgress: 0.31,
    duration: '9 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Practical',
    icon: Icons.egg_alt_rounded,
    imageAsset: AppAssets.uiLeafField,
    overview:
        'Good poultry housing lowers stress, supports feed efficiency, and reduces disease pressure. Learn how airflow, dryness, stocking density, and cleaning routines work together to keep birds healthier.',
    steps: <String>[
      'Keep litter dry and remove wet patches quickly.',
      'Make sure air can move through the house without direct drafts on chicks.',
      'Avoid overcrowding so birds can feed and rest comfortably.',
      'Clean feeders, drinkers, and corners on a regular schedule.',
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'poultry-1',
        prompt: 'What improves poultry comfort and health together?',
        options: <String>[
          'Good airflow and dry litter',
          'Dark corners and wet floors',
          'More crowding in the pen',
        ],
        correctOptionIndex: 0,
        explanation: 'Airflow and dryness reduce heat stress and disease pressure.',
      ),
      LessonQuestion(
        id: 'poultry-2',
        prompt: 'Why should overcrowding be avoided?',
        options: <String>[
          'Birds need space to feed and rest properly',
          'It makes eggs invisible',
          'It removes the need for water',
        ],
        correctOptionIndex: 0,
        explanation: 'Overcrowding increases stress and makes management harder.',
      ),
      LessonQuestion(
        id: 'poultry-3',
        prompt: 'What should be cleaned regularly in poultry housing?',
        options: <String>[
          'Feeders, drinkers, and corners',
          'The farm logo only',
          'The sales ledger',
        ],
        correctOptionIndex: 0,
        explanation: 'These areas can quickly build up dirt, waste, and disease risk.',
      ),
    ],
    tools: <String>[
      'Check house temperature and airflow daily.',
      'Remove wet bedding before it spreads.',
      'Record mortality, feed use, and water changes.',
    ],
  ),
  const LearningLesson(
    id: 'pricing-and-margin',
    title: 'Pricing and profit margins',
    subtitle: 'Turn sales records into better pricing decisions.',
    baseProgress: 0.21,
    duration: '8 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.price_change_rounded,
    imageAsset: AppAssets.uiProduceMarket,
    overview:
        'Learn how to calculate sale price, cost, and margin so your farm keeps more of the value it creates. This lesson helps you compare customer offers, understand transport costs, and avoid underpricing profitable goods.',
    steps: <String>[
      'Record the cost of production, packaging, and transport before pricing a product.',
      'Compare at least three buyers or channels before setting a large sale price.',
      'Track the margin on each batch, not just the sale amount.',
      'Use past receipts to identify the highest-value products and buyers.',
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'margin-1',
      prompt: 'What should you record before pricing a product?',
      options: <String>[
        'Production, packaging, and transport cost',
        'Only the farm name',
        'The buyers favorite color',
      ],
        correctOptionIndex: 0,
        explanation: 'Knowing the full cost helps prevent underpricing.',
      ),
      LessonQuestion(
        id: 'margin-2',
        prompt: 'Why compare three buyers or channels?',
        options: <String>[
          'To make a better pricing decision',
          'To increase paperwork only',
          'To avoid recording receipts',
        ],
        correctOptionIndex: 0,
        explanation: 'Comparing offers gives you a clearer picture of the best market option.',
      ),
      LessonQuestion(
        id: 'margin-3',
        prompt: 'What do receipts help you identify over time?',
        options: <String>[
          'High-value products and buyers',
          'The age of the notebook',
          'Who wore boots in the field',
        ],
        correctOptionIndex: 0,
        explanation: 'Receipt history highlights which products and buyers deliver better returns.',
      ),
    ],
    tools: <String>[
      'Keep a margin note with every major sale.',
      'Review transport cost before accepting low offers.',
      'Use price history when planning the next harvest sale.',
    ],
  ),
  // Additional compact lessons (100 entries)
  const LearningLesson(
    id: 'extra-001',
    title: 'Mulching basics',
    subtitle: 'How mulch conserves moisture and suppresses weeds.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.grass_rounded,
    imageAsset: AppAssets.uiGallery01,
    overview: 'Apply mulch to reduce evaporation, moderate soil temperature, and keep weeds from emerging close to stems.',
    steps: <String>['Spread 2-3cm of organic mulch evenly', 'Keep mulch pulled away from plant stems', 'Refresh when the surface layer starts to break down'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'mulch-1',
        prompt: 'Why is organic mulch used around crops?',
        options: <String>[
          'To retain moisture and suppress weeds',
          'To make the field look nicer',
          'To attract pests',
        ],
        correctOptionIndex: 0,
        explanation: 'Organic mulch helps keep soil moist and reduces weed pressure while adding organic matter as it decomposes.',
      ),
      LessonQuestion(
        id: 'mulch-2',
        prompt: 'What should you avoid when applying mulch?',
        options: <String>[
          'Piling mulch directly against stems',
          'Using leaves as mulch',
          'Covering the soil evenly',
        ],
        correctOptionIndex: 0,
        explanation: 'Mulch against stems can trap moisture and encourage rot or pests near the plant base.',
      ),
      LessonQuestion(
        id: 'mulch-3',
        prompt: 'When is it time to refresh mulch?',
        options: <String>[
          'When the top layer has broken down and thin spots appear',
          'After every rain shower',
          'Only at the end of the season',
        ],
        correctOptionIndex: 0,
        explanation: 'Mulch should be refreshed once it becomes thin so it continues to protect soil and conserve moisture.',
      ),
    ],
    tools: <String>['Mulch, rake', 'Gloves'],
  ),
  const LearningLesson(
    id: 'extra-002',
    title: 'Simple compost recipe',
    subtitle: 'Mix greens and browns for balanced compost.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.eco_rounded,
    imageAsset: AppAssets.uiGallery02,
    overview: 'Combine fresh green waste and dry brown material, keep the pile moist, and turn it weekly for even breakdown.',
    steps: <String>['Layer greens and browns in a pile', 'Keep the compost moist but not waterlogged', 'Turn the pile weekly to add air and speed decomposition'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'compost-1',
        prompt: 'What ratio of materials is best for compost?',
        options: <String>[
          'Mix greens and browns for balance',
          'Use only greens',
          'Use only dry waste',
        ],
        correctOptionIndex: 0,
        explanation: 'Balanced green and brown materials keep compost active without becoming too wet or smelly.',
      ),
      LessonQuestion(
        id: 'compost-2',
        prompt: 'Why should you turn compost weekly?',
        options: <String>[
          'To supply air and prevent compacted material',
          'To dry it out completely',
          'To scatter the seeds',
        ],
        correctOptionIndex: 0,
        explanation: 'Turning keeps the pile aerated and speeds decomposition by feeding microbes oxygen.',
      ),
      LessonQuestion(
        id: 'compost-3',
        prompt: 'How moist should compost be?',
        options: <String>[
          'Like a wrung-out sponge',
          'Saturated and dripping',
          'Dry and crumbly',
        ],
        correctOptionIndex: 0,
        explanation: 'A wrung-out sponge moisture level supports microbes without causing rot or odors.',
      ),
    ],
    tools: <String>['Pitchfork, water', 'Basket'],
  ),
  const LearningLesson(
    id: 'extra-003',
    title: 'Seed selection',
    subtitle: 'Choose varieties suited to your climate.',
    baseProgress: 0.05,
    duration: '6 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.cropAdvice,
    difficulty: 'Essential',
    icon: Icons.grass_rounded,
    imageAsset: AppAssets.uiGallery03,
    overview: 'Pick seeds with known performance in your region and market, and confirm they match your soil, season, and customer demand.',
    steps: <String>['Check days to maturity for your growing season', 'Confirm disease resistance for local pests', 'Choose a variety the market values'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'seed-1',
        prompt: 'What is the most important reason to match seed variety to your climate?',
        options: <String>[
          'To ensure the crop matures before adverse weather',
          'To make planting more expensive',
          'To reduce field work',
        ],
        correctOptionIndex: 0,
        explanation: 'Climate-matched seeds are more likely to mature successfully within the available season.',
      ),
      LessonQuestion(
        id: 'seed-2',
        prompt: 'Why check disease resistance before buying seed?',
        options: <String>[
          'It helps reduce losses and input costs',
          'It makes harvesting harder',
          'It lowers seed weight',
        ],
        correctOptionIndex: 0,
        explanation: 'Resistant varieties can lower the need for chemical treatments and reduce crop failure.',
      ),
      LessonQuestion(
        id: 'seed-3',
        prompt: 'Which factor is useful for market selection?',
        options: <String>[
          'Buyer preference and price demand',
          'Seed color only',
          'How small the seeds are',
        ],
        correctOptionIndex: 0,
        explanation: 'Buying seeds that meet market demand helps ensure sales and better prices.',
      ),
    ],
    tools: <String>['Seed catalog', 'Checklist'],
  ),
  const LearningLesson(
    id: 'extra-004',
    title: 'Watering schedule',
    subtitle: 'Establish a watering rhythm by crop stage.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.water_drop_rounded,
    imageAsset: AppAssets.uiGallery04,
    overview: 'Adjust the amount and timing of water as plants grow, weather changes, and roots deepen.',
    steps: <String>['Water young plants lightly daily', 'Check soil moisture before each irrigation', 'Reduce frequency as roots deepen and soil holds water longer'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'water-1',
        prompt: 'Why should young plants receive lighter watering?',
        options: <String>[
          'Because their roots are shallow and can be damaged by too much water',
          'Because they do not need water yet',
          'Because heavy watering saves time',
        ],
        correctOptionIndex: 0,
        explanation: 'Young plants have shallow roots and need careful moisture balance to avoid drowning or washing away.',
      ),
      LessonQuestion(
        id: 'water-2',
        prompt: 'What is the best way to decide when to water?',
        options: <String>[
          'Check the soil moisture before watering',
          'Always water every day',
          'Water only when the leaves are yellow',
        ],
        correctOptionIndex: 0,
        explanation: 'Soil moisture gives the most reliable sign of whether the crop needs irrigation.',
      ),
      LessonQuestion(
        id: 'water-3',
        prompt: 'How should watering change as crops mature?',
        options: <String>[
          'Reduce frequency as roots grow deeper',
          'Increase amount every day',
          'Stop watering completely',
        ],
        correctOptionIndex: 0,
        explanation: 'Mature crops with deeper roots can access more water and often need less frequent irrigation.',
      ),
    ],
    tools: <String>['Can, timer', 'Moisture probe'],
  ),
  const LearningLesson(
    id: 'extra-005',
    title: 'Field sanitation',
    subtitle: 'Simple cleaning habits to reduce disease.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFE9F4DB),
    track: AppStrings.animalHealth,
    difficulty: 'Essential',
    icon: Icons.cleaning_services_rounded,
    imageAsset: AppAssets.uiGallery05,
    overview: 'Keep fields and equipment clean to lower pest pressure and stop disease from spreading between plants or animals.',
    steps: <String>['Collect debris and burn or compost it away from crops', 'Clean tools after each use', 'Remove standing water where pests can breed'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'sanitation-1',
        prompt: 'What is a good sanitation habit after working in the field?',
        options: <String>[
          'Clean tools before using them again',
          'Leave tools covered in soil',
          'Share tools without cleaning',
        ],
        correctOptionIndex: 0,
        explanation: 'Cleaning tools helps prevent moving pests and disease from one area to another.',
      ),
      LessonQuestion(
        id: 'sanitation-2',
        prompt: 'Why remove crop debris from the field?',
        options: <String>[
          'To reduce pest and disease sources',
          'To make the farm look messy',
          'To provide shelter for insects',
        ],
        correctOptionIndex: 0,
        explanation: 'Debris can hide pests and disease organisms that attack the next crop.',
      ),
      LessonQuestion(
        id: 'sanitation-3',
        prompt: 'Which water source should be removed to improve sanitation?',
        options: <String>[
          'Standing water where pests may breed',
          'Running irrigation water',
          'Water stored in a clean tank',
        ],
        correctOptionIndex: 0,
        explanation: 'Standing water can become a breeding ground for mosquitoes and other pests.',
      ),
    ],
    tools: <String>['Brush, disinfectant', 'Gloves'],
  ),
  const LearningLesson(
    id: 'extra-006',
    title: 'Simple pruning',
    subtitle: 'When and how to prune for healthier plants.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.content_cut_rounded,
    imageAsset: AppAssets.uiGallery06,
    overview: 'Prune away dead or crowded branches to improve air movement, reduce disease risk, and help the plant focus energy on fruit or flower production.',
    steps: <String>['Cut back dead wood first', 'Thin crowded branches for light and air', 'Make clean cuts and avoid tearing bark'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'prune-1',
        prompt: 'What is a main benefit of pruning crowded branches?',
        options: <String>[
          'Improved air circulation and light penetration',
          'Making the plant smaller only',
          'Keeping pests hidden',
        ],
        correctOptionIndex: 0,
        explanation: 'Thinning crowded branches allows light and air to reach the plant, reducing disease pressure.',
      ),
      LessonQuestion(
        id: 'prune-2',
        prompt: 'Which branch should you remove first during pruning?',
        options: <String>[
          'Dead or diseased branches',
          'The healthiest branch',
          'The lowest branch only',
        ],
        correctOptionIndex: 0,
        explanation: 'Removing dead or diseased wood helps keep the rest of the plant healthy.',
      ),
      LessonQuestion(
        id: 'prune-3',
        prompt: 'Why are clean cuts important when pruning?',
        options: <String>[
          'They heal faster and lower infection risk',
          'They look better',
          'They make the plant grow slower',
        ],
        correctOptionIndex: 0,
        explanation: 'Clean cuts are less likely to tear and invite pests or disease into the plant.',
      ),
    ],
    tools: <String>['Pruner', 'Gloves'],
  ),
  const LearningLesson(
    id: 'extra-007',
    title: 'Seedbed preparation',
    subtitle: 'Basic steps for a fine seedbed and even germination.',
    baseProgress: 0.05,
    duration: '6 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.landscape_rounded,
    imageAsset: AppAssets.uiGallery07,
    overview: 'Create a smooth, firm seedbed so seeds are planted at an even depth and young roots can establish quickly.',
    steps: <String>['Clear debris and stones from the planting area', 'Level the seedbed and firm the surface gently', 'Check that the bed is not too compacted before sowing'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'seedbed-1',
        prompt: 'Why should a seedbed be firm but not compacted?',
        options: <String>[
          'It supports even seed depth and root growth',
          'It makes the soil dry faster',
          'It prevents any water from entering',
        ],
        correctOptionIndex: 0,
        explanation: 'A firm seedbed helps seeds stay at the right depth while still allowing roots and water to move through.',
      ),
      LessonQuestion(
        id: 'seedbed-2',
        prompt: 'What should be removed before planting seed?',
        options: <String>[
          'Stones and debris that block roots',
          'All moisture from the soil',
          'Nearby healthy plants',
        ],
        correctOptionIndex: 0,
        explanation: 'Stones and debris can create uneven planting depth and obstacles for young roots.',
      ),
      LessonQuestion(
        id: 'seedbed-3',
        prompt: 'How does a smooth seedbed help germination?',
        options: <String>[
          'It keeps seeds at an even depth for uniform sprouting',
          'It makes the soil hotter',
          'It stops weeds from growing forever',
        ],
        correctOptionIndex: 0,
        explanation: 'Even seed depth supports consistent moisture and temperature for all seeds.',
      ),
    ],
    tools: <String>['Rake, roller', 'Measuring stick'],
  ),
  const LearningLesson(
    id: 'extra-008',
    title: 'Basic grafting',
    subtitle: 'An introduction to simple grafting techniques.',
    baseProgress: 0.05,
    duration: '7 min',
    tint: Color(0xFFEDE8FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.handshake_rounded,
    imageAsset: AppAssets.uiGallery08,
    overview: 'Match a healthy scion and rootstock, make clean cuts, and keep the graft protected until it heals.',
    steps: <String>['Prepare matching scion and rootstock materials', 'Make clean, angled cuts for contact points', 'Bind and cover the graft to keep it clean and moist'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'graft-1',
        prompt: 'What is important when choosing scion and rootstock?',
        options: <String>[
          'They should match in size and species compatibility',
          'They should come from different countries',
          'They should be at different heights',
        ],
        correctOptionIndex: 0,
        explanation: 'Compatibility and clean contact points are essential for a successful graft union.',
      ),
      LessonQuestion(
        id: 'graft-2',
        prompt: 'Why are clean cuts used in grafting?',
        options: <String>[
          'They help the surfaces join and heal without infection',
          'They make the work look professional',
          'They keep the scion dry',
        ],
        correctOptionIndex: 0,
        explanation: 'Clean cuts improve contact and reduce the chance of disease at the graft site.',
      ),
      LessonQuestion(
        id: 'graft-3',
        prompt: 'How should a graft be finished after joining?',
        options: <String>[
          'Bind and protect it to keep it clean and moist',
          'Leave it open to air dry',
          'Cover it with loose soil',
        ],
        correctOptionIndex: 0,
        explanation: 'Protection helps the graft heal and prevents drying or contamination.',
      ),
    ],
    tools: <String>['Knife, tape', 'Wrapping material'],
  ),
  const LearningLesson(
    id: 'extra-009',
    title: 'Cover cropping',
    subtitle: 'Use cover crops to protect and feed the soil.',
    baseProgress: 0.05,
    duration: '6 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.nature_people_rounded,
    imageAsset: AppAssets.uiGallery09,
    overview: 'Sow cover plants between cash crops to protect soil, reduce erosion, and add organic matter.',
    steps: <String>['Select cover species that fit your climate', 'Plant soon after harvest', 'Manage the cover crop before it flowers and sets seed'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'cover-1',
        prompt: 'What is a main benefit of a cover crop?',
        options: <String>[
          'Protecting soil and adding organic matter',
          'Increasing weed pressure',
          'Making harvest harder',
        ],
        correctOptionIndex: 0,
        explanation: 'Cover crops protect the soil and improve fertility while the main crop is not growing.',
      ),
      LessonQuestion(
        id: 'cover-2',
        prompt: 'When is it best to sow a cover crop?',
        options: <String>[
          'Soon after the main crop is harvested',
          'During the main crop flowering stage',
          'After leaving the field empty all season',
        ],
        correctOptionIndex: 0,
        explanation: 'Planting after harvest gives the cover crop a full growing window to protect soil.',
      ),
      LessonQuestion(
        id: 'cover-3',
        prompt: 'Why manage the cover crop before it flowers?',
        options: <String>[
          'To prevent it from producing seed and becoming a weed',
          'To make it harder to remove later',
          'To keep it alive forever',
        ],
        correctOptionIndex: 0,
        explanation: 'Removing or mowing before seed set avoids creating a volunteer weed problem in the next season.',
      ),
    ],
    tools: <String>['Seeds, harrow', 'Spade'],
  ),
  const LearningLesson(
    id: 'extra-010',
    title: 'Simple disease ID',
    subtitle: 'Basic clues to separate pests, fungal, and nutrient problems.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.bug_report_rounded,
    imageAsset: AppAssets.uiGallery10,
    overview: 'Look for damage patterns, spread, and visible signs like pests or spores to help identify the likely cause.',
    steps: <String>['Inspect leaves and stems for patterns', 'Compare symptoms across plants', 'Check for visible pests or fungal growth'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'disease-1',
        prompt: 'What helps distinguish pest damage from disease?',
        options: <String>[
          'Pest damage often appears as chewing or holes, while disease can show spots or rot',
          'Disease always smells bad',
          'Pests only attack roots',
        ],
        correctOptionIndex: 0,
        explanation: 'Pest damage and disease often look different, with pests leaving bite marks and disease causing spots or decay.',
      ),
      LessonQuestion(
        id: 'disease-2',
        prompt: 'Why compare symptoms across multiple plants?',
        options: <String>[
          'To see if the issue is spreading and not just a single plant problem',
          'To make the field look checked',
          'To find the oldest plant',
        ],
        correctOptionIndex: 0,
        explanation: 'Comparing symptoms helps determine if the problem is general or isolated.',
      ),
      LessonQuestion(
        id: 'disease-3',
        prompt: 'Which sign suggests a fungal issue?',
        options: <String>[
          'Spots, powdery growth, or mold-like threads on tissues',
          'Perfect green leaves',
          'Only insect eggs are present',
        ],
        correctOptionIndex: 0,
        explanation: 'Fungal problems often produce visible spores, powdery surfaces, or mold.',
      ),
    ],
    tools: <String>['Magnifier, camera', 'Notebook'],
  ),
  const LearningLesson(
    id: 'extra-011',
    title: 'Fertilizer timing',
    subtitle: 'When to apply nutrients for best uptake.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFE9F4DB),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.grass_rounded,
    imageAsset: AppAssets.uiGallery01,
    overview: 'Apply fertilizer at the right growth stages so plants can use the nutrients instead of losing them to runoff or leaching.',
    steps: <String>['Identify the crop growth stage', 'Choose application method for the stage', 'Avoid fertilizing before heavy rain'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'fertilizer-1',
        prompt: 'Why is timing fertilizer important?',
        options: <String>[
          'To make sure plants are actively taking up nutrients',
          'To reduce the need for irrigation',
          'To make weeds grow faster',
        ],
        correctOptionIndex: 0,
        explanation: 'Fertilizer is most effective when plants are in a growth stage that can absorb the nutrients.',
      ),
      LessonQuestion(
        id: 'fertilizer-2',
        prompt: 'What should you avoid when applying fertilizer?',
        options: <String>[
          'Applying before heavy rain',
          'Applying once per season',
          'Using organic sources',
        ],
        correctOptionIndex: 0,
        explanation: 'Heavy rain can wash fertilizer away before plants use it, reducing efficiency.',
      ),
      LessonQuestion(
        id: 'fertilizer-3',
        prompt: 'Which method is good for young plants?',
        options: <String>[
          'Band or side-dress near the root zone',
          'Broadcast all over the field',
          'Mix in soil with no water',
        ],
        correctOptionIndex: 0,
        explanation: 'Targeted applications place nutrients where young roots can access them without wasting material.',
      ),
    ],
    tools: <String>['Spreader, hand trowel', 'Protective gloves'],
  ),
  const LearningLesson(
    id: 'extra-012',
    title: 'Mulch management',
    subtitle: 'When to renew or remove mulch.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.grass_rounded,
    imageAsset: AppAssets.uiGallery02,
    overview: 'Inspect mulch regularly, refresh patches that have broken down, and remove it when it starts to trap moisture or pests against plant stems.',
    steps: <String>['Inspect mulch every few weeks', 'Top up thin areas', 'Pull mulch away from stems'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'mulch-management-1',
        prompt: 'When should mulch be refreshed?',
        options: <String>[
          'When the surface becomes thin and patchy',
          'Only at the end of the season',
          'When it is still thick',
        ],
        correctOptionIndex: 0,
        explanation: 'Refreshing keeps mulch effective at conserving moisture and suppressing weeds.',
      ),
      LessonQuestion(
        id: 'mulch-management-2',
        prompt: 'Why should mulch be pulled away from plant stems?',
        options: <String>[
          'To prevent rot and pest hiding spots',
          'To make watering harder',
          'To reduce soil temperature',
        ],
        correctOptionIndex: 0,
        explanation: 'Mulch too close to stems can trap moisture and invite rot or pests.',
      ),
      LessonQuestion(
        id: 'mulch-management-3',
        prompt: 'What can indicate mulch is no longer effective?',
        options: <String>[
          'It has decomposed into thin layers',
          'It remains thick and cool',
          'It smells fresh',
        ],
        correctOptionIndex: 0,
        explanation: 'Decomposed mulch needs topping up to keep protecting the soil and suppressing weeds.',
      ),
    ],
    tools: <String>['Rake, mulch material'],
  ),
  const LearningLesson(
    id: 'extra-013',
    title: 'Basic irrigation checks',
    subtitle: 'Look for leaks and blockages that waste water.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Field skill',
    icon: Icons.water_drop_rounded,
    imageAsset: AppAssets.uiGallery03,
    overview: 'Walk irrigation lines regularly, look for leaking joints or blocked emitters, and repair problems before water is wasted.',
    steps: <String>['Inspect lines weekly', 'Clean or replace blocked emitters', 'Repair leaks promptly'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'irrigation-1',
        prompt: 'Why is it important to check irrigation lines often?',
        options: <String>[
          'To save water and keep crops evenly watered',
          'To make more work',
          'To change the water source',
        ],
        correctOptionIndex: 0,
        explanation: 'Regular checks prevent small issues from causing large water loss or uneven irrigation.',
      ),
      LessonQuestion(
        id: 'irrigation-2',
        prompt: 'What does a blocked emitter cause?',
        options: <String>[
          'Uneven water distribution',
          'Faster crop growth',
          'Cleaner water',
        ],
        correctOptionIndex: 0,
        explanation: 'Blocked emitters cause some plants to receive too little water while others get too much.',
      ),
      LessonQuestion(
        id: 'irrigation-3',
        prompt: 'What should you do when you find a leaking joint?',
        options: <String>[
          'Repair it quickly to avoid water loss',
          'Leave it until the next season',
          'Reduce water pressure only',
        ],
        correctOptionIndex: 0,
        explanation: 'Fixing leaks promptly conserves water and maintains proper irrigation pressure.',
      ),
    ],
    tools: <String>['Spare emitters, brush'],
  ),
  const LearningLesson(
    id: 'extra-014',
    title: 'Nursery watering',
    subtitle: 'Gentle methods to avoid washing seeds away.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.opacity_rounded,
    imageAsset: AppAssets.uiGallery04,
    overview: 'Use fine sprays or wick systems to keep nursery beds evenly moist without dislodging seeds or seedlings.',
    steps: <String>['Use a fine mist or gentle watering tool', 'Avoid heavy streams on seedlings', 'Water when topsoil begins to dry'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'nursery-1',
        prompt: 'What watering method is best for newly sown seeds?',
        options: <String>[
          'Fine mist or gentle watering',
          'Heavy hose stream',
          'No water at all',
        ],
        correctOptionIndex: 0,
        explanation: 'Gentle watering keeps seeds in place and maintains moist contact with the soil.',
      ),
      LessonQuestion(
        id: 'nursery-2',
        prompt: 'Why avoid heavy watering on seedlings?',
        options: <String>[
          'It can wash them away or compact the soil',
          'It makes them grow too fast',
          'It helps more oxygen enter the soil',
        ],
        correctOptionIndex: 0,
        explanation: 'Heavy watering can damage delicate seedlings and displace seeds or soil.',
      ),
      LessonQuestion(
        id: 'nursery-3',
        prompt: 'When should you water nursery beds?',
        options: <String>[
          'When the topsoil starts to feel slightly dry',
          'Every hour no matter what',
          'Only after the plants show wilting',
        ],
        correctOptionIndex: 0,
        explanation: 'Watering based on soil moisture prevents both drying out and overwatering.',
      ),
    ],
    tools: <String>['Sprayer, watering can with rose'],
  ),
  const LearningLesson(
    id: 'extra-015',
    title: 'Pest life cycles',
    subtitle: 'Know timings to interrupt pests effectively.',
    baseProgress: 0.05,
    duration: '6 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.bug_report_rounded,
    imageAsset: AppAssets.uiGallery05,
    overview: 'Observe the pest life cycle and focus control when pests are most vulnerable to minimize damage.',
    steps: <String>['Identify the current pest stage', 'Time control methods for vulnerable stages', 'Record observations for future timing'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'pestlife-1',
        prompt: 'Why should pest control be timed to the life cycle?',
        options: <String>[
          'Control is most effective at vulnerable stages',
          'It saves money on seed',
          'It increases plant growth',
        ],
        correctOptionIndex: 0,
        explanation: 'Targeting pests when they are weakest improves control and lowers inputs.',
      ),
      LessonQuestion(
        id: 'pestlife-2',
        prompt: 'Which pest stage is usually easiest to control?',
        options: <String>[
          'Immature or larval stages',
          'Adult flying stage',
          'Egg stage',
        ],
        correctOptionIndex: 0,
        explanation: 'Many pests are most vulnerable before they become adults or before they have hardened off.',
      ),
      LessonQuestion(
        id: 'pestlife-3',
        prompt: 'What helps improve future pest timing?',
        options: <String>[
          'Recording observations over time',
          'Using the same method every time',
          'Waiting until damage is severe',
        ],
        correctOptionIndex: 0,
        explanation: 'Records help you predict when pests will appear and when control is best applied.',
      ),
    ],
    tools: <String>['Notebook, camera'],
  ),
  const LearningLesson(
    id: 'extra-016',
    title: 'Fodder preservation',
    subtitle: 'Simple ways to store excess fodder for dry months.',
    baseProgress: 0.05,
    duration: '7 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Practical',
    icon: Icons.grass_rounded,
    imageAsset: AppAssets.uiGallery06,
    overview: 'Dry, bale, or ensile excess fodder so you have quality feed during lean seasons.',
    steps: <String>['Dry to a safe moisture level', 'Bale or store under cover', 'Protect from rodents and rain'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'fodder-1',
        prompt: 'Why should fodder be dried before storage?',
        options: <String>[
          'To prevent mold and spoilage',
          'To make it heavier',
          'To reduce its nutrient value',
        ],
        correctOptionIndex: 0,
        explanation: 'Dry fodder is less likely to rot and can be stored safely for longer.',
      ),
      LessonQuestion(
        id: 'fodder-2',
        prompt: 'What is an important storage step?',
        options: <String>[
          'Keep fodder covered and off the ground',
          'Expose it to rain',
          'Mix it with soil',
        ],
        correctOptionIndex: 0,
        explanation: 'Covering and elevating prevents water damage and pest entry.',
      ),
      LessonQuestion(
        id: 'fodder-3',
        prompt: 'Why protect stored fodder from rodents?',
        options: <String>[
          'Rodents can eat and contaminate the feed',
          'Rodents help aerate it',
          'Rodents act as fertilizer',
        ],
        correctOptionIndex: 0,
        explanation: 'Rodents damage and contaminate stored feed, reducing its value and safety.',
      ),
    ],
    tools: <String>['Baler, tarpaulin'],
  ),
  const LearningLesson(
    id: 'extra-017',
    title: 'Basic pond care',
    subtitle: 'Maintain small irrigation or fish ponds.',
    baseProgress: 0.05,
    duration: '6 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.weatherForecast,
    difficulty: 'Practical',
    icon: Icons.water_rounded,
    imageAsset: AppAssets.uiGallery07,
    overview: 'Keep pond water clean, remove weeds, and check inflow and outflow so the system stays balanced.',
    steps: <String>['Remove weeds and floating debris', 'Check inlet and outlet flow', 'Top up water level if needed'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'pond-1',
        prompt: 'What is one pond maintenance task?',
        options: <String>[
          'Remove weeds and debris',
          'Drain the pond every day',
          'Add fertilizer to the water',
        ],
        correctOptionIndex: 0,
        explanation: 'Clearing weeds and debris keeps water moving and prevents clogging.',
      ),
      LessonQuestion(
        id: 'pond-2',
        prompt: 'Why check inlet and outlet flow?',
        options: <String>[
          'To ensure water circulates and does not stagnate',
          'To reduce evaporation only',
          'To waste water',
        ],
        correctOptionIndex: 0,
        explanation: 'Good flow prevents stagnation and maintains water quality.',
      ),
      LessonQuestion(
        id: 'pond-3',
        prompt: 'When might you top up a pond?',
        options: <String>[
          'When water levels fall below the normal line',
          'Whenever the surface is windy',
          'Only during harvest',
        ],
        correctOptionIndex: 0,
        explanation: 'Maintaining normal water level helps the pond system stay stable and functional.',
      ),
    ],
    tools: <String>['Net, pump'],
  ),
  const LearningLesson(
    id: 'extra-018',
    title: 'Shade management',
    subtitle: 'Use shade to reduce heat stress for sensitive crops.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFEDE8FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.sunny_snowing,
    imageAsset: AppAssets.uiGallery08,
    overview: 'Reduce heat stress by assessing sun exposure and installing temporary shade or using natural shade trees.',
    steps: <String>['Assess crop sun exposure', 'Install shade cloth or structures', 'Monitor plant response'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'shade-1',
        prompt: 'What is the main benefit of shade for sensitive crops?',
        options: <String>[
          'Reduced heat stress and sun damage',
          'Faster drying of leaves',
          'Less growth',
        ],
        correctOptionIndex: 0,
        explanation: 'Shade helps crops avoid heat damage and keeps them cooler during hot periods.',
      ),
      LessonQuestion(
        id: 'shade-2',
        prompt: 'What should you do after installing shade?',
        options: <String>[
          'Monitor how the crop responds',
          'Remove it immediately',
          'Water less often only',
        ],
        correctOptionIndex: 0,
        explanation: 'Monitoring ensures the shade is helping and not causing too much coolness or dampness.',
      ),
      LessonQuestion(
        id: 'shade-3',
        prompt: 'Which is a simple way to provide shade?',
        options: <String>[
          'Use shade cloth or temporary structures',
          'Paint leaves',
          'Add fertilizer',
        ],
        correctOptionIndex: 0,
        explanation: 'Shade cloth and structures are practical ways to reduce direct sunlight on crops.',
      ),
    ],
    tools: <String>['Shade cloth, poles'],
  ),
  const LearningLesson(
    id: 'extra-019',
    title: 'Simple record summaries',
    subtitle: 'Turn weekly notes into short action points.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFE9F4DB),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.receipt_long_rounded,
    imageAsset: AppAssets.uiGallery09,
    overview: 'Review weekly notes, identify the most important insights, and list three clear actions to take next week.',
    steps: <String>['List the top findings', 'Decide three actions', 'Assign responsibility'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'summary-1',
        prompt: 'What is the goal of a weekly record summary?',
        options: <String>[
          'Turn observations into clear actions',
          'Write a long report',
          'Ignore the notes',
        ],
        correctOptionIndex: 0,
        explanation: 'Summaries help turn raw observations into practical actions and decisions.',
      ),
      LessonQuestion(
        id: 'summary-2',
        prompt: 'How many action points should you set?',
        options: <String>[
          'Three clear actions',
          'Ten vague tasks',
          'None',
        ],
        correctOptionIndex: 0,
        explanation: 'A short list of actions is easier to follow and complete.',
      ),
      LessonQuestion(
        id: 'summary-3',
        prompt: 'Why assign responsibility for each action?',
        options: <String>[
          'So someone is accountable for doing it',
          'So no one knows the tasks',
          'So the task is forgotten',
        ],
        correctOptionIndex: 0,
        explanation: 'Assigning responsibility increases the chances that actions are completed.',
      ),
    ],
    tools: <String>['Notebook, pen'],
  ),
  const LearningLesson(
    id: 'extra-020',
    title: 'Seed storage basics',
    subtitle: 'Keep seeds viable between seasons.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.save_rounded,
    imageAsset: AppAssets.uiGallery10,
    overview: 'Store seeds dry, cool, and sealed to maintain viability until planting season.',
    steps: <String>['Dry seeds thoroughly', 'Store in airtight containers', 'Keep containers cool and dry'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'seedstorage-1',
        prompt: 'Why should seeds be stored dry?',
        options: <String>[
          'To prevent mold and loss of viability',
          'To make them heavier',
          'To make them germinate early',
        ],
        correctOptionIndex: 0,
        explanation: 'Moisture can cause seeds to rot or sprout prematurely in storage.',
      ),
      LessonQuestion(
        id: 'seedstorage-2',
        prompt: 'What is a good storage container for seeds?',
        options: <String>[
          'Airtight container with desiccant',
          'Open basket',
          'Wet cloth bag',
        ],
        correctOptionIndex: 0,
        explanation: 'Airtight containers keep moisture out and protect seeds from pests.',
      ),
      LessonQuestion(
        id: 'seedstorage-3',
        prompt: 'Where should seed containers be kept?',
        options: <String>[
          'Cool and dry place',
          'In direct sunlight',
          'Next to the stove',
        ],
        correctOptionIndex: 0,
        explanation: 'Cool, dry storage maintains seed quality and slows deterioration.',
      ),
    ],
    tools: <String>['Jars, desiccant'],
  ),
  const LearningLesson(
    id: 'extra-021',
    title: 'Weed prioritization',
    subtitle: 'Which weeds to remove first and why.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.grass_rounded,
    imageAsset: AppAssets.uiGallery01,
    overview: 'Focus on removing competitive and perennial weeds first so your crop can get the most light, water, and nutrients.',
    steps: <String>['Identify the most competitive weed species', 'Remove them before they set seed', 'Monitor for regrowth'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'weed-1',
        prompt: 'Which weeds should you remove first?',
        options: <String>[
          'Competitive and perennial weeds',
          'Only small grasses',
          'Weeds near the field edge',
        ],
        correctOptionIndex: 0,
        explanation: 'Competitive and perennial weeds cause the most damage over time and should be removed early.',
      ),
      LessonQuestion(
        id: 'weed-2',
        prompt: 'Why remove weeds before they set seed?',
        options: <String>[
          'To reduce future weed pressure',
          'To make the field look clean',
          'To add more seed to the soil',
        ],
        correctOptionIndex: 0,
        explanation: 'Removing weeds before seed production stops the weed population from increasing.',
      ),
      LessonQuestion(
        id: 'weed-3',
        prompt: 'What is a useful follow-up after removing weeds?',
        options: <String>[
          'Monitor for regrowth',
          'Leave the area alone',
          'Plant immediately without preparation',
        ],
        correctOptionIndex: 0,
        explanation: 'Weeds often regrow, so monitoring helps you remove new shoots quickly.',
      ),
    ],
    tools: <String>['Hoe, gloves'],
  ),
  const LearningLesson(
    id: 'extra-022',
    title: 'Cold protection',
    subtitle: 'Protect tender crops from unexpected cold spells.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFEDE8FF),
    track: AppStrings.weatherForecast,
    difficulty: 'Practical',
    icon: Icons.ac_unit_rounded,
    imageAsset: AppAssets.uiGallery02,
    overview: 'Use covers, mulch, or water to moderate soil and air temperature when frost or cold nights are expected.',
    steps: <String>['Cover crops at night', 'Add mulch around roots', 'Use light irrigation for frost protection when safe'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'cold-1',
        prompt: 'What is a good method to protect crops from a cold night?',
        options: <String>[
          'Use covers or frost cloth',
          'Water heavily during the day',
          'Prune the plants',
        ],
        correctOptionIndex: 0,
        explanation: 'Covers trap heat near the plant and reduce exposure to frost.',
      ),
      LessonQuestion(
        id: 'cold-2',
        prompt: 'Why add mulch around roots in cold weather?',
        options: <String>[
          'To insulate soil and protect roots',
          'To make the soil colder',
          'To keep weeds out only',
        ],
        correctOptionIndex: 0,
        explanation: 'Mulch helps keep soil temperature stable and protects roots from frost.',
      ),
      LessonQuestion(
        id: 'cold-3',
        prompt: 'When is irrigation useful for frost protection?',
        options: <String>[
          'When it is safe and can release latent heat as it freezes',
          'When it is windy',
          'When the soil is already saturated',
        ],
        correctOptionIndex: 0,
        explanation: 'A light protective irrigation can release heat as water freezes, helping protect plants.',
      ),
    ],
    tools: <String>['Covers, sprinkler'],
  ),
  const LearningLesson(
    id: 'extra-023',
    title: 'Basic bee management',
    subtitle: 'Support pollinators and protect hives.',
    baseProgress: 0.05,
    duration: '6 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.brightness_5_rounded,
    imageAsset: AppAssets.uiGallery03,
    overview: 'Provide water, a diversity of flowers, and gentle handling to help bees thrive and pollinate your farm.',
    steps: <String>['Offer clean water sources', 'Plant different flowering species', 'Avoid spraying insecticides when bees are active'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'bee-1',
        prompt: 'What helps support bees on the farm?',
        options: <String>[
          'Providing water and flowers',
          'Spraying pesticides daily',
          'Removing all wild plants',
        ],
        correctOptionIndex: 0,
        explanation: 'Bees need water and a variety of flowers to forage throughout the season.',
      ),
      LessonQuestion(
        id: 'bee-2',
        prompt: 'Why avoid spraying insecticides when bees are active?',
        options: <String>[
          'To prevent harming pollinators',
          'Because it does not affect pests',
          'To keep the crop wet',
        ],
        correctOptionIndex: 0,
        explanation: 'Bees can be harmed by insecticides, so spraying when they are inactive is safer.',
      ),
      LessonQuestion(
        id: 'bee-3',
        prompt: 'What is a useful habitat feature for bees?',
        options: <String>[
          'A variety of flowering plants',
          'Only one flower type',
          'No water source',
        ],
        correctOptionIndex: 0,
        explanation: 'Different flowers provide nectar and pollen at different times of the season.',
      ),
    ],
    tools: <String>['Bee veil, smoker'],
  ),
  const LearningLesson(
    id: 'extra-024',
    title: 'Crop rotation basics',
    subtitle: 'Rotate families to break pest and disease cycles.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Business',
    icon: Icons.sync_alt_rounded,
    imageAsset: AppAssets.uiGallery04,
    overview: 'Plan crop rotations to balance nutrients, reduce pests and diseases, and improve soil health over time.',
    steps: <String>['Choose different crop families for successive seasons', 'Avoid planting the same crop in the same bed two years in a row', 'Record past crops and rotation plans'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'rotation-1',
        prompt: 'Why rotate crops by family?',
        options: <String>[
          'To break pest and disease cycles',
          'To use more fertilizer',
          'To make harvest easier',
        ],
        correctOptionIndex: 0,
        explanation: 'Different crop families host different pests and use nutrients differently, so rotation helps reduce problems.',
      ),
      LessonQuestion(
        id: 'rotation-2',
        prompt: 'What is a good record to keep for rotation?',
        options: <String>[
          'Last crop grown in each bed',
          'Only the weather',
          'How many weeds were pulled',
        ],
        correctOptionIndex: 0,
        explanation: 'Knowing what was grown where helps plan effective rotations and avoid repeated problems.',
      ),
      LessonQuestion(
        id: 'rotation-3',
        prompt: 'What is a risk of not rotating crops?',
        options: <String>[
          'Pest and disease build-up',
          'Better soil health',
          'Faster growth',
        ],
        correctOptionIndex: 0,
        explanation: 'Without rotation, pests, diseases, and nutrient depletion can increase in a bed.',
      ),
    ],
    tools: <String>['Planner, calendar'],
  ),
  const LearningLesson(
    id: 'extra-025',
    title: 'Small ruminant care',
    subtitle: 'Basic husbandry for goats and sheep.',
    baseProgress: 0.05,
    duration: '6 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Practical',
    icon: Icons.pets_rounded,
    imageAsset: AppAssets.uiGallery05,
    overview: 'Provide clean water, balanced feed, and regular health checks to keep goats and sheep productive and healthy.',
    steps: <String>['Check hooves and coat condition regularly', 'Offer clean water daily', 'Provide mineral supplements as needed'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'ruminant-1',
        prompt: 'What is a key daily care habit for small ruminants?',
        options: <String>[
          'Provide clean water daily',
          'Only feed once a week',
          'Keep them in the dark',
        ],
        correctOptionIndex: 0,
        explanation: 'Clean water is essential to health and digestion in goats and sheep.',
      ),
      LessonQuestion(
        id: 'ruminant-2',
        prompt: 'Why check hooves regularly?',
        options: <String>[
          'To prevent foot problems and lameness',
          'To make them look tidy',
          'To slow their movement',
        ],
        correctOptionIndex: 0,
        explanation: 'Hoof problems can cause pain and reduce mobility, so regular checks prevent issues.',
      ),
      LessonQuestion(
        id: 'ruminant-3',
        prompt: 'What is the role of mineral supplements?',
        options: <String>[
          'To provide lacking minerals for health',
          'To make the feed look better',
          'To replace water',
        ],
        correctOptionIndex: 0,
        explanation: 'Mineral supplements fill nutritional gaps that can affect growth and reproduction.',
      ),
    ],
    tools: <String>['Hoof trimmer, mineral block'],
  ),
  const LearningLesson(
    id: 'extra-026',
    title: 'Simple greenhouse checks',
    subtitle: 'Ventilation, shading, and irrigation basics.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFEDE8FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.king_bed_rounded,
    imageAsset: AppAssets.uiGallery06,
    overview: 'Check greenhouse ventilation, shading, and irrigation distribution daily to keep conditions stable and crops healthy.',
    steps: <String>['Open vents when it gets hot', 'Adjust shade when light is intense', 'Ensure drip lines or hoses are delivering evenly'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'greenhouse-1',
        prompt: 'Why is ventilation important in a greenhouse?',
        options: <String>[
          'To control temperature and humidity',
          'To keep the doors closed',
          'To add pests',
        ],
        correctOptionIndex: 0,
        explanation: 'Good ventilation prevents overheating and reduces disease risk in greenhouse crops.',
      ),
      LessonQuestion(
        id: 'greenhouse-2',
        prompt: 'What should you check about irrigation inside a greenhouse?',
        options: <String>[
          'That water is reaching all plants evenly',
          'That it is only applied once a month',
          'That it is always cold',
        ],
        correctOptionIndex: 0,
        explanation: 'Even water distribution avoids dry spots and overwatered areas.',
      ),
      LessonQuestion(
        id: 'greenhouse-3',
        prompt: 'When should shade be adjusted?',
        options: <String>[
          'When light is too intense for the crop',
          'Only in winter',
          'When the greenhouse is empty',
        ],
        correctOptionIndex: 0,
        explanation: 'Shade helps protect crops from intense sun and keeps temperatures more stable.',
      ),
    ],
    tools: <String>['Thermometer, hygrometer'],
  ),
  const LearningLesson(
    id: 'extra-027',
    title: 'Nursery sanitation',
    subtitle: 'Prevent disease in the seedling stage.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Essential',
    icon: Icons.cleaning_services_rounded,
    imageAsset: AppAssets.uiGallery07,
    overview: 'Sanitize nursery trays and tools, keep spacing between seedlings, and remove infected plants quickly.',
    steps: <String>['Sanitize trays and tools before use', 'Space seedlings to improve air circulation', 'Remove any diseased seedlings immediately'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'nursery-2-1',
        prompt: 'Why sanitize nursery trays?',
        options: <String>[
          'To prevent disease spread among seedlings',
          'To make them shiny',
          'To keep water from soaking in',
        ],
        correctOptionIndex: 0,
        explanation: 'Sanitizing reduces the chance that pathogens will infect young seedlings.',
      ),
      LessonQuestion(
        id: 'nursery-2-2',
        prompt: 'What is a benefit of spacing seedlings?',
        options: <String>[
          'Better air circulation and lower disease risk',
          'More crowding and shade',
          'Less growth',
        ],
        correctOptionIndex: 0,
        explanation: 'Proper spacing keeps humidity lower and reduces the spread of disease.',
      ),
      LessonQuestion(
        id: 'nursery-2-3',
        prompt: 'What should you do with diseased seedlings?',
        options: <String>[
          'Remove them immediately',
          'Leave them to recover',
          'Water them more',
        ],
        correctOptionIndex: 0,
        explanation: 'Removing diseased plants stops infection from spreading to healthy seedlings.',
      ),
    ],
    tools: <String>['Bleach solution, trays'],
  ),
  const LearningLesson(
    id: 'extra-028',
    title: 'Basic soil testing',
    subtitle: 'When to test and what simple tests tell you.',
    baseProgress: 0.05,
    duration: '6 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.science_rounded,
    imageAsset: AppAssets.uiGallery08,
    overview: 'Take representative soil samples and use pH or kit tests to guide whether lime, fertilizer, or organic matter are needed.',
    steps: <String>['Collect samples from several spots', 'Label and test or send to a lab', 'Record the results for future comparison'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'soiltest-1',
        prompt: 'Why collect samples from several spots?',
        options: <String>[
          'To get a representative result for the area',
          'To make more work',
          'To increase soil moisture',
        ],
        correctOptionIndex: 0,
        explanation: 'Multiple samples reduce the chance that one unusual spot will skew the results.',
      ),
      LessonQuestion(
        id: 'soiltest-2',
        prompt: 'What can a pH test tell you?',
        options: <String>[
          'Whether soil is acidic or alkaline',
          'How many worms there are',
          'The exact amount of nitrogen',
        ],
        correctOptionIndex: 0,
        explanation: 'Soil pH affects nutrient availability and helps decide whether liming or acidifying is needed.',
      ),
      LessonQuestion(
        id: 'soiltest-3',
        prompt: 'Why record soil test results?',
        options: <String>[
          'To compare changes over time and track amendments',
          'To throw the paper away later',
          'To avoid testing again',
        ],
        correctOptionIndex: 0,
        explanation: 'Keeping records helps you see whether management steps are improving soil health.',
      ),
    ],
    tools: <String>['Soil probe, kit'],
  ),
  const LearningLesson(
    id: 'extra-029',
    title: 'Simple pruning for productivity',
    subtitle: 'Prune to encourage fruiting and airflow.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFE9F4DB),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.content_cut_rounded,
    imageAsset: AppAssets.uiGallery09,
    overview: 'Remove crowded shoots and crossing branches to improve airflow, light, and fruit quality.',
    steps: <String>['Thin crowded shoots', 'Remove crossing branches', 'Leave the strongest shoots'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'prune-prod-1',
        prompt: 'What is a main reason to prune for productivity?',
        options: <String>[
          'To improve airflow and fruit quality',
          'To make the plant shorter only',
          'To increase the number of shoots',
        ],
        correctOptionIndex: 0,
        explanation: 'Pruning removes crowded growth and helps the best shoots develop better fruit.',
      ),
      LessonQuestion(
        id: 'prune-prod-2',
        prompt: 'Which branches should you remove when pruning for productivity?',
        options: <String>[
          'Crossing and weak branches',
          'Only the strongest branches',
          'Roots visible above ground',
        ],
        correctOptionIndex: 0,
        explanation: 'Crossing and weak growth reduce airflow and take energy from the best shoots.',
      ),
      LessonQuestion(
        id: 'prune-prod-3',
        prompt: 'What should remain after pruning?',
        options: <String>[
          'The strongest, healthiest shoots',
          'All branches',
          'Only the oldest stems',
        ],
        correctOptionIndex: 0,
        explanation: 'Leaving the best shoots helps the plant focus resources on quality production.',
      ),
    ],
    tools: <String>['Pruner'],
  ),
  const LearningLesson(
    id: 'extra-030',
    title: 'Transport packing tips',
    subtitle: 'Pack to reduce damage during transport.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.local_shipping_rounded,
    imageAsset: AppAssets.uiGallery10,
    overview: 'Use padding, avoid overstacking, and separate varieties so produce arrives in market-ready condition.',
    steps: <String>['Pad crates and boxes', 'Avoid overstacking', 'Separate fragile items'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'packing-1',
        prompt: 'Why is padding important for transport?',
        options: <String>[
          'It protects produce from bruising',
          'It makes crates heavier',
          'It reduces air flow',
        ],
        correctOptionIndex: 0,
        explanation: 'Padding cushions produce and prevents damage from movement.',
      ),
      LessonQuestion(
        id: 'packing-2',
        prompt: 'What is a risk of overstacking crates?',
        options: <String>[
          'Crushing produce below',
          'Faster cooling',
          'Less space used',
        ],
        correctOptionIndex: 0,
        explanation: 'Too much weight from overstacking can bruise or crush produce underneath.',
      ),
      LessonQuestion(
        id: 'packing-3',
        prompt: 'Why separate fragile items?',
        options: <String>[
          'To prevent them from being damaged by heavier produce',
          'To mix all goods together',
          'To make loading faster',
        ],
        correctOptionIndex: 0,
        explanation: 'Separating fragile items reduces the chance of damage during transport.',
      ),
    ],
    tools: <String>['Padding, crates'],
  ),
  const LearningLesson(
    id: 'extra-031',
    title: 'Winter feed planning',
    subtitle: 'Estimate winter feed needs and secure supplies early.',
    baseProgress: 0.05,
    duration: '6 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Business',
    icon: Icons.calendar_today_rounded,
    imageAsset: AppAssets.uiGallery01,
    overview: 'Calculate herd feed needs through the dry season and source or conserve fodder well before shortages occur.',
    steps: <String>['Count herd size and type', 'Multiply by daily intake needed', 'Secure supply or grow cover crops', 'Store in covered area'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'winterfeed-1',
        prompt: 'Why plan winter feed before the dry season?',
        options: <String>[
          'To avoid running short and losing animals',
          'Because feed is cheaper in dry season',
          'To reduce the need for water',
        ],
        correctOptionIndex: 0,
        explanation: 'Planning ahead ensures feed is available when pasture is scarce.',
      ),
      LessonQuestion(
        id: 'winterfeed-2',
        prompt: 'What is the first step in winter feed planning?',
        options: <String>[
          'Estimate daily intake by counting herd size',
          'Buy all feed at once',
          'Stop feeding in winter',
        ],
        correctOptionIndex: 0,
        explanation: 'Knowing your herd size and intake helps calculate total needs.',
      ),
      LessonQuestion(
        id: 'winterfeed-3',
        prompt: 'Which is a good storage location for winter feed?',
        options: <String>[
          'Dry, covered area away from rodents',
          'In open field in the sun',
          'In water to keep it fresh',
        ],
        correctOptionIndex: 0,
        explanation: 'Dry storage keeps feed from spoiling and protects it from pests.',
      ),
    ],
    tools: <String>['Calculator, notes'],
    youtubeVideoId: 'cFLC1j9ebfA',
    websiteUrl: 'https://www.fao.org/3/i3661e/i3661e.pdf',
  ),
  const LearningLesson(
    id: 'extra-032',
    title: 'Bee-friendly planting',
    subtitle: 'Plants that attract pollinators to your farm.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.filter_vintage_rounded,
    imageAsset: AppAssets.uiGallery02,
    overview: 'Plant a variety of flowering species that bloom at different times to provide continuous nectar for bees.',
    steps: <String>['Choose early, mid, and late blooming plants', 'Plant in clusters', 'Avoid pesticides during bloom', 'Provide water'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'beeplant-1',
        prompt: 'Why plant multiple flowering species?',
        options: <String>[
          'To provide nectar throughout the season',
          'To make the farm look pretty',
          'To reduce pollination',
        ],
        correctOptionIndex: 0,
        explanation: 'Different plants bloom at different times, giving bees consistent food.',
      ),
      LessonQuestion(
        id: 'beeplant-2',
        prompt: 'What is a key point about bee-friendly planting?',
        options: <String>[
          'Avoid spraying pesticides when flowers are blooming',
          'Use pesticides to kill competing insects',
          'Keep flowers away from crops',
        ],
        correctOptionIndex: 0,
        explanation: 'Pesticides harm bees, so spraying during bloom risks bee populations.',
      ),
      LessonQuestion(
        id: 'beeplant-3',
        prompt: 'How should flowering plants be arranged?',
        options: <String>[
          'Plant in clusters for easy access',
          'Spread single plants everywhere',
          'Plant only one type',
        ],
        correctOptionIndex: 0,
        explanation: 'Clusters help bees find and forage more efficiently.',
      ),
    ],
    tools: <String>['Seeds, water source'],
    youtubeVideoId: '2BJ-CyVtbNQ',
    websiteUrl: 'https://www.pollinator.org/guides/creating-habitat',
  ),
  const LearningLesson(
    id: 'extra-033',
    title: 'Simple graft care',
    subtitle: 'Protect grafts during the first weeks.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.healing_rounded,
    imageAsset: AppAssets.uiGallery03,
    overview: 'Grafts are vulnerable after joining. Shade, keep moist, and monitor for healing and failure.',
    steps: <String>['Shade grafts from direct sun', 'Keep soil consistently moist', 'Inspect daily for wilting or separation', 'Remove binding once healed'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'graft-1',
        prompt: 'Why should grafts be shaded after grafting?',
        options: <String>[
          'To reduce stress on the healing union',
          'To make grafts grow faster',
          'To prevent water from reaching roots',
        ],
        correctOptionIndex: 0,
        explanation: 'Shade reduces water loss and heat stress on the delicate graft union while it heals.',
      ),
      LessonQuestion(
        id: 'graft-2',
        prompt: 'What indicates graft failure?',
        options: <String>[
          'Wilting of scion leaves or no callus growth',
          'Green leaves appearing',
          'Rapid branch growth',
        ],
        correctOptionIndex: 0,
        explanation: 'Wilting and lack of callus (the healing tissue) indicate the graft is not taking.',
      ),
      LessonQuestion(
        id: 'graft-3',
        prompt: 'When can you remove graft binding?',
        options: <String>[
          'After 4-6 weeks when the union is solid',
          'Within days of grafting',
          'Never, leave it on permanently',
        ],
        correctOptionIndex: 0,
        explanation: 'Once callus tissue forms and the union is strong enough, remove binding to prevent girdling.',
      ),
    ],
    tools: <String>['Shade, tape'],
    youtubeVideoId: 'X5gSDVrZ0-Q',
    websiteUrl: 'https://www.gardenmyths.com/grafting-guide/',
  ),
  const LearningLesson(
    id: 'extra-034',
    title: 'Compost tea basics',
    subtitle: 'A low-cost foliar feed and microbial booster.',
    baseProgress: 0.05,
    duration: '6 min',
    tint: Color(0xFFEDE8FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.bubble_chart_rounded,
    imageAsset: AppAssets.uiGallery04,
    overview: 'Steep finished compost in water with aeration to activate beneficial microbes. Use the resulting tea as a foliar spray to boost plant immunity and nutrient uptake.',
    steps: <String>['Fill bucket with water', 'Add finished compost and aerate 24-48 hours', 'Strain through cloth', 'Dilute and spray on leaf undersides at dawn'],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: 'comptea-1',
        prompt: 'What is the main benefit of compost tea?',
        options: <String>['Provides beneficial microbes and slow-release nutrients', 'Replaces all pest management', 'Makes soil waterproof'],
        correctOptionIndex: 0,
        explanation: 'Compost tea delivers living microbes that improve soil health and nutrient availability.',
      ),
      LessonQuestion(
        id: 'comptea-2',
        prompt: 'How long should compost tea brew?',
        options: <String>['24-48 hours with aeration', '5 minutes', 'One week in sunlight'],
        correctOptionIndex: 0,
        explanation: 'Aeration during 24-48 hours allows beneficial microbes to multiply significantly.',
      ),
      LessonQuestion(
        id: 'comptea-3',
        prompt: 'When is the best time to spray?',
        options: <String>['Early morning when leaves are damp', 'Midday in full sun', 'During rain'],
        correctOptionIndex: 0,
        explanation: 'Early morning spray allows microbes to establish before sun stress kills them.',
      ),
    ],
    tools: <String>['Bucket, aerator'],
    youtubeVideoId: 'Ov-ZCDS2p8g',
    websiteUrl: 'https://www.gardenmyths.com/compost-tea/',
  ),
  const LearningLesson(
    id: 'extra-035',
    title: 'Basic soil cover',
    subtitle: 'Protect bare soil to reduce erosion.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.landscape_rounded,
    imageAsset: AppAssets.uiGallery05,
    overview: 'Bare soil erodes in rain and loses nutrients. Cover with residues or live crops to protect structure.',
    steps: <String>['Collect crop residues after harvest', 'Spread 5-10 cm layer evenly', 'Plant cover crops if area stays bare'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'sc-1', prompt: 'Why is bare soil a problem?', options: <String>['Erodes and loses nutrients', 'Stores water too well', 'Reduces pest habitat'], correctOptionIndex: 0, explanation: 'Rain breaks soil; water washes away topsoil.'),
      LessonQuestion(id: 'sc-2', prompt: 'Good soil cover source?', options: <String>['Crop residues or plants', 'Plastic only', 'Rocks'], correctOptionIndex: 0, explanation: 'Organic improves soil.'),
      LessonQuestion(id: 'sc-3', prompt: 'How deep should cover be?', options: <String>['5-10 cm', 'Barely visible', 'Over 20 cm'], correctOptionIndex: 0, explanation: '5-10 cm protects and allows water flow.'),
    ],
    tools: <String>['Residue, seed'],
    youtubeVideoId: 'sJ9LpL7X4Ys',
    websiteUrl: 'https://www.agronomy.org/cover-crops',
  ),
  const LearningLesson(
    id: 'extra-036',
    title: 'Quick market checks',
    subtitle: 'Three things to check when pricing in the market.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.storefront_rounded,
    imageAsset: AppAssets.uiGallery06,
    overview: 'Before selling, confirm price, buyer willingness, and transport costs to avoid losses.',
    steps: <String>['Contact 3+ buyers for quotes', 'Confirm volume and payment', 'Calculate transport vs profit'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'mk-1', prompt: 'Why check multiple buyers?', options: <String>['Prices vary; avoid selling low', 'Each reliable', 'Waste time'], correctOptionIndex: 0, explanation: 'Prices fluctuate; checking ensures competitive rates.'),
      LessonQuestion(id: 'mk-2', prompt: 'Before selling, important?', options: <String>['Confirm buyer will buy', 'Guess they have money', 'Assume'], correctOptionIndex: 0, explanation: 'Reliability matters; confirm terms.'),
      LessonQuestion(id: 'mk-3', prompt: 'Subtract from market price?', options: <String>['Transport, fees', 'Nothing', 'Water weight'], correctOptionIndex: 0, explanation: 'Profit = price minus costs.'),
    ],
    tools: <String>['Phone, notes'],
    youtubeVideoId: 'gKw7KE5fBi4',
    websiteUrl: 'https://www.fao.org/3/i3088e/i3088e.pdf',
  ),
  const LearningLesson(
    id: 'extra-037',
    title: 'Simple seedling hardening',
    subtitle: 'Prepare seedlings for field conditions gradually.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFE9F4DB),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.sunny,
    imageAsset: AppAssets.uiGallery07,
    overview: 'Seedlings need gradual exposure to sun/wind to avoid transplant shock.',
    steps: <String>['Start 7-10 days before transplant', 'Place in shade 2 hours daily', 'Increase sun and reduce water'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'hd-1', prompt: 'What is hardening?', options: <String>['Exposing to stress gradually', 'Making hard', 'Stopping water'], correctOptionIndex: 0, explanation: 'Acclimates to sun, wind.'),
      LessonQuestion(id: 'hd-2', prompt: 'When start hardening?', options: <String>['7-10 days before', 'Day before', 'After'], correctOptionIndex: 0, explanation: 'Early prevents shock.'),
      LessonQuestion(id: 'hd-3', prompt: 'Without hardening?', options: <String>['Wilt and shock', 'Grow faster', 'Need no water'], correctOptionIndex: 0, explanation: 'Stress from sudden sun.'),
    ],
    tools: <String>['Shade cloth'],
    youtubeVideoId: 'qsH9JwFxDjE',
    websiteUrl: 'https://www.almanac.com/gardening/hardening-off',
  ),
  const LearningLesson(
    id: 'extra-038',
    title: 'Weed mapping',
    subtitle: 'Mark persistent weed patches for targeted control.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.map_rounded,
    imageAsset: AppAssets.uiGallery08,
    overview: 'Map weed locations to focus control and track year to year.',
    steps: <String>['Walk systematically, mark areas', 'Note type and intensity', 'Plan control per area'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'wm-1', prompt: 'Why map weeds?', options: <String>['Target control efficiently', 'Kills auto', 'Just recording'], correctOptionIndex: 0, explanation: 'Shows priority areas.'),
      LessonQuestion(id: 'wm-2', prompt: 'Record what?', options: <String>['Location, type, intensity', 'Field name', 'Crop'], correctOptionIndex: 0, explanation: 'Guides control choices.'),
      LessonQuestion(id: 'wm-3', prompt: 'Next season benefit?', options: <String>['Compare patterns', 'No benefit', 'This year only'], correctOptionIndex: 0, explanation: 'Shows persistent issues.'),
    ],
    tools: <String>['Flags, notebook'],
    youtubeVideoId: '7zGnP_s5pzw',
    websiteUrl: 'https://www.cropwatch.unl.edu/weeds',
  ),
  const LearningLesson(
    id: 'extra-039',
    title: 'Livestock record basics',
    subtitle: 'Track health, treatments, and production per group.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Business',
    icon: Icons.receipt_long_rounded,
    imageAsset: AppAssets.uiGallery09,
    overview: 'Simple records show health patterns, treatment effectiveness, and trends.',
    steps: <String>['Record date, group, observation', 'Note treatments and costs', 'Record outcome 3-7 days later'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'lr-1', prompt: 'Main benefit of records?', options: <String>['Identify patterns and effectiveness', 'No value', 'Government only'], correctOptionIndex: 0, explanation: 'Show what works, what recurs.'),
      LessonQuestion(id: 'lr-2', prompt: 'Record what?', options: <String>['Date, group, obs, treatment, outcome', 'Deaths', 'Costs'], correctOptionIndex: 0, explanation: 'Complete tracks trends.'),
      LessonQuestion(id: 'lr-3', prompt: 'Review how often?', options: <String>['Monthly for patterns', 'Never', 'Yearly'], correctOptionIndex: 0, explanation: 'Regular catches issues.'),
    ],
    tools: <String>['Notebook, pen'],
    youtubeVideoId: 'fLVcXD_IXPg',
    websiteUrl: 'https://www.sare.org/learning/record-keeping/',
  ),
  const LearningLesson(
    id: 'extra-040',
    title: 'Shade tree planning',
    subtitle: 'Plant trees to provide long-term on-farm shade.',
    baseProgress: 0.05,
    duration: '6 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.cropAdvice,
    difficulty: 'Business',
    icon: Icons.park_rounded,
    imageAsset: AppAssets.uiGallery10,
    overview: 'Trees reduce heat, provide windbreak, shelter, and soil improvement over time.',
    steps: <String>['Choose fast-growing species', 'Plant north/west for afternoon shade', 'Space 4-6 meters apart', 'Water 2 years until established'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'st-1', prompt: 'Why shade trees?', options: <String>['Reduce heat, wind, improve soil', 'No maintenance', 'Immediate'], correctOptionIndex: 0, explanation: 'Long-term benefits multiple ways.'),
      LessonQuestion(id: 'st-2', prompt: 'When choosing?', options: <String>['Select fast-growing', 'Any tree', 'Slow'], correctOptionIndex: 0, explanation: 'Affects rate and benefit timing.'),
      LessonQuestion(id: 'st-3', prompt: 'When benefit?', options: <String>['After 3-5 years', 'Immediately', 'After 20+'], correctOptionIndex: 0, explanation: 'Fast species work within years.'),
    ],
    tools: <String>['Shovel, stakes'],
    youtubeVideoId: '5RdxY5jSh0w',
    websiteUrl: 'https://www.agroforestry.org/tree-selection/',
  ),
  const LearningLesson(
    id: 'extra-041',
    title: 'Soil aeration',
    subtitle: 'Reduce compaction to improve root growth.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.compress_rounded,
    imageAsset: AppAssets.uiGallery01,
    overview: 'Compacted soil restricts roots and water. Break compaction mechanically or biologically.',
    steps: <String>['Avoid traffic when wet', 'Use deep tools or aerators', 'Add organic matter', 'Grow deep roots'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'ae-1', prompt: 'Problem with compact soil?', options: <String>['Roots cannot penetrate', 'Too light', 'Weeds cannot'], correctOptionIndex: 0, explanation: 'Restricts root and water.'),
      LessonQuestion(id: 'ae-2', prompt: 'When avoid traffic?', options: <String>['When wet compacts', 'Winter only', 'Never'], correctOptionIndex: 0, explanation: 'Wet soil compresses easily.'),
      LessonQuestion(id: 'ae-3', prompt: 'Improve biologically?', options: <String>['Add organic, grow roots', 'More fertilizer', 'Remove organics'], correctOptionIndex: 0, explanation: 'Organic and roots create pores.'),
    ],
    tools: <String>['Fork, aerator'],
    youtubeVideoId: 'ql0kI62sKvQ',
    websiteUrl: 'https://www.soilhealth.org/improving-compaction/',
  ),
  const LearningLesson(
    id: 'extra-042',
    title: 'Simple fence checks',
    subtitle: 'Keep boundaries secure and animals safe.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Practical',
    icon: Icons.fence_rounded,
    imageAsset: AppAssets.uiGallery02,
    overview: 'Regular checks prevent escapes, theft, and predator access to animals.',
    steps: <String>['Walk weekly looking for damage', 'Check holes, posts, rust', 'Repair immediately', 'Replace weak sections seasonally'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'fc-1', prompt: 'Why regular checks?', options: <String>['Small holes grow; prevent escape', 'Never need repair', 'After escape'], correctOptionIndex: 0, explanation: 'Early catches prevents loss.'),
      LessonQuestion(id: 'fc-2', prompt: 'Look for what?', options: <String>['Holes, posts, rust, damage', 'Only color', 'Nothing'], correctOptionIndex: 0, explanation: 'These signs weakness.'),
      LessonQuestion(id: 'fc-3', prompt: 'When repair?', options: <String>['Immediately prevent', 'Convenient', 'After escape'], correctOptionIndex: 0, explanation: 'Quick prevents losses.'),
    ],
    tools: <String>['Wire, pliers'],
    youtubeVideoId: 'pVJwz8KqSrE',
    websiteUrl: 'https://www.ext.vt.edu/fencing',
  ),
  const LearningLesson(
    id: 'extra-043',
    title: 'Low-cost drying',
    subtitle: 'Dry produce to extend shelf life using simple methods.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Practical',
    icon: Icons.sunny,
    imageAsset: AppAssets.uiGallery03,
    overview: 'Use shade, racks, and airflow to dry safely and reduce spoilage.',
    steps: <String>['Select mature healthy produce', 'Spread thin on clean racks', 'Place in shaded ventilated area', 'Turn regularly for even drying'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'dr-1', prompt: 'Why shade drying?', options: <String>['Prevents bleaching and retains nutrients', 'Sun faster', 'Shade hard'], correctOptionIndex: 0, explanation: 'Protects color and nutrients.'),
      LessonQuestion(id: 'dr-2', prompt: 'Why turn regularly?', options: <String>['Ensures even drying, no mold', 'Makes harder', 'No reason'], correctOptionIndex: 0, explanation: 'Improves air circulation.'),
      LessonQuestion(id: 'dr-3', prompt: 'Produce dry enough?', options: <String>['No moisture when squeezed', 'Still heavy', 'Turns black'], correctOptionIndex: 0, explanation: 'Dry is shelf-stable.'),
    ],
    tools: <String>['Racks, tarpaulin'],
    youtubeVideoId: 'WvSrLMtqKiA',
    websiteUrl: 'https://www.fao.org/3/i3972e/i3972e.pdf',
  ),
  const LearningLesson(
    id: 'extra-044',
    title: 'Hand tool care',
    subtitle: 'Sharpen and store tools to keep them effective.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFE9F4DB),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.build_rounded,
    imageAsset: AppAssets.uiGallery04,
    overview: 'Proper maintenance extends tool life and improves work efficiency.',
    steps: <String>['Clean dirt after each use', 'Sharpen blades regularly', 'Oil hinges and moving parts', 'Store in dry location'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'tc-1', prompt: 'Why sharpen regularly?', options: <String>['Need less effort and faster', 'Make noise', 'Wastes time'], correctOptionIndex: 0, explanation: 'Sharp is safer and faster.'),
      LessonQuestion(id: 'tc-2', prompt: 'When oil tools?', options: <String>['After use to prevent rust', 'Never slippery', 'Yearly'], correctOptionIndex: 0, explanation: 'Oil prevents rust.'),
      LessonQuestion(id: 'tc-3', prompt: 'Best storage?', options: <String>['Dry location protected', 'Outside', 'In water'], correctOptionIndex: 0, explanation: 'Dry prevents rust.'),
    ],
    tools: <String>['File, oil'],
    youtubeVideoId: 'RpxvJY8u8RI',
    websiteUrl: 'https://www.gardenmyths.com/tool-maintenance/',
  ),
  const LearningLesson(
    id: 'extra-045',
    title: 'Nursery labeling',
    subtitle: 'Label rows clearly to avoid confusion at transplant.',
    baseProgress: 0.05,
    duration: '2 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.label_rounded,
    imageAsset: AppAssets.uiGallery05,
    overview: 'Clear labeling prevents wrong variety transplants and tracks performance.',
    steps: <String>['Record variety and date on label', 'Use waterproof marker and stake', 'Place at row start and end', 'Check regularly for legibility'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'nl-1', prompt: 'Why label nursery?', options: <String>['Prevents wrong varieties', 'Just suggestion', 'Big farms'], correctOptionIndex: 0, explanation: 'Ensures correct transplant.'),
      LessonQuestion(id: 'nl-2', prompt: 'What on labels?', options: <String>['Variety name and date', 'Only variety', 'Only date'], correctOptionIndex: 0, explanation: 'Both track age and performance.'),
      LessonQuestion(id: 'nl-3', prompt: 'Why waterproof?', options: <String>['Survives nursery water', 'Regular ok', 'Color irrelevant'], correctOptionIndex: 0, explanation: 'Remains legible.'),
    ],
    tools: <String>['Stakes, marker'],
    youtubeVideoId: 'KG7d1iBFZ0A',
    websiteUrl: 'https://www.almanac.com/gardening/starting-seeds',
  ),
  const LearningLesson(
    id: 'extra-046',
    title: 'Simple pest traps',
    subtitle: 'Low-cost traps to monitor or reduce pest numbers.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.wb_iridescent_rounded,
    imageAsset: AppAssets.uiGallery06,
    overview: 'Traps monitor populations and reduce pest numbers with low cost.',
    steps: <String>['Set traps at dusk near crops', 'Inspect daily and record count', 'Empty and refresh regularly', 'Use data to time control'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'pt-1', prompt: 'Main benefit of traps?', options: <String>['Monitor populations and time control', 'Better than all', 'Just decoration'], correctOptionIndex: 0, explanation: 'Shows what and when.'),
      LessonQuestion(id: 'pt-2', prompt: 'When set?', options: <String>['At dusk when active', 'Midday', 'Never work'], correctOptionIndex: 0, explanation: 'Many active at dusk.'),
      LessonQuestion(id: 'pt-3', prompt: 'Why record?', options: <String>['Data shows control timing', 'Just paperwork', 'Irrelevant'], correctOptionIndex: 0, explanation: 'Records reveal timing.'),
    ],
    tools: <String>['Simple traps'],
    youtubeVideoId: 'dJGZnX-ZpQY',
    websiteUrl: 'https://www.ipm.ucdavis.edu/monitoring',
  ),
  const LearningLesson(
    id: 'extra-047',
    title: 'Simple fencing for poultry',
    subtitle: 'Keep birds safe and manage ranging.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Practical',
    icon: Icons.sports_cricket_rounded,
    imageAsset: AppAssets.uiGallery07,
    overview: 'Fencing protects from predators and controls foraging areas.',
    steps: <String>['Use netting 1.5-2 meters high', 'Bury bottom 15 cm prevent dig', 'Provide sheltered roosting area', 'Check daily for damage'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'pf-1', prompt: 'How high fencing?', options: <String>['1.5-2 meters prevent', '30 cm', 'Irrelevant'], correctOptionIndex: 0, explanation: 'Adequate prevents escape.'),
      LessonQuestion(id: 'pf-2', prompt: 'Why bury bottom?', options: <String>['Prevents digging and escape', 'Just cosmetic', 'Wastes'], correctOptionIndex: 0, explanation: 'Prevents entry.'),
      LessonQuestion(id: 'pf-3', prompt: 'Inside fence?', options: <String>['Sheltered roosting and water', 'Nothing', 'Only feed'], correctOptionIndex: 0, explanation: 'Need protection.'),
    ],
    tools: <String>['Netting, posts'],
    youtubeVideoId: 'sY_qCu-KLTo',
    websiteUrl: 'https://www.extension.org/poultry-fencing',
  ),
  const LearningLesson(
    id: 'extra-048',
    title: 'Record-sharing basics',
    subtitle: 'Share simple reports with buyers or partners.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.share_rounded,
    imageAsset: AppAssets.uiGallery08,
    overview: 'Clear reporting builds trust with buyers and partners through transparency.',
    steps: <String>['Prepare one-page summary', 'Include dates and quantities', 'Attach receipts or photos', 'Send by phone or email'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'rs-1', prompt: 'Why share records?', options: <String>['Builds trust shows transparency', 'Wastes time', 'Not needed'], correctOptionIndex: 0, explanation: 'Builds relationships.'),
      LessonQuestion(id: 'rs-2', prompt: 'Include what?', options: <String>['Key numbers dates evidence', 'Vague', 'No data'], correctOptionIndex: 0, explanation: 'Specific credible.'),
      LessonQuestion(id: 'rs-3', prompt: 'How detailed?', options: <String>['One page summary', 'Book-length', 'Verbal'], correctOptionIndex: 0, explanation: 'Concise gets read.'),
    ],
    tools: <String>['Phone, email'],
    youtubeVideoId: 'n0Eg8xD2lbM',
    websiteUrl: 'https://www.fao.org/3/i3161e/i3161e.pdf',
  ),
  const LearningLesson(
    id: 'extra-049',
    title: 'Quick compost checks',
    subtitle: 'Is the pile hot, moist, and active?',
    baseProgress: 0.05,
    duration: '2 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.local_fire_department_rounded,
    imageAsset: AppAssets.uiGallery09,
    overview: 'Weekly checks reveal compost progress and readiness through temp and moisture.',
    steps: <String>['Feel pile temperature from center', 'Check moisture like squeezed sponge', 'Smell for ammonia or dry scent', 'Turn if too cool or wet'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'cc-1', prompt: 'Hot pile indicates?', options: <String>['Microbes breaking down active', 'Pile burned', 'No activity'], correctOptionIndex: 0, explanation: 'Heat shows activity.'),
      LessonQuestion(id: 'cc-2', prompt: 'Right moisture?', options: <String>['Moist like sponge', 'Bone dry', 'Soaking'], correctOptionIndex: 0, explanation: 'Ideal for activity.'),
      LessonQuestion(id: 'cc-3', prompt: 'Ammonia smell?', options: <String>['Pile too wet turn', 'Pile ready', 'Pile burning'], correctOptionIndex: 0, explanation: 'Shows anaerobic.'),
    ],
    tools: <String>['Thermometer'],
    youtubeVideoId: 'VF1mALvgD-8',
    websiteUrl: 'https://www.gardenmyths.com/compost-management/',
  ),
  const LearningLesson(
    id: 'extra-050',
    title: 'Simple herd grouping',
    subtitle: 'Group animals by age or purpose for better management.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Practical',
    icon: Icons.groups_rounded,
    imageAsset: AppAssets.uiGallery10,
    overview: 'Grouping by age simplifies feeding and improves health monitoring consistency.',
    steps: <String>['Separate young from adults', 'Keep different purpose separate', 'Tag or mark groups clearly', 'Maintain consistent feed schedule'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'hg-1', prompt: 'Why group by age?', options: <String>['Similar ages same feed needs', 'All same', 'Wastes time'], correctOptionIndex: 0, explanation: 'Reduces conflict.'),
      LessonQuestion(id: 'hg-2', prompt: 'What separate?', options: <String>['Young from adults different', 'No separation', 'Only color'], correctOptionIndex: 0, explanation: 'Prevents bullying.'),
      LessonQuestion(id: 'hg-3', prompt: 'Why label?', options: <String>['Identify for treatment', 'Not useful', 'Look organized'], correctOptionIndex: 0, explanation: 'Ensures correct care.'),
    ],
    tools: <String>['Tags, marker'],
    youtubeVideoId: 'GrJBLnCbSIQ',
    websiteUrl: 'https://www.extension.org/animal-grouping',
  ),
  const LearningLesson(
    id: 'extra-051',
    title: 'Quick drying assessment',
    subtitle: 'Decide if produce is ready for market or needs drying.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFE9F4DB),
    track: 'Market access',
    difficulty: 'Practical',
    icon: Icons.outbond_rounded,
    imageAsset: AppAssets.uiGallery01,
    overview: 'Test moisture content and assess quality to decide whether to sell fresh or dry produce.',
    steps: <String>['Break sample to check interior dryness', 'Weigh to track moisture loss', 'Assess for mold or damage', 'Choose market route based on condition'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'da-1', prompt: 'How to test if produce is dry enough?', options: <String>['Break sample; interior should be dry and brittle', 'Only check surface', 'Use smell alone'], correctOptionIndex: 0, explanation: 'Interior dryness ensures shelf stability.'),
      LessonQuestion(id: 'da-2', prompt: 'Why track moisture loss over time?', options: <String>['Shows when drying is complete', 'Not important', 'Just for records'], correctOptionIndex: 0, explanation: 'Weight loss directly indicates moisture removal.'),
      LessonQuestion(id: 'da-3', prompt: 'Best market for high-moisture produce?', options: <String>['Sell fresh immediately to avoid loss', 'Force dry anyway', 'Discard'], correctOptionIndex: 0, explanation: 'Fresh sales prevent storage losses.'),
    ],
    tools: <String>['Moisture tester, scale'],
    youtubeVideoId: 'EcL3W5zEPCg',
    websiteUrl: 'https://www.fao.org/3/i3956e/i3956e.pdf',
  ),
  const LearningLesson(
    id: 'extra-052',
    title: 'Shade cloth choices',
    subtitle: 'Which shade percentage suits your crop?',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.crop_portrait_rounded,
    imageAsset: AppAssets.uiGallery02,
    overview: 'Different crops need different shade levels. Choose percentage based on crop tolerance and climate.',
    steps: <String>['Identify crop sun tolerance (full/partial/shade)', 'Check climate heat intensity', 'Select 30-70% shade cloth', 'Monitor and adjust if needed'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'sc-1', prompt: 'What shade for sun-loving crops?', options: <String>['30-40% shade', '70% shade', 'No shade'], correctOptionIndex: 0, explanation: 'Light shade protects from extreme sun.'),
      LessonQuestion(id: 'sc-2', prompt: 'Why vary shade percentage?', options: <String>['Different crops have different tolerances', 'All same', 'Shade irrelevant'], correctOptionIndex: 0, explanation: 'Each crop has optimal light requirements.'),
      LessonQuestion(id: 'sc-3', prompt: 'When increase shade?', options: <String>['During hottest season', 'Never change', 'Winter only'], correctOptionIndex: 0, explanation: 'Heat stress requires more protection.'),
    ],
    tools: <String>['Shade cloth, clips'],
    youtubeVideoId: 'Z8tNDQvLEMo',
    websiteUrl: 'https://www.gardenmyths.com/shade-cloth/',
  ),
  const LearningLesson(
    id: 'extra-053',
    title: 'Basic harvest timing',
    subtitle: 'Signs that crops are ready to harvest.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.emoji_food_beverage_rounded,
    imageAsset: AppAssets.uiGallery03,
    overview: 'Each crop shows readiness through size, color, and firmness. Learn variety-specific indicators.',
    steps: <String>['Check size against variety standard', 'Look for color change from unripe', 'Feel firmness; ripe yields slightly to pressure', 'Taste sample if appropriate'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'ht-1', prompt: 'Main harvest readiness signs?', options: <String>['Size, color, and firmness together', 'Only size matters', 'Color alone'], correctOptionIndex: 0, explanation: 'Multiple indicators confirm ripeness.'),
      LessonQuestion(id: 'ht-2', prompt: 'Why sample before full harvest?', options: <String>['Confirm ripeness throughout field', 'Wastes time', 'Not necessary'], correctOptionIndex: 0, explanation: 'Field maturity varies; sampling guides decisions.'),
      LessonQuestion(id: 'ht-3', prompt: 'Underripe vs overripe?', options: <String>['Pick underripe; prevents waste and ripens post-harvest', 'Overripe better', 'Timing irrelevant'], correctOptionIndex: 0, explanation: 'Underripe produces longer market life.'),
    ],
    tools: <String>['Knife, scale'],
    youtubeVideoId: 'A9m3YC_sKOU',
    websiteUrl: 'https://www.almanac.com/gardening/harvest-guide',
  ),
  const LearningLesson(
    id: 'extra-054',
    title: 'Storage hygiene',
    subtitle: 'Keep storage clean to reduce pests and spoilage.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Practical',
    icon: Icons.store_rounded,
    imageAsset: AppAssets.uiGallery04,
    overview: 'Clean storage areas prevent pest infestations and microbial spoilage of stored products.',
    steps: <String>['Remove all debris and old produce', 'Sweep and wash floors and walls', 'Elevate fresh produce on pallets', 'Seal cracks and gaps'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'sh-1', prompt: 'Why remove old debris?', options: <String>['Harbors pests and mold spores', 'Just cosmetic', 'No real benefit'], correctOptionIndex: 0, explanation: 'Debris is food source for pests.'),
      LessonQuestion(id: 'sh-2', prompt: 'Why elevate on pallets?', options: <String>['Prevents floor moisture and pest access', 'Just easier', 'No reason'], correctOptionIndex: 0, explanation: 'Air circulation and separation prevents contact rot.'),
      LessonQuestion(id: 'sh-3', prompt: 'When clean storage?', options: <String>['Before each season and after use', 'Never', 'Once yearly'], correctOptionIndex: 0, explanation: 'Regular cleaning maintains conditions.'),
    ],
    tools: <String>['Broom, disinfectant'],
    youtubeVideoId: 'qL5yLqZnBJQ',
    websiteUrl: 'https://www.fao.org/3/i3097e/i3097e.pdf',
  ),
  const LearningLesson(
    id: 'extra-055',
    title: 'Water harvesting basics',
    subtitle: 'Capture and store rainwater for later use.',
    baseProgress: 0.05,
    duration: '6 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.weatherForecast,
    difficulty: 'Business',
    icon: Icons.water_damage_rounded,
    imageAsset: AppAssets.uiGallery05,
    overview: 'Collect rainwater runoff into tanks or ponds for supplemental irrigation in dry periods.',
    steps: <String>['Calculate catchment area and rainfall', 'Size tank for storage', 'Install gutters and pipes', 'Include simple filtration'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'wh-1', prompt: 'Best use of harvested water?', options: <String>['Supplemental irrigation during dry season', 'Drinking only', 'Impossible to use'], correctOptionIndex: 0, explanation: 'Water storage extends irrigation capability.'),
      LessonQuestion(id: 'wh-2', prompt: 'Why calculate catchment area?', options: <String>['Determines tank size needed', 'Not important', 'Guess size'], correctOptionIndex: 0, explanation: 'Area × rainfall = volume captured.'),
      LessonQuestion(id: 'wh-3', prompt: 'Important for water storage?', options: <String>['Cleanliness and filtration', 'Any tank works', 'Size irrelevant'], correctOptionIndex: 0, explanation: 'Clean water prevents algae and disease.'),
    ],
    tools: <String>['Tank, gutter'],
    youtubeVideoId: 'M0gkI9aXMfU',
    websiteUrl: 'https://www.fao.org/3/i5773e/i5773e.pdf',
  ),
  const LearningLesson(
    id: 'extra-056',
    title: 'Basic animal first aid',
    subtitle: 'Treat minor wounds and stabilize until vet help arrives.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Essential',
    icon: Icons.healing_rounded,
    imageAsset: AppAssets.uiGallery06,
    overview: 'Proper wound care prevents infection and reduces animal suffering and recovery time.',
    steps: <String>['Restrain animal calmly', 'Flush wound with clean water', 'Apply antiseptic solution', 'Bandage if needed; monitor for infection'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'af-1', prompt: 'First step for wounds?', options: <String>['Clean with water to remove dirt', 'Apply dressing immediately', 'Wait for vet'], correctOptionIndex: 0, explanation: 'Cleaning prevents infection.'),
      LessonQuestion(id: 'af-2', prompt: 'Why use antiseptic?', options: <String>['Kills bacteria and prevents infection', 'Just colors wound', 'Not needed'], correctOptionIndex: 0, explanation: 'Antiseptic reduces disease risk.'),
      LessonQuestion(id: 'af-3', prompt: 'Monitor bandage for?', options: <String>['Swelling, discharge, or odor indicating infection', 'Changes in weather', 'Color change only'], correctOptionIndex: 0, explanation: 'Signs of infection require vet care.'),
    ],
    tools: <String>['Water, antiseptic, bandage'],
    youtubeVideoId: 'zLSMDQHbAaA',
    websiteUrl: 'https://www.sare.org/animal-first-aid/',
  ),
  const LearningLesson(
    id: 'extra-057',
    title: 'Crop thinning',
    subtitle: 'Thin to improve size and reduce competition.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFE9F4DB),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.rowing_rounded,
    imageAsset: AppAssets.uiGallery07,
    overview: 'Remove excess plants early to give remaining plants space, water, and light.',
    steps: <String>['Thin when plants 5-10 cm high', 'Leave strongest plants', 'Remove weak or damaged ones', 'Water immediately after'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'ct-1', prompt: 'Why thin early?', options: <String>['Reduces competition and allows growth', 'Harder later', 'Never needed'], correctOptionIndex: 0, explanation: 'Early thinning prevents stunting.'),
      LessonQuestion(id: 'ct-2', prompt: 'What plants keep?', options: <String>['Strongest and healthiest', 'Random selection', 'Smallest'], correctOptionIndex: 0, explanation: 'Best plants produce better yields.'),
      LessonQuestion(id: 'ct-3', prompt: 'After thinning, do what?', options: <String>['Water to settle soil', 'Nothing', 'Thin again'], correctOptionIndex: 0, explanation: 'Watering reduces transplant shock.'),
    ],
    tools: <String>['Shears, water'],
    youtubeVideoId: 'Qz3KY5pXDWE',
    websiteUrl: 'https://www.almanac.com/gardening/thinning',
  ),
  const LearningLesson(
    id: 'extra-058',
    title: 'Low-cost soil amendments',
    subtitle: 'Use locally available materials to feed the soil.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.local_florist_rounded,
    imageAsset: AppAssets.uiGallery08,
    overview: 'Local materials like compost and manure improve soil structure and add nutrients cheaply.',
    steps: <String>['Collect compost, manure, or residues', 'Test soil to guide amendment type', 'Apply 5-10 cm layer', 'Mix into topsoil and water in'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'sa-1', prompt: 'Best local amendment?', options: <String>['Compost or aged manure', 'Fresh chemicals', 'Only commercial'], correctOptionIndex: 0, explanation: 'Local organics are cheap and beneficial.'),
      LessonQuestion(id: 'sa-2', prompt: 'Why test soil?', options: <String>['Identifies deficiencies to address', 'Wastes time', 'Guess amendments'], correctOptionIndex: 0, explanation: 'Testing guides amendment choices.'),
      LessonQuestion(id: 'sa-3', prompt: 'Application depth?', options: <String>['5-10 cm layer mixed in', 'Surface only', 'Deep'], correctOptionIndex: 0, explanation: 'Mixing creates good rooting zone.'),
    ],
    tools: <String>['Fork, compost'],
    youtubeVideoId: 'G5vLQVKE--8',
    websiteUrl: 'https://www.soilhealth.org/amendments/',
  ),
  const LearningLesson(
    id: 'extra-059',
    title: 'Basic transplant care',
    subtitle: 'Reduce transplant shock and improve survival.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFEDE8FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.emoji_nature_rounded,
    imageAsset: AppAssets.uiGallery09,
    overview: 'Proper handling and timing dramatically improves survival and crop establishment.',
    steps: <String>['Harden seedlings 7-10 days before', 'Transplant in cool part of day', 'Water soil well before digging', 'Plant at same depth; water in gently'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'tc-1', prompt: 'Before transplanting, do what?', options: <String>['Harden seedlings gradually to stress', 'Plant immediately indoors', 'Skip this'], correctOptionIndex: 0, explanation: 'Hardening prevents shock.'),
      LessonQuestion(id: 'tc-2', prompt: 'When transplant?', options: <String>['Cool part of day or cloudy', 'Midday sun', 'Anytime'], correctOptionIndex: 0, explanation: 'Cool conditions reduce wilt.'),
      LessonQuestion(id: 'tc-3', prompt: 'Correct planting depth?', options: <String>['Same depth as in nursery', 'Deeper', 'Shallower'], correctOptionIndex: 0, explanation: 'Same depth prevents crown rot.'),
    ],
    tools: <String>['Water, shade cloth'],
    youtubeVideoId: 'TIGbXhxPd1I',
    websiteUrl: 'https://www.almanac.com/gardening/transplanting',
  ),
  const LearningLesson(
    id: 'extra-060',
    title: 'Simple feed mixing',
    subtitle: 'Basic proportions to mix energy and protein feeds.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Practical',
    icon: Icons.food_bank_rounded,
    imageAsset: AppAssets.uiGallery10,
    overview: 'Balance roughage, protein, and energy to meet animal nutritional requirements efficiently.',
    steps: <String>['Estimate daily intake for each animal', 'Know basic protein percentages needed', 'Mix grains, legumes, roughage proportions', 'Record formula for consistency'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'fm-1', prompt: 'Main feed components?', options: <String>['Roughage, grain, legume for balance', 'Only one type', 'Random mix'], correctOptionIndex: 0, explanation: 'Balance provides complete nutrition.'),
      LessonQuestion(id: 'fm-2', prompt: 'Why record formula?', options: <String>['Ensures consistent nutrition and results', 'Not needed', 'Just mixing'], correctOptionIndex: 0, explanation: 'Records prevent errors.'),
      LessonQuestion(id: 'fm-3', prompt: 'Protein need varies by?', options: <String>['Age, production level, health', 'Never varies', 'Only weight'], correctOptionIndex: 0, explanation: 'Young and producing animals need more.'),
    ],
    tools: <String>['Scale, bucket'],
    youtubeVideoId: 'b2J7iiMj3q4',
    websiteUrl: 'https://www.sare.org/animal-nutrition/',
  ),
  const LearningLesson(
    id: 'extra-061',
    title: 'Quick market negotiation',
    subtitle: 'Three tips to negotiate better prices.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFE9F4DB),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.record_voice_over_rounded,
    imageAsset: AppAssets.uiGallery01,
    overview: 'Understanding your costs and having alternative buyers increases negotiating power.',
    steps: <String>['Calculate minimum price', 'Contact multiple buyers', 'Compare offers carefully', 'Be ready to walk away'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'mn-1', prompt: 'Why calculate minimum price?', options: <String>['Know when negotiations are unprofitable', 'Random guess', 'Never needed'], correctOptionIndex: 0, explanation: 'Knowing costs prevents losing money.'),
      LessonQuestion(id: 'mn-2', prompt: 'Best negotiation approach?', options: <String>['Have multiple buyer options', 'Accept first offer', 'Demand maximum'], correctOptionIndex: 0, explanation: 'Competition increases your negotiating power.'),
      LessonQuestion(id: 'mn-3', prompt: 'When to walk away?', options: <String>['If offer is below minimum', 'Never', 'Always push harder'], correctOptionIndex: 0, explanation: 'Walking away shows you have options.'),
    ],
    tools: <String>['Calculator, phone'],
    youtubeVideoId: 'D5MwI1cFJYg',
    websiteUrl: 'https://www.fao.org/3/ca5162en/ca5162en.pdf',
  ),
  const LearningLesson(
    id: 'extra-062',
    title: 'Simple soil cover crops',
    subtitle: 'Legumes and grasses to improve soil and reduce erosion.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.nature_rounded,
    imageAsset: AppAssets.uiGallery02,
    overview: 'Cover crops prevent erosion, suppress weeds, and legumes fix nitrogen affordably.',
    steps: <String>['Select appropriate crop for season', 'Plant after harvest', 'Grow until next season', 'Plow or cut and incorporate'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'cc-1', prompt: 'Best cover crop benefit?', options: <String>['Legumes fix nitrogen cheaply', 'No benefit', 'Waste of time'], correctOptionIndex: 0, explanation: 'Nitrogen fixation reduces fertilizer cost.'),
      LessonQuestion(id: 'cc-2', prompt: 'When plant cover crop?', options: <String>['After harvest before dry season', 'Anytime', 'Never needed'], correctOptionIndex: 0, explanation: 'Timing maximizes growth and benefit.'),
      LessonQuestion(id: 'cc-3', prompt: 'Why erosion control matters?', options: <String>['Protects soil from rain, wind damage', 'Cosmetic only', 'No benefit'], correctOptionIndex: 0, explanation: 'Erosion degrades productive topsoil.'),
    ],
    tools: <String>['Seed, seeder'],
    youtubeVideoId: 'F9PnVCQfHxE',
    websiteUrl: 'https://www.sare.org/cover-crops/',
  ),
  const LearningLesson(
    id: 'extra-063',
    title: 'Quick sales packing list',
    subtitle: 'Checklist before loading produce for market.',
    baseProgress: 0.05,
    duration: '2 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.checklist_rounded,
    imageAsset: AppAssets.uiGallery03,
    overview: 'A pre-loading checklist prevents forgotten items and buyer miscommunication.',
    steps: <String>['Count and verify crate quantities', 'Check product quality and ripeness', 'Confirm buyer details and price', 'Verify transport availability'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'sp-1', prompt: 'Checklist prevents?', options: <String>['Forgotten items and mistakes', 'Wasting time', 'Has no benefit'], correctOptionIndex: 0, explanation: 'Organization prevents costly errors.'),
      LessonQuestion(id: 'sp-2', prompt: 'What to verify before loading?', options: <String>['Counts, quality, buyer contact, transport', 'Skip checks', 'Load randomly'], correctOptionIndex: 0, explanation: 'Verification ensures customer satisfaction.'),
      LessonQuestion(id: 'sp-3', prompt: 'Best time to make checklist?', options: <String>['Day before market to prepare', 'Day of market', 'Never'], correctOptionIndex: 0, explanation: 'Advance prep avoids last-minute stress.'),
    ],
    tools: <String>['Checklist, phone'],
    youtubeVideoId: 'X8dQu4TyDe8',
    websiteUrl: 'https://www.fao.org/3/i5415e/i5415e.pdf',
  ),
  const LearningLesson(
    id: 'extra-064',
    title: 'Quick irrigation scheduling',
    subtitle: 'Simple rules to avoid overwatering.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.schedule_rounded,
    imageAsset: AppAssets.uiGallery04,
    overview: 'Deep infrequent watering encourages deep roots and saves water versus daily shallow watering.',
    steps: <String>['Test soil 15 cm deep weekly', 'Water only when soil feels dry', 'Plan around rain forecasts', 'Water early morning for efficiency'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'is-1', prompt: 'When water deeply?', options: <String>['Less often but deeper to encourage roots', 'Shallow daily', 'Random scheduling'], correctOptionIndex: 0, explanation: 'Deep roots access more water.'),
      LessonQuestion(id: 'is-2', prompt: 'Best test for soil moisture?', options: <String>['Squeeze handful - crumbly is dry', 'Guess', 'Never test'], correctOptionIndex: 0, explanation: 'Simple test guides watering decisions.'),
      LessonQuestion(id: 'is-3', prompt: 'Why check rain forecast?', options: <String>['Avoid irrigating before rain', 'Ignore weather', 'Water anyway'], correctOptionIndex: 0, explanation: 'Forecasting saves water and money.'),
    ],
    tools: <String>['Moisture meter, calendar'],
    youtubeVideoId: 'Ln_yKvE2-zI',
    websiteUrl: 'https://www.gardenmyths.com/irrigation/',
  ),
  const LearningLesson(
    id: 'extra-065',
    title: 'Simple trimming for quality',
    subtitle: 'Trim to improve fruit size and quality.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFE9F4DB),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.content_cut_rounded,
    imageAsset: AppAssets.uiGallery05,
    overview: 'Removing excess flowers or fruits concentrates plant resources into larger, higher-quality specimens.',
    steps: <String>['Monitor fruit set carefully', 'Identify clusters with excess', 'Remove smaller or damaged fruit', 'Leave space between remaining fruit'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'tr-1', prompt: 'Why trim fruit?', options: <String>['Concentrates resources for larger fruit', 'Waste effort', 'Never needed'], correctOptionIndex: 0, explanation: 'Fewer fruits = bigger, better quality.'),
      LessonQuestion(id: 'tr-2', prompt: 'What to remove?', options: <String>['Smaller or damaged fruit, excess blooms', 'Keep everything', 'Remove largest'], correctOptionIndex: 0, explanation: 'Selection favors best specimens.'),
      LessonQuestion(id: 'tr-3', prompt: 'Result of proper trimming?', options: <String>['Better market price, customer satisfaction', 'No change', 'Lower quality'], correctOptionIndex: 0, explanation: 'Quality improves with thinning.'),
    ],
    tools: <String>['Shears'],
    youtubeVideoId: 'bW6qRNxRbqE',
    websiteUrl: 'https://www.almanac.com/gardening/thinning',
  ),
  const LearningLesson(
    id: 'extra-066',
    title: 'Quick feed checks',
    subtitle: 'Inspect feed for contaminants and spoilage.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Practical',
    icon: Icons.food_bank_rounded,
    imageAsset: AppAssets.uiGallery06,
    overview: 'Regular feed inspections prevent illness from moldy or contaminated batches.',
    steps: <String>['Inspect visually for discoloration', 'Smell for musty or off-odors', 'Check for pest signs', 'Discard suspect feed'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'fc-1', prompt: 'Signs of spoiled feed?', options: <String>['Mold, bad odor, discoloration', 'No signs matter', 'Always feed'], correctOptionIndex: 0, explanation: 'These signs indicate spoilage.'),
      LessonQuestion(id: 'fc-2', prompt: 'Moldy feed consequence?', options: <String>['Causes illness and reduced growth', 'No problem', 'Improves nutrition'], correctOptionIndex: 0, explanation: 'Mold toxins harm animal health.'),
      LessonQuestion(id: 'fc-3', prompt: 'Best feed storage?', options: <String>['Cool, dry, sealed container', 'Any location', 'Open pile'], correctOptionIndex: 0, explanation: 'Proper storage prevents mold.'),
    ],
    tools: <String>['Scoop, light'],
    youtubeVideoId: 'qEYn-BzPy1g',
    websiteUrl: 'https://www.sare.org/feed-quality/',
  ),
  const LearningLesson(
    id: 'extra-067',
    title: 'Simple pest scouting route',
    subtitle: 'Design a route that samples the whole field.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.map_rounded,
    imageAsset: AppAssets.uiGallery07,
    overview: 'Consistent sampling at fixed points provides trends for control decisions versus spotty observations.',
    steps: <String>['Mark fixed sampling points in field', 'Visit same time weekly', 'Record pest counts at each', 'Compare week to week for trends'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'ps-1', prompt: 'Why fixed points matter?', options: <String>['Compare trends week to week', 'Random sampling is better', 'No difference'], correctOptionIndex: 0, explanation: 'Consistency reveals pest population changes.'),
      LessonQuestion(id: 'ps-2', prompt: 'Best sampling time?', options: <String>['Early morning, same time weekly', 'Random', 'Afternoon'], correctOptionIndex: 0, explanation: 'Timing consistency improves accuracy.'),
      LessonQuestion(id: 'ps-3', prompt: 'Value of scouting?', options: <String>['Avoids unnecessary spraying, saves cost', 'Always spray', 'No benefit'], correctOptionIndex: 0, explanation: 'Data guides efficient control.'),
    ],
    tools: <String>['Marker flags, notebook'],
    youtubeVideoId: 'rJ5iEQKX_-I',
    websiteUrl: 'https://www.fao.org/3/i3956e/i3956e.pdf',
  ),
  const LearningLesson(
    id: 'extra-068',
    title: 'Quick sales documentation',
    subtitle: 'What to record for each sale to protect buyer relationships.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.receipt_long_rounded,
    imageAsset: AppAssets.uiGallery08,
    overview: 'Sales records create accountability and build buyer confidence through transparency.',
    steps: <String>['Record buyer name and contact', 'Note date, quantity, price', 'Document payment method received', 'File for reference and disputes'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'sd-1', prompt: 'Key record items?', options: <String>['Buyer, date, quantity, price, payment', 'Just quantity', 'No records needed'], correctOptionIndex: 0, explanation: 'Complete records prevent misunderstandings.'),
      LessonQuestion(id: 'sd-2', prompt: 'Record benefits?', options: <String>['Protects both seller and buyer', 'Wastes time', 'No benefit'], correctOptionIndex: 0, explanation: 'Documentation builds trust.'),
      LessonQuestion(id: 'sd-3', prompt: 'When disputes arise?', options: <String>['Records provide proof and resolution', 'Guess amounts', 'Accept loss'], correctOptionIndex: 0, explanation: 'Records resolve disagreements fairly.'),
    ],
    tools: <String>['Receipt book, phone'],
    youtubeVideoId: 'X8dQu4TyDe8',
    websiteUrl: 'https://www.fao.org/3/i3956e/i3956e.pdf',
  ),
  const LearningLesson(
    id: 'extra-069',
    title: 'Quick soil cover checks',
    subtitle: 'Does the soil have enough protective cover?',
    baseProgress: 0.05,
    duration: '2 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.landscape_rounded,
    imageAsset: AppAssets.uiGallery09,
    overview: 'Bare soil erodes quickly; cover crops or residue protect and build soil.',
    steps: <String>['Walk field and observe cover', 'Note bare patches', 'Add residue mulch if needed', 'Plan cover crop for next season'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'sc-1', prompt: 'Bare soil risks?', options: <String>['Erosion and nutrient loss', 'No problems', 'Beneficial'], correctOptionIndex: 0, explanation: 'Unprotected soil degrades quickly.'),
      LessonQuestion(id: 'sc-2', prompt: 'How to cover bare patches?', options: <String>['Mulch or cover crops', 'Leave bare', 'No solution'], correctOptionIndex: 0, explanation: 'Coverage prevents erosion.'),
      LessonQuestion(id: 'sc-3', prompt: 'Cover benefits?', options: <String>['Prevents erosion, improves soil', 'No benefit', 'Negative'], correctOptionIndex: 0, explanation: 'Protection improves farm health.'),
    ],
    tools: <String>['Notebook'],
    youtubeVideoId: 'E5Z0G9W8pRo',
    websiteUrl: 'https://www.soilhealth.org/cover-soil/',
  ),
  const LearningLesson(
    id: 'extra-070',
    title: 'Basic irrigation repair',
    subtitle: 'Fix common small leaks and replace blocked emitters.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.build_rounded,
    imageAsset: AppAssets.uiGallery10,
    overview: 'Quick repairs prevent water waste and maintain uniform crop watering.',
    steps: <String>['Carry spare emitters and connectors', 'Identify leaks regularly', 'Replace or clean blocked parts', 'Test repaired zones immediately'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'ir-1', prompt: 'Why keep spares?', options: <String>['Fix breaks immediately, avoid water loss', 'Unnecessary', 'Fix later'], correctOptionIndex: 0, explanation: 'Spares enable quick repairs.'),
      LessonQuestion(id: 'ir-2', prompt: 'Signs of blocked emitter?', options: <String>['Uneven water output, dry patches', 'No signs', 'Works fine'], correctOptionIndex: 0, explanation: 'Blockage causes uneven watering.'),
      LessonQuestion(id: 'ir-3', prompt: 'Leak impacts?', options: <String>['Water waste and increased cost', 'No problem', 'Beneficial'], correctOptionIndex: 0, explanation: 'Leaks waste water and money.'),
    ],
    tools: <String>['Spare emitters, pliers'],
    youtubeVideoId: 'Ln_yKvE2-zI',
    websiteUrl: 'https://www.fao.org/3/i3956e/i3956e.pdf',
  ),
  const LearningLesson(
    id: 'extra-071',
    title: 'Simple feeding schedules',
    subtitle: 'Set routine feeding times for consistent intake.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Practical',
    icon: Icons.schedule_rounded,
    imageAsset: AppAssets.uiGallery01,
    overview: 'Regular feeding times stabilize appetite and digestion and allow animals to anticipate meals.',
    steps: <String>['Establish two feeding times daily', 'Measure consistent feed amounts', 'Maintain schedule even on holidays', 'Adjust for season changes gradually'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'fs-1', prompt: 'Feeding schedule benefits?', options: <String>['Stabilizes appetite and digestion', 'No difference', 'Wastes time'], correctOptionIndex: 0, explanation: 'Consistency improves intake and growth.'),
      LessonQuestion(id: 'fs-2', prompt: 'How many times daily?', options: <String>['Two feeding times for consistency', 'Once', 'Random'], correctOptionIndex: 0, explanation: 'Regular rhythm trains animals.'),
      LessonQuestion(id: 'fs-3', prompt: 'Schedule importance?', options: <String>['Predictability improves animal health', 'No benefit', 'Negative'], correctOptionIndex: 0, explanation: 'Animals thrive on routine.'),
    ],
    tools: <String>['Buckets, scale'],
    youtubeVideoId: 'L3bQ5OU6DsQ',
    websiteUrl: 'https://www.sare.org/feeding-animals/',
  ),
  const LearningLesson(
    id: 'extra-072',
    title: 'Quick market sorting',
    subtitle: 'Sort by size and quality to maximise price.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Practical',
    icon: Icons.sort_rounded,
    imageAsset: AppAssets.uiGallery02,
    overview: 'Quality grading lets farmers access premium buyer segments instead of bulk discount buyers.',
    steps: <String>['Establish quality grades for crop', 'Sort produce by size/color/blemishes', 'Pack separately by grade', 'Sell premium separately for higher price'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'ms-1', prompt: 'Why sort by quality?', options: <String>['Access premium buyers and prices', 'Wastes effort', 'No difference'], correctOptionIndex: 0, explanation: 'Grading increases value.'),
      LessonQuestion(id: 'ms-2', prompt: 'Grade criteria?', options: <String>['Size, color, firmness, blemishes', 'Random', 'No criteria'], correctOptionIndex: 0, explanation: 'Consistent standards guide sorting.'),
      LessonQuestion(id: 'ms-3', prompt: 'Market advantage?', options: <String>['Premium grade fetches higher price', 'All same price', 'Lower for sorted'], correctOptionIndex: 0, explanation: 'Quality commands price premium.'),
    ],
    tools: <String>['Crates, labels'],
    youtubeVideoId: 'VKz6dNXzlFA',
    websiteUrl: 'https://www.fao.org/3/i5415e/i5415e.pdf',
  ),
  const LearningLesson(
    id: 'extra-073',
    title: 'Basic predator control',
    subtitle: 'Protect animals from common predators.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Practical',
    icon: Icons.shield_rounded,
    imageAsset: AppAssets.uiGallery03,
    overview: 'Secure housing and guard animals significantly reduce predator losses versus open grazing.',
    steps: <String>['Build secure night housing', 'Use predator-proof fencing', 'Consider guard animals', 'Use lights or noise deterrents'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'pc-1', prompt: 'Best predator prevention?', options: <String>['Secure housing and fencing', 'Leave open', 'Hope for best'], correctOptionIndex: 0, explanation: 'Confinement prevents access.'),
      LessonQuestion(id: 'pc-2', prompt: 'Guard animal roles?', options: <String>['Warn and defend against predators', 'Useless', 'Just feed waste'], correctOptionIndex: 0, explanation: 'Guard animals protect flocks.'),
      LessonQuestion(id: 'pc-3', prompt: 'Deterrent types?', options: <String>['Lights, noise, movement scare predators', 'Nothing works', 'No use'], correctOptionIndex: 0, explanation: 'Deterrents discourage attacks.'),
    ],
    tools: <String>['Locks, lights'],
    youtubeVideoId: 'bC_6sLvWaVQ',
    websiteUrl: 'https://www.sare.org/predator-protection/',
  ),
  const LearningLesson(
    id: 'extra-074',
    title: 'Quick drying racks',
    subtitle: 'Build simple racks for even produce drying.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFE9F4DB),
    track: 'Market access',
    difficulty: 'Practical',
    icon: Icons.view_agenda_rounded,
    imageAsset: AppAssets.uiGallery04,
    overview: 'Elevated racks with mesh allow airflow underneath for faster, more uniform drying.',
    steps: <String>['Build simple wooden frame', 'Add mesh or shade cloth', 'Elevate above ground', 'Turn produce daily for even drying'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'dr-1', prompt: 'Why elevate racks?', options: <String>['Allows airflow underneath for faster drying', 'Looks nice', 'No reason'], correctOptionIndex: 0, explanation: 'Air circulation speeds drying.'),
      LessonQuestion(id: 'dr-2', prompt: 'Mesh material purpose?', options: <String>['Allows air while supporting produce', 'Aesthetic', 'No purpose'], correctOptionIndex: 0, explanation: 'Mesh prevents damage while drying.'),
      LessonQuestion(id: 'dr-3', prompt: 'Turning frequency?', options: <String>['Daily for even drying', 'Never', 'Once per week'], correctOptionIndex: 0, explanation: 'Turning ensures uniformity.'),
    ],
    tools: <String>['Wood, mesh'],
    youtubeVideoId: 'qL5yLqZnBJQ',
    websiteUrl: 'https://www.fao.org/3/i3956e/i3956e.pdf',
  ),
  const LearningLesson(
    id: 'extra-075',
    title: 'Quick compost layering',
    subtitle: 'Layer materials for faster decomposition.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.layers_rounded,
    imageAsset: AppAssets.uiGallery05,
    overview: 'Alternating green and brown materials accelerates decomposition compared to random mixing.',
    steps: <String>['Collect green (nitrogen) materials', 'Collect brown (carbon) materials', 'Layer alternately', 'Water and turn regularly'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'cl-1', prompt: 'Green materials examples?', options: <String>['Grass clippings, manure, food scraps', 'Only brown', 'No greens'], correctOptionIndex: 0, explanation: 'Greens provide nitrogen.'),
      LessonQuestion(id: 'cl-2', prompt: 'Brown materials examples?', options: <String>['Leaves, straw, wood chips', 'Only green', 'No browns'], correctOptionIndex: 0, explanation: 'Browns provide carbon.'),
      LessonQuestion(id: 'cl-3', prompt: 'Layering benefit?', options: <String>['Speeds decomposition', 'No benefit', 'Slows process'], correctOptionIndex: 0, explanation: 'Balanced layers decompose faster.'),
    ],
    tools: <String>['Pitchfork'],
    youtubeVideoId: 'G5vLQVKE--8',
    websiteUrl: 'https://www.soilhealth.org/composting/',
  ),
  const LearningLesson(
    id: 'extra-076',
    title: 'Seed spacing',
    subtitle: 'Correct spacing improves yield and reduces disease.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.grid_on_rounded,
    imageAsset: AppAssets.uiGallery06,
    overview: 'Proper spacing allows light penetration and airflow reducing disease and competition.',
    steps: <String>['Know recommended spacing for crop', 'Mark rows consistently', 'Space plants or seeds', 'Thin excess seedlings'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'ss-1', prompt: 'Spacing importance?', options: <String>['Reduces competition and disease', 'No difference', 'Too complicated'], correctOptionIndex: 0, explanation: 'Spacing improves health and yield.'),
      LessonQuestion(id: 'ss-2', prompt: 'Air circulation benefit?', options: <String>['Dries leaves, prevents fungal disease', 'No benefit', 'Wastes water'], correctOptionIndex: 0, explanation: 'Airflow prevents diseases.'),
      LessonQuestion(id: 'ss-3', prompt: 'Crowded plant result?', options: <String>['Reduced size and yield', 'Bigger plants', 'No impact'], correctOptionIndex: 0, explanation: 'Competition stresses plants.'),
    ],
    tools: <String>['Measuring stick'],
    youtubeVideoId: 'Qz3KY5pXDWE',
    websiteUrl: 'https://www.almanac.com/gardening/spacing',
  ),
  const LearningLesson(
    id: 'extra-077',
    title: 'Quick water tests',
    subtitle: 'Check water quality for irrigation or livestock.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFEDE8FF),
    track: AppStrings.weatherForecast,
    difficulty: 'Practical',
    icon: Icons.water_damage_rounded,
    imageAsset: AppAssets.uiGallery07,
    overview: 'Simple water tests identify contamination before use on crops or animals.',
    steps: <String>['Collect sample in clean container', 'Check for cloudiness or color', 'Smell for odors', 'Observe floating matter'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'wt-1', prompt: 'Contamination signs?', options: <String>['Cloudiness, odor, color, matter', 'No signs', 'Always safe'], correctOptionIndex: 0, explanation: 'Visual signs indicate problems.'),
      LessonQuestion(id: 'wt-2', prompt: 'Test importance?', options: <String>['Prevents crop/animal harm', 'No benefit', 'Wastes time'], correctOptionIndex: 0, explanation: 'Testing protects farm.'),
      LessonQuestion(id: 'wt-3', prompt: 'Contaminated water use?', options: <String>['Discard or treat', 'Use anyway', 'No problem'], correctOptionIndex: 0, explanation: 'Contaminated water causes harm.'),
    ],
    tools: <String>['Container, test kit'],
    youtubeVideoId: 'M0gkI9aXMfU',
    websiteUrl: 'https://www.fao.org/3/i5773e/i5773e.pdf',
  ),
  const LearningLesson(
    id: 'extra-078',
    title: 'Quick market packing',
    subtitle: 'Pack to reduce bruising and loss.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFE9F4DB),
    track: 'Market access',
    difficulty: 'Practical',
    icon: Icons.inventory_2_rounded,
    imageAsset: AppAssets.uiGallery08,
    overview: 'Careful packing prevents bruising and quality loss that reduce market price.',
    steps: <String>['Layer delicate produce with padding', 'Avoid mixing hard and soft items', 'Fill crates firmly to prevent shifting', 'Label and stack safely'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'mp-1', prompt: 'Padding purpose?', options: <String>['Prevents bruising and damage', 'Just for looks', 'No use'], correctOptionIndex: 0, explanation: 'Protection maintains quality.'),
      LessonQuestion(id: 'mp-2', prompt: 'Why separate by type?', options: <String>['Prevents bruising of sensitive produce', 'No reason', 'Mix everything'], correctOptionIndex: 0, explanation: 'Mixing causes damage.'),
      LessonQuestion(id: 'mp-3', prompt: 'Proper crate fill?', options: <String>['Firm and full to prevent shifting', 'Loose', 'Leave space'], correctOptionIndex: 0, explanation: 'Fullness prevents movement.'),
    ],
    tools: <String>['Padding, crates'],
    youtubeVideoId: 'X8dQu4TyDe8',
    websiteUrl: 'https://www.fao.org/3/i5415e/i5415e.pdf',
  ),
  const LearningLesson(
    id: 'extra-079',
    title: 'Quick pasture checks',
    subtitle: 'Assess pasture condition for grazing decisions.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Practical',
    icon: Icons.park_rounded,
    imageAsset: AppAssets.uiGallery09,
    overview: 'Regular pasture assessment prevents overgrazing damage and maintains feed quality.',
    steps: <String>['Measure forage height regularly', 'Check for bare spots', 'Monitor plant health', 'Rotate grazing areas before overuse'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'pc-1', prompt: 'Overgrazing impacts?', options: <String>['Soil degradation and poor recovery', 'No problem', 'Improves pasture'], correctOptionIndex: 0, explanation: 'Overgrazing damages land.'),
      LessonQuestion(id: 'pc-2', prompt: 'Rotation benefits?', options: <String>['Allows recovery and prevents degradation', 'No benefit', 'Wastes pasture'], correctOptionIndex: 0, explanation: 'Rest allows regrowth.'),
      LessonQuestion(id: 'pc-3', prompt: 'Ideal forage height?', options: <String>['5-10 cm for cattle, varies by species', 'No height matters', 'Always short'], correctOptionIndex: 0, explanation: 'Height indicates ready-to-eat stage.'),
    ],
    tools: <String>['Stick measure'],
    youtubeVideoId: 'L3bQ5OU6DsQ',
    websiteUrl: 'https://www.sare.org/pasture-management/',
  ),
  const LearningLesson(
    id: 'extra-080',
    title: 'Simple curing',
    subtitle: 'Cure root crops to extend shelf life.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFDFF1FF),
    track: 'Market access',
    difficulty: 'Practical',
    icon: Icons.agriculture_rounded,
    imageAsset: AppAssets.uiGallery10,
    overview: 'Curing heals harvest wounds in root crops improving storage and preventing rot.',
    steps: <String>['Harvest and store in warm shade', 'Maintain 70-80°F and 85-90% humidity', 'Wait 2-3 weeks for wound healing', 'Move to cool storage afterward'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'cur-1', prompt: 'Curing purpose?', options: <String>['Heals wounds, prevents rot, extends storage', 'No benefit', 'Wastes time'], correctOptionIndex: 0, explanation: 'Curing improves shelf life significantly.'),
      LessonQuestion(id: 'cur-2', prompt: 'Ideal cure temperature?', options: <String>['70-80°F in humid conditions', 'Cold storage', 'Hot and dry'], correctOptionIndex: 0, explanation: 'Warm humidity encourages healing.'),
      LessonQuestion(id: 'cur-3', prompt: 'After curing, do what?', options: <String>['Move to cool storage', 'Leave outside', 'Discard'], correctOptionIndex: 0, explanation: 'Cool storage prevents sprouting.'),
    ],
    tools: <String>['Bins, shade'],
    youtubeVideoId: 'qL5yLqZnBJQ',
    websiteUrl: 'https://www.fao.org/3/i3097e/i3097e.pdf',
  ),
  const LearningLesson(
    id: 'extra-081',
    title: 'Quick soil moisture test',
    subtitle: 'Use the squeeze test to estimate moisture.',
    baseProgress: 0.05,
    duration: '2 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.soilManagement,
    difficulty: 'Field skill',
    icon: Icons.water_drop_rounded,
    imageAsset: AppAssets.uiGallery01,
    overview: 'Simple hand tests accurately indicate soil moisture without meters or equipment.',
    steps: <String>['Take handful of soil from 15cm deep', 'Feel texture: crumbly means dry', 'If sticky or forms ball, irrigate soon', 'Practice to recognize feel'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'smt-1', prompt: 'Dry soil feels?', options: <String>['Crumbly and falls apart', 'Sticky', 'Soaking wet'], correctOptionIndex: 0, explanation: 'Crumbling indicates low moisture.'),
      LessonQuestion(id: 'smt-2', prompt: 'Moist but adequate?', options: <String>['Forms ball but falls apart easily', 'Always wet', 'Always dry'], correctOptionIndex: 0, explanation: 'Ball that breaks shows good moisture.'),
      LessonQuestion(id: 'smt-3', prompt: 'Wet soil action?', options: <String>['Do not water, wait for drying', 'Water more', 'No difference'], correctOptionIndex: 0, explanation: 'Wet soil needs no irrigation.'),
    ],
    tools: <String>['Hands'],
    youtubeVideoId: 'xY7ZQR3PpKE',
    websiteUrl: 'https://www.soilhealth.org/moisture-test/',
  ),
  const LearningLesson(
    id: 'extra-082',
    title: 'Quick vehicle checks',
    subtitle: 'Simple checks before transport.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Practical',
    icon: Icons.directions_car_rounded,
    imageAsset: AppAssets.uiGallery02,
    overview: 'Pre-transport checks prevent breakdowns and accidents during market trips.',
    steps: <String>['Check tire pressure and condition', 'Test lights and brakes', 'Secure load with straps', 'Verify spare tire and tools'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'vc-1', prompt: 'Tire pressure importance?', options: <String>['Prevents blowouts and accidents', 'No difference', 'Guess pressure'], correctOptionIndex: 0, explanation: 'Proper pressure prevents failures.'),
      LessonQuestion(id: 'vc-2', prompt: 'Brake check purpose?', options: <String>['Safety for self and others', 'Not needed', 'No benefit'], correctOptionIndex: 0, explanation: 'Brakes ensure control.'),
      LessonQuestion(id: 'vc-3', prompt: 'Load securing needed?', options: <String>['Prevents spills and shifting', 'Optional', 'No benefit'], correctOptionIndex: 0, explanation: 'Securing prevents loss.'),
    ],
    tools: <String>['Pump, straps'],
    youtubeVideoId: 'L3bQ5OU6DsQ',
    websiteUrl: 'https://www.fao.org/3/i5415e/i5415e.pdf',
  ),
  const LearningLesson(
    id: 'extra-083',
    title: 'Quick spraying safety',
    subtitle: 'Protect workers and the environment when spraying.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFE9F4DB),
    track: AppStrings.cropAdvice,
    difficulty: 'Essential',
    icon: Icons.health_and_safety_rounded,
    imageAsset: AppAssets.uiGallery03,
    overview: 'Proper safety practices prevent poisoning and environmental contamination.',
    steps: <String>['Wear full PPE: gloves, mask, goggles', 'Check wind direction', 'Spray early morning when calm', 'Never exceed label rates'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'ss-1', prompt: 'PPE includes?', options: <String>['Gloves, mask, goggles, coveralls', 'No PPE needed', 'Just shirt'], correctOptionIndex: 0, explanation: 'Full PPE prevents absorption.'),
      LessonQuestion(id: 'ss-2', prompt: 'Wind direction importance?', options: <String>['Prevents drift to unintended areas', 'No difference', 'Ignore wind'], correctOptionIndex: 0, explanation: 'Wind control prevents drift damage.'),
      LessonQuestion(id: 'ss-3', prompt: 'Label rate necessity?', options: <String>['Prevents overdose and harm', 'More is better', 'Ignore labels'], correctOptionIndex: 0, explanation: 'Rates are scientifically determined.'),
    ],
    tools: <String>['PPE, sprayer'],
    youtubeVideoId: 'Aa8T1wGvPmM',
    websiteUrl: 'https://www.fao.org/3/i3956e/i3956e.pdf',
  ),
  const LearningLesson(
    id: 'extra-084',
    title: 'Quick seed testing',
    subtitle: 'Germination test to check seed quality.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.fact_check_rounded,
    imageAsset: AppAssets.uiGallery04,
    overview: 'Pre-planting germination tests prevent wasting seed and land on poor lots.',
    steps: <String>['Take 100 seeds from lot', 'Place on moist paper towel', 'Keep moist and warm for 7-10 days', 'Count germinated seeds for viability %'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'st-1', prompt: 'Why test seeds?', options: <String>['Know viability before planting', 'Waste time', 'Always plant'], correctOptionIndex: 0, explanation: 'Testing prevents crop failure.'),
      LessonQuestion(id: 'st-2', prompt: 'Good germination rate?', options: <String>['85-90%+ for most crops', 'Any rate works', 'Only 50%'], correctOptionIndex: 0, explanation: 'High viability ensures stands.'),
      LessonQuestion(id: 'st-3', prompt: 'Low viability result?', options: <String>['Get better seed or increase rate', 'Plant anyway', 'No change needed'], correctOptionIndex: 0, explanation: 'Poor seed needs adjustment.'),
    ],
    tools: <String>['Paper, water'],
    youtubeVideoId: 'bC_6sLvWaVQ',
    websiteUrl: 'https://www.fao.org/3/i5773e/i5773e.pdf',
  ),
  const LearningLesson(
    id: 'extra-085',
    title: 'Quick market contacts',
    subtitle: 'Keep a short list of reliable buyers.',
    baseProgress: 0.05,
    duration: '2 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.contacts_rounded,
    imageAsset: AppAssets.uiGallery05,
    overview: 'Reliable buyer network reduces marketing effort and uncertainty.',
    steps: <String>['Identify 3-5 reliable buyers', 'Record phone, location, preferences', 'Note typical price for crops', 'Update after each transaction'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'mc-1', prompt: 'Buyer list benefit?', options: <String>['Quick, reliable market access', 'Wastes time', 'No benefit'], correctOptionIndex: 0, explanation: 'Networks reduce marketing cost.'),
      LessonQuestion(id: 'mc-2', prompt: 'Info to record?', options: <String>['Phone, location, crop preferences', 'Nothing', 'Just name'], correctOptionIndex: 0, explanation: 'Details enable quick sales.'),
      LessonQuestion(id: 'mc-3', prompt: 'Update frequency?', options: <String>['After each sale to stay current', 'Never', 'Once yearly'], correctOptionIndex: 0, explanation: 'Updates ensure accuracy.'),
    ],
    tools: <String>['Phone, notebook'],
    youtubeVideoId: 'D5MwI1cFJYg',
    websiteUrl: 'https://www.fao.org/3/ca5162en/ca5162en.pdf',
  ),
  const LearningLesson(
    id: 'extra-086',
    title: 'Quick feed storage',
    subtitle: 'Store feed to avoid spoilage and pests.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Practical',
    icon: Icons.store_rounded,
    imageAsset: AppAssets.uiGallery06,
    overview: 'Proper storage protects feed quality and reduces losses to pests.',
    steps: <String>['Use sealed, airtight containers', 'Elevate off floor on pallets', 'Keep in cool, dry location', 'Monitor for pests regularly'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'fs-1', prompt: 'Sealed containers prevent?', options: <String>['Moisture and pest entry', 'No benefit', 'Unnecessary'], correctOptionIndex: 0, explanation: 'Sealing preserves quality.'),
      LessonQuestion(id: 'fs-2', prompt: 'Why elevate storage?', options: <String>['Prevents floor moisture and rodents', 'No reason', 'Wastes space'], correctOptionIndex: 0, explanation: 'Height prevents ground contact.'),
      LessonQuestion(id: 'fs-3', prompt: 'Storage location?', options: <String>['Cool and dry to prevent spoilage', 'Hot and wet', 'No difference'], correctOptionIndex: 0, explanation: 'Environment affects shelf life.'),
    ],
    tools: <String>['Containers, pallets'],
    youtubeVideoId: 'qEYn-BzPy1g',
    websiteUrl: 'https://www.sare.org/feed-storage/',
  ),
  const LearningLesson(
    id: 'extra-087',
    title: 'Quick pest thresholds',
    subtitle: 'When action is needed versus monitoring.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFE9F4DB),
    track: AppStrings.cropAdvice,
    difficulty: 'Field skill',
    icon: Icons.rule_rounded,
    imageAsset: AppAssets.uiGallery07,
    overview: 'Pest thresholds guide control decisions avoiding spraying costs when monitoring suffices.',
    steps: <String>['Know economic threshold for crop', 'Scout regularly', 'Count affected plants', 'Spray only when threshold exceeded'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'pt-1', prompt: 'Threshold purpose?', options: <String>['Guides when to spray for profit', 'Always spray', 'Never spray'], correctOptionIndex: 0, explanation: 'Thresholds improve economics.'),
      LessonQuestion(id: 'pt-2', prompt: 'Below-threshold pests?', options: <String>['Monitor, do not spray yet', 'Spray anyway', 'Ignore'], correctOptionIndex: 0, explanation: 'Monitoring saves costs.'),
      LessonQuestion(id: 'pt-3', prompt: 'Above-threshold action?', options: <String>['Spray or use other control', 'Ignore', 'Hope it stops'], correctOptionIndex: 0, explanation: 'Action prevents crop loss.'),
    ],
    tools: <String>['Notebook'],
    youtubeVideoId: 'rJ5iEQKX_-I',
    websiteUrl: 'https://www.fao.org/3/i3956e/i3956e.pdf',
  ),
  const LearningLesson(
    id: 'extra-088',
    title: 'Quick pruning schedule',
    subtitle: 'Set pruning times by crop growth stage.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.calendar_month_rounded,
    imageAsset: AppAssets.uiGallery08,
    overview: 'Scheduled pruning at growth stages optimizes plant form and productivity.',
    steps: <String>['Identify key growth stages', 'Plan pruning dates', 'Record schedule yearly', 'Adjust based on weather'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'prs-1', prompt: 'Pruning timing importance?', options: <String>['Growth stage matters for response', 'Anytime is fine', 'Never prune'], correctOptionIndex: 0, explanation: 'Timing affects recovery.'),
      LessonQuestion(id: 'prs-2', prompt: 'Overgrown result?', options: <String>['Reduced fruiting and disease', 'Better production', 'No change'], correctOptionIndex: 0, explanation: 'Dense canopy traps moisture.'),
      LessonQuestion(id: 'prs-3', prompt: 'Schedule benefit?', options: <String>['Ensures consistent maintenance', 'Wastes time', 'Unnecessary'], correctOptionIndex: 0, explanation: 'Planning enables efficiency.'),
    ],
    tools: <String>['Calendar, pruner'],
    youtubeVideoId: 'bW6qRNxRbqE',
    websiteUrl: 'https://www.almanac.com/gardening/pruning',
  ),
  const LearningLesson(
    id: 'extra-089',
    title: 'Quick sales invoicing',
    subtitle: 'Create a simple invoice for larger buyers.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.receipt_rounded,
    imageAsset: AppAssets.uiGallery09,
    overview: 'Professional invoices build buyer confidence and reduce payment disputes.',
    steps: <String>['Create simple invoice template', 'List goods, quantities, unit prices', 'Calculate total amount due', 'Keep copies for records'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'inv-1', prompt: 'Invoice purpose?', options: <String>['Documents sale and payment terms', 'Wastes paper', 'No use'], correctOptionIndex: 0, explanation: 'Invoices prevent disputes.'),
      LessonQuestion(id: 'inv-2', prompt: 'Invoice contents?', options: <String>['Item, quantity, price, total', 'Just total', 'No details'], correctOptionIndex: 0, explanation: 'Details ensure clarity.'),
      LessonQuestion(id: 'inv-3', prompt: 'Records kept?', options: <String>['Copies for future reference', 'Discard', 'Memory only'], correctOptionIndex: 0, explanation: 'Records prove transactions.'),
    ],
    tools: <String>['Invoice book, phone'],
    youtubeVideoId: 'X8dQu4TyDe8',
    websiteUrl: 'https://www.fao.org/3/i5415e/i5415e.pdf',
  ),
  const LearningLesson(
    id: 'extra-090',
    title: 'Simple weed barriers',
    subtitle: 'Use physical barriers for persistent weeds.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.block_rounded,
    imageAsset: AppAssets.uiGallery10,
    overview: 'Physical barriers eliminate persistent weeds without chemicals.',
    steps: <String>['Select barrier material', 'Lay over area', 'Secure edges with mulch or pegs', 'Cut holes for planting'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'wb-1', prompt: 'Barrier types?', options: <String>['Landscape fabric or plastic', 'Nothing works', 'Only chemicals'], correctOptionIndex: 0, explanation: 'Physical barriers block light.'),
      LessonQuestion(id: 'wb-2', prompt: 'Barrier benefit?', options: <String>['Eliminates persistent weeds', 'Wasted effort', 'No benefit'], correctOptionIndex: 0, explanation: 'Barriers are effective.'),
      LessonQuestion(id: 'wb-3', prompt: 'Long-term solution?', options: <String>['Yes, can last 5+ years', 'Temporary', 'Worthless'], correctOptionIndex: 0, explanation: 'Quality barriers persist.'),
    ],
    tools: <String>['Fabric, pegs'],
    youtubeVideoId: 'E5Z0G9W8pRo',
    websiteUrl: 'https://www.gardenmyths.com/landscape-fabric/',
  ),
  const LearningLesson(
    id: 'extra-091',
    title: 'Quick disease records',
    subtitle: 'Log disease cases to spot patterns early.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.note_alt_rounded,
    imageAsset: AppAssets.uiGallery01,
    overview: 'Disease records reveal patterns enabling early prevention of future outbreaks.',
    steps: <String>['Record date disease appears', 'Note affected field section', 'Describe symptoms and extent', 'Take photo for reference'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'dr-1', prompt: 'Record importance?', options: <String>['Reveals patterns and trends', 'Wastes time', 'No benefit'], correctOptionIndex: 0, explanation: 'Patterns guide prevention.'),
      LessonQuestion(id: 'dr-2', prompt: 'Include in records?', options: <String>['Date, location, symptoms, photos', 'Just name', 'Nothing matters'], correctOptionIndex: 0, explanation: 'Details enable analysis.'),
      LessonQuestion(id: 'dr-3', prompt: 'Use of records?', options: <String>['Plan prevention for next year', 'Ignore', 'Forget it'], correctOptionIndex: 0, explanation: 'History informs planning.'),
    ],
    tools: <String>['Phone, notebook'],
    youtubeVideoId: 'rJ5iEQKX_-I',
    websiteUrl: 'https://www.fao.org/3/i3956e/i3956e.pdf',
  ),
  const LearningLesson(
    id: 'extra-092',
    title: 'Quick market sample prep',
    subtitle: 'Prepare a representative sample for buyer inspection.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Practical',
    icon: Icons.inventory_2_rounded,
    imageAsset: AppAssets.uiGallery02,
    overview: 'Quality samples give buyers confidence and lead to better offers.',
    steps: <String>['Select average-quality produce', 'Include variety of sizes', 'Package neatly in display', 'Present cleanly at market'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'msp-1', prompt: 'Sample represents?', options: <String>['True crop quality, not cherry-picked', 'Only best fruit', 'Worst examples'], correctOptionIndex: 0, explanation: 'Honest sampling builds trust.'),
      LessonQuestion(id: 'msp-2', prompt: 'Presentation matters?', options: <String>['Yes, affects buyer perception', 'No difference', 'Ignore'], correctOptionIndex: 0, explanation: 'Appearance influences offers.'),
      LessonQuestion(id: 'msp-3', prompt: 'Sample benefit?', options: <String>['Buyers see quality, offer better price', 'No impact', 'Lowers price'], correctOptionIndex: 0, explanation: 'Quality samples justify premiums.'),
    ],
    tools: <String>['Tray, cloth'],
    youtubeVideoId: 'VKz6dNXzlFA',
    websiteUrl: 'https://www.fao.org/3/i5415e/i5415e.pdf',
  ),
  const LearningLesson(
    id: 'extra-093',
    title: 'Quick parasite checks',
    subtitle: 'Spot common external parasites on livestock.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFFFEBCF),
    track: AppStrings.animalHealth,
    difficulty: 'Field skill',
    icon: Icons.bug_report_rounded,
    imageAsset: AppAssets.uiGallery03,
    overview: 'Regular parasite checks prevent blood loss and disease from ticks and lice.',
    steps: <String>['Inspect skin and coat', 'Check ears and around eyes', 'Look for movement or bites', 'Apply recommended treatment'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'pc-1', prompt: 'Tick signs?', options: <String>['Embedded in skin, blood loss', 'Just cosmetic', 'No problem'], correctOptionIndex: 0, explanation: 'Ticks feed on blood.'),
      LessonQuestion(id: 'pc-2', prompt: 'Lice impacts?', options: <String>['Itching, hair loss, stress', 'No effect', 'Helps animal'], correctOptionIndex: 0, explanation: 'Lice cause discomfort.'),
      LessonQuestion(id: 'pc-3', prompt: 'Check frequency?', options: <String>['Monthly or after grazing in brush', 'Never', 'Once yearly'], correctOptionIndex: 0, explanation: 'Regular checks catch infestations.'),
    ],
    tools: <String>['Tick remover, treatment'],
    youtubeVideoId: 'bC_6sLvWaVQ',
    websiteUrl: 'https://www.sare.org/parasite-management/',
  ),
  const LearningLesson(
    id: 'extra-094',
    title: 'Quick irrigation mapping',
    subtitle: 'Map zones to manage water application uniformly.',
    baseProgress: 0.05,
    duration: '4 min',
    tint: Color(0xFFDFF1FF),
    track: AppStrings.soilManagement,
    difficulty: 'Practical',
    icon: Icons.map_rounded,
    imageAsset: AppAssets.uiGallery04,
    overview: 'Mapped zones enable consistent water management and problem identification.',
    steps: <String>['Observe field for variations', 'Mark high, medium, low areas', 'Note slope and soil differences', 'Create simple map reference'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'im-1', prompt: 'Zone benefits?', options: <String>['Different areas get appropriate water', 'No difference', 'Wastes time'], correctOptionIndex: 0, explanation: 'Zones enable tuning.'),
      LessonQuestion(id: 'im-2', prompt: 'Variation sources?', options: <String>['Slope, soil type, drainage', 'No variations', 'Ignore'], correctOptionIndex: 0, explanation: 'Topology affects water.'),
      LessonQuestion(id: 'im-3', prompt: 'Low zone issue?', options: <String>['Waterlogging if over-irrigated', 'No problems', 'Ignore'], correctOptionIndex: 0, explanation: 'Low areas retain moisture.'),
    ],
    tools: <String>['Flags, map'],
    youtubeVideoId: 'Ln_yKvE2-zI',
    websiteUrl: 'https://www.fao.org/3/i5773e/i5773e.pdf',
  ),
  const LearningLesson(
    id: 'extra-095',
    title: 'Quick seed calibration',
    subtitle: 'Calibrate seeders for correct seeding rate.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFE9F4DB),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.precision_manufacturing_rounded,
    imageAsset: AppAssets.uiGallery05,
    overview: 'Calibration ensures target plant population improving uniformity and yield.',
    steps: <String>['Read seeder manual for target rate', 'Test output over known distance', 'Count seeds collected', 'Adjust opening or speed'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'sc-1', prompt: 'Calibration importance?', options: <String>['Achieves target stand density', 'No difference', 'Wastes time'], correctOptionIndex: 0, explanation: 'Correct population matters.'),
      LessonQuestion(id: 'sc-2', prompt: 'Test method?', options: <String>['Collect seeds over measured run', 'Guess', 'No testing'], correctOptionIndex: 0, explanation: 'Testing provides data.'),
      LessonQuestion(id: 'sc-3', prompt: 'Adjustment options?', options: <String>['Change opening size or speed', 'Cannot adjust', 'Try luck'], correctOptionIndex: 0, explanation: 'Adjustments fine-tune rate.'),
    ],
    tools: <String>['Container, measure tape'],
    youtubeVideoId: 'bW6qRNxRbqE',
    websiteUrl: 'https://www.almanac.com/gardening/seeding',
  ),
  const LearningLesson(
    id: 'extra-096',
    title: 'Quick transport checks',
    subtitle: 'Secure produce and check vehicle readiness.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFEDE8FF),
    track: 'Market access',
    difficulty: 'Practical',
    icon: Icons.local_shipping_rounded,
    imageAsset: AppAssets.uiGallery06,
    overview: 'Secure loads prevent spillage and loss during transport.',
    steps: <String>['Use straps across crates', 'Cover loads if needed', 'Check tie-downs secure', 'Test before departing'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'tc-1', prompt: 'Strap necessity?', options: <String>['Prevents shifting and spills', 'Optional', 'No need'], correctOptionIndex: 0, explanation: 'Straps secure cargo.'),
      LessonQuestion(id: 'tc-2', prompt: 'Cover protects?', options: <String>['Rain, wind, UV damage', 'No benefit', 'Trap heat'], correctOptionIndex: 0, explanation: 'Covers protect produce.'),
      LessonQuestion(id: 'tc-3', prompt: 'Tie-down check?', options: <String>['Ensure tight before trip', 'Do not check', 'Loose is OK'], correctOptionIndex: 0, explanation: 'Secure tie-downs prevent loss.'),
    ],
    tools: <String>['Straps, tarpaulin'],
    youtubeVideoId: 'X8dQu4TyDe8',
    websiteUrl: 'https://www.fao.org/3/i5415e/i5415e.pdf',
  ),
  const LearningLesson(
    id: 'extra-097',
    title: 'Quick pruning safety',
    subtitle: 'Protect yourself when pruning trees.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.cropAdvice,
    difficulty: 'Essential',
    icon: Icons.security_rounded,
    imageAsset: AppAssets.uiGallery07,
    overview: 'Proper safety technique prevents cuts and eye injuries during pruning.',
    steps: <String>['Wear gloves and safety goggles', 'Cut away from body', 'Secure tools when not in use', 'Seek first aid for injuries'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'ps-1', prompt: 'Required PPE?', options: <String>['Gloves and goggles always', 'No PPE', 'Optional'], correctOptionIndex: 0, explanation: 'PPE prevents injuries.'),
      LessonQuestion(id: 'ps-2', prompt: 'Cut direction?', options: <String>['Away from body and others', 'Toward self', 'Any direction'], correctOptionIndex: 0, explanation: 'Direction prevents cuts.'),
      LessonQuestion(id: 'ps-3', prompt: 'Eye protection purpose?', options: <String>['Prevents branch and debris injury', 'Not needed', 'Unnecessary'], correctOptionIndex: 0, explanation: 'Goggles guard eyes.'),
    ],
    tools: <String>['Gloves, goggles'],
    youtubeVideoId: 'Aa8T1wGvPmM',
    websiteUrl: 'https://www.fao.org/3/i3956e/i3956e.pdf',
  ),
  const LearningLesson(
    id: 'extra-098',
    title: 'Quick harvest checks',
    subtitle: 'Final checks before harvest to protect quality.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFEDE8FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.check_rounded,
    imageAsset: AppAssets.uiGallery08,
    overview: 'Pre-harvest checks prevent problems and ensure timely, quality harvesting.',
    steps: <String>['Check soil moisture for firmness', 'Inspect for pests or disease', 'Ensure workers and tools ready', 'Start harvest when conditions right'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'hc-1', prompt: 'Moisture importance?', options: <String>['Affects handling and post-harvest quality', 'No difference', 'Irrelevant'], correctOptionIndex: 0, explanation: 'Moisture influences spoilage.'),
      LessonQuestion(id: 'hc-2', prompt: 'Pest inspection goal?', options: <String>['Avoid packaging infested crop', 'No inspection', 'Ignore pests'], correctOptionIndex: 0, explanation: 'Detection prevents loss.'),
      LessonQuestion(id: 'hc-3', prompt: 'Readiness check?', options: <String>['Prevents delays and damage', 'No benefit', 'Wastes time'], correctOptionIndex: 0, explanation: 'Preparation ensures efficiency.'),
    ],
    tools: <String>['Moisture tester, tools'],
    youtubeVideoId: 'A9m3YC_sKOU',
    websiteUrl: 'https://www.almanac.com/gardening/harvest-guide',
  ),
  const LearningLesson(
    id: 'extra-099',
    title: 'Quick farm safety',
    subtitle: 'Basic safety habits to reduce accidents.',
    baseProgress: 0.05,
    duration: '3 min',
    tint: Color(0xFFE9F4DB),
    track: AppStrings.cropAdvice,
    difficulty: 'Essential',
    icon: Icons.warning_rounded,
    imageAsset: AppAssets.uiGallery09,
    overview: 'Consistent safety practices significantly reduce farm injuries and illness.',
    steps: <String>['Wear PPE for all fieldwork', 'Keep tools tidy and secure', 'Store chemicals safely away from animals', 'Know first aid response'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'fs-1', prompt: 'PPE always?', options: <String>['Yes, reduces injury risk', 'Optional', 'No PPE needed'], correctOptionIndex: 0, explanation: 'PPE is protection.'),
      LessonQuestion(id: 'fs-2', prompt: 'Chemical storage?', options: <String>['Locked cabinet away from animals', 'Open storage', 'Any location'], correctOptionIndex: 0, explanation: 'Proper storage prevents poisoning.'),
      LessonQuestion(id: 'fs-3', prompt: 'Injury response?', options: <String>['First aid and medical help', 'Ignore', 'Hope it heals'], correctOptionIndex: 0, explanation: 'Prompt response prevents complications.'),
    ],
    tools: <String>['PPE, lockable cabinet'],
    youtubeVideoId: 'Aa8T1wGvPmM',
    websiteUrl: 'https://www.fao.org/3/i3956e/i3956e.pdf',
  ),
  const LearningLesson(
    id: 'extra-100',
    title: 'Quick planning review',
    subtitle: 'Review the week and set three actions for next week.',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFDFF1FF),
    track: 'Market access',
    difficulty: 'Business',
    icon: Icons.event_note_rounded,
    imageAsset: AppAssets.uiGallery10,
    overview: 'Weekly reflection improves decision-making and ensures continuous farm improvement.',
    steps: <String>['List three wins from week', 'Note three challenges or losses', 'Set three specific actions for next week', 'Record in farm journal'],
    questions: <LessonQuestion>[
      LessonQuestion(id: 'pr-1', prompt: 'Planning review benefit?', options: <String>['Improves decisions, tracks progress', 'Wastes time', 'No benefit'], correctOptionIndex: 0, explanation: 'Reflection drives improvement.'),
      LessonQuestion(id: 'pr-2', prompt: 'Include in review?', options: <String>['Wins, challenges, next actions', 'Just wins', 'Random notes'], correctOptionIndex: 0, explanation: 'Balanced review is effective.'),
      LessonQuestion(id: 'pr-3', prompt: 'Action setting importance?', options: <String>['Moves farm forward progressively', 'No action needed', 'Just review'], correctOptionIndex: 0, explanation: 'Actions drive improvement.'),
    ],
    tools: <String>['Notebook, pen'],
    youtubeVideoId: 'D5MwI1cFJYg',
    websiteUrl: 'https://www.fao.org/3/ca5162en/ca5162en.pdf',
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
