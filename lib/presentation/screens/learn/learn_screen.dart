import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<LearningLesson> featuredLessons = <LearningLesson>[
      const LearningLesson(
        title: 'Managing soil moisture',
        subtitle: 'A short field guide for dry-season irrigation balance.',
        progress: 0.72,
        duration: '8 min',
        tint: Color(0xFFDFF1FF),
        track: 'Soil management',
        difficulty: 'Practical',
        overview:
            'Learn how to observe moisture loss, match watering to crop stage, and avoid wasting labour or water in dry periods.',
        steps: <String>[
          'Check the top soil early in the morning before irrigation.',
          'Group beds by crop stage so young plants get priority water.',
          'Mulch exposed areas to slow surface drying.',
          'Record stress signs like curling leaves or blossom drop.',
        ],
      ),
      const LearningLesson(
        title: 'Livestock vaccination basics',
        subtitle: 'Simple health routines for smallholder teams.',
        progress: 0.48,
        duration: '12 min',
        tint: Color(0xFFE9F4DB),
        track: 'Animal health',
        difficulty: 'Essential',
        overview:
            'Build a reliable vaccination routine, reduce avoidable disease losses, and keep cleaner treatment records for every group.',
        steps: <String>[
          'Keep a dated vaccine calendar by species and age group.',
          'Store vaccines correctly and avoid using expired doses.',
          'Separate treated animals so follow-up is easier to track.',
          'Log reactions, missed doses, and the next health action.',
        ],
      ),
      const LearningLesson(
        title: 'Reading market timing',
        subtitle: 'When to sell produce and when to hold stock a little longer.',
        progress: 0.23,
        duration: '10 min',
        tint: Color(0xFFFFEBCF),
        track: 'Market access',
        difficulty: 'Business',
        overview:
            'Compare timing, spoilage risk, transport cost, and demand signals so you can choose better selling windows.',
        steps: <String>[
          'Watch weekly price changes for your main produce.',
          'Estimate transport and handling before deciding to wait.',
          'Compare buyers by reliability, not just headline price.',
          'Match harvest planning to expected market demand peaks.',
        ],
      ),
    ];

    final List<LearningTrack> tracks = <LearningTrack>[
      const LearningTrack(
        title: AppStrings.cropAdvice,
        icon: Icons.spa_rounded,
        detail: '16 lessons',
        color: Color(0xFFE9F4DB),
        summary: 'Crop planning, field care, growth stages, and harvest-readiness lessons.',
      ),
      const LearningTrack(
        title: AppStrings.animalHealth,
        icon: Icons.pets_rounded,
        detail: '09 lessons',
        color: Color(0xFFFFEBD0),
        summary: 'Vaccination routines, hygiene, feeding, breeding, and disease response basics.',
      ),
      const LearningTrack(
        title: AppStrings.soilManagement,
        icon: Icons.landscape_rounded,
        detail: '11 lessons',
        color: Color(0xFFDFF1FF),
        summary: 'Moisture, fertility, structure, erosion prevention, and practical soil observations.',
      ),
      const LearningTrack(
        title: AppStrings.weatherForecast,
        icon: Icons.wb_sunny_outlined,
        detail: '05 lessons',
        color: Color(0xFFFFF0C9),
        summary: 'Weather interpretation, timing decisions, and work planning around field conditions.',
      ),
    ];

    final List<PracticeActivity> activities = <PracticeActivity>[
      const PracticeActivity(
        title: 'Field checklist',
        subtitle: 'Walk your crop rows and mark irrigation stress, weed pressure, and flowering changes.',
        icon: Icons.fact_check_rounded,
        color: Color(0xFFE8F4D8),
        checklist: <String>[
          'Inspect wilting, yellowing, and pest pressure by section.',
          'Mark beds that need irrigation or mulching first.',
          'Note any flowering or fruit set changes in the log.',
        ],
      ),
      const PracticeActivity(
        title: 'Weekly quiz',
        subtitle: 'A quick five-question check on disease prevention and livestock hygiene.',
        icon: Icons.quiz_rounded,
        color: Color(0xFFDFF1FF),
        checklist: <String>[
          'Answer five short questions from this week’s lessons.',
          'Review missed answers and reopen the related lesson.',
          'Set one improvement action for the next farm week.',
        ],
      ),
      const PracticeActivity(
        title: 'Community notes',
        subtitle: 'Save what worked on your farm so the next lesson stays practical.',
        icon: Icons.edit_note_rounded,
        color: Color(0xFFFFEBD0),
        checklist: <String>[
          'Write one local practice that worked well this week.',
          'Attach yield, animal, or weather context to the note.',
          'Share lessons worth repeating next season.',
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SoftScreenScaffold(
        heroTitle: 'Learning hub',
        heroSubtitle: 'Lessons, progress tracking, field practice, and short guides come together in one study space.',
        heroIcon: Icons.menu_book_rounded,
        heroVariant: FarmArtworkVariant.field,
        heroBadge: '12 active lessons',
        sections: <Widget>[
          const SoftSectionTitle(title: 'Learning progress'),
          Row(
            children: const <Widget>[
              Expanded(
                child: SoftInfoChip(
                  label: AppStrings.lessons,
                  value: '12',
                  color: Color(0xFFDFF1FF),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: SoftInfoChip(
                  label: AppStrings.progress,
                  value: '68%',
                  color: Color(0xFFE8F4D8),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: SoftInfoChip(
                  label: AppStrings.completed,
                  value: '07',
                  color: Color(0xFFFFEBCF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SoftSectionTitle(
            title: AppStrings.continueLearning,
            action: Text(
              'Tap to open',
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          ...featuredLessons.map(
            (LearningLesson lesson) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LessonCard(
                lesson: lesson,
                onTap: () => _openPage(
                  context,
                  LearnLessonDetailScreen(lesson: lesson),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Learning tracks'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            childAspectRatio: 1.12,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: tracks
                .map(
                  (LearningTrack track) => _TopicCard(
                    track: track,
                    onTap: () => _openPage(
                      context,
                      LearnTrackDetailScreen(
                        track: track,
                        lessons: featuredLessons.where((LearningLesson lesson) => lesson.track == track.title).toList(),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          const SoftSectionTitle(title: 'Practice activities'),
          ...activities.map(
            (PracticeActivity activity) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PracticeCard(
                activity: activity,
                onTap: () => _openPage(
                  context,
                  LearnPracticeDetailScreen(activity: activity),
                ),
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

class LearnLessonDetailScreen extends StatelessWidget {
  const LearnLessonDetailScreen({
    super.key,
    required this.lesson,
  });

  final LearningLesson lesson;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SoftScreenScaffold(
        heroTitle: lesson.title,
        heroSubtitle: lesson.subtitle,
        heroIcon: Icons.play_lesson_rounded,
        heroVariant: FarmArtworkVariant.crops,
        heroBadge: '${lesson.duration} • ${lesson.difficulty}',
        sections: <Widget>[
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
                  label: 'Progress',
                  value: '${(lesson.progress * 100).round()}%',
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
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Use this lesson as a quick reference while you are planning work in the field.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppButton.primary(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to learn'),
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

class LearnTrackDetailScreen extends StatelessWidget {
  const LearnTrackDetailScreen({
    super.key,
    required this.track,
    required this.lessons,
  });

  final LearningTrack track;
  final List<LearningLesson> lessons;

  @override
  Widget build(BuildContext context) {
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
        heroBadge: track.detail,
        sections: <Widget>[
          const SoftSectionTitle(title: 'Track summary'),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'This track helps you build confidence through short practical lessons you can revisit during the season.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
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

class LearnPracticeDetailScreen extends StatelessWidget {
  const LearnPracticeDetailScreen({
    super.key,
    required this.activity,
  });

  final PracticeActivity activity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(activity.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SoftScreenScaffold(
        heroTitle: activity.title,
        heroSubtitle: activity.subtitle,
        heroIcon: activity.icon,
        heroVariant: FarmArtworkVariant.dashboard,
        heroBadge: 'Practice activity',
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
                'Practice activities turn the lesson into something observable on your actual farm, so learning stays useful and memorable.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.onTap,
  });

  final LearningLesson lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: lesson.tint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.play_lesson_rounded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    lesson.title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lesson.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MiniMeta(
                        text: '${(lesson.progress * 100).round()}%',
                        color: const Color(0xFFE8F4D8),
                      ),
                      _MiniMeta(text: lesson.duration, color: const Color(0xFFDFF1FF)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
    required this.onTap,
  });

  final LearningTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: track.color,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(track.icon),
            ),
            const Spacer(),
            Text(track.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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
    required this.onTap,
  });

  final PracticeActivity activity;
  final VoidCallback onTap;

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
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            activity.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
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

class LearningLesson {
  const LearningLesson({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.duration,
    required this.tint,
    required this.track,
    required this.difficulty,
    required this.overview,
    required this.steps,
  });

  final String title;
  final String subtitle;
  final double progress;
  final String duration;
  final Color tint;
  final String track;
  final String difficulty;
  final String overview;
  final List<String> steps;
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
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.checklist,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> checklist;
}
