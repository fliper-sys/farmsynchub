import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/firebase_messaging_service.dart';
import '../core/services/learning_reminder_service.dart';
import 'app_preferences_provider.dart';
import 'engagement_provider.dart';

final learningReminderSettingsProvider =
    NotifierProvider<LearningReminderSettingsNotifier, LearningReminderSettings>(
        LearningReminderSettingsNotifier.new);

class LearningReminderSettingsNotifier
    extends Notifier<LearningReminderSettings> {
  @override
  LearningReminderSettings build() {
    unawaited(_load());
    return const LearningReminderSettings();
  }

  Future<void> _load() async {
    state = await LearningReminderSettings.load();
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await state.save();
  }

  Future<void> setTime(int hour, int minute) async {
    state = state.copyWith(hour: hour, minute: minute);
    await state.save();
  }
}

/// Keeps the queued reminders in step with the learner's progress.
///
/// Rebuilds the schedule when the streak or today's lesson changes, when the
/// language or the reminder settings change, and when the app is reopened.
class LearningReminderBinder extends ConsumerStatefulWidget {
  const LearningReminderBinder({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LearningReminderBinder> createState() =>
      _LearningReminderBinderState();
}

class _LearningReminderBinderState extends ConsumerState<LearningReminderBinder>
    with WidgetsBindingObserver {
  String _lastSignature = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastSignature = ''; // A new day may have started: rebuild the queue.
      _schedule();
    }
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _apply);
  }

  Future<void> _apply() async {
    if (!mounted) return;
    final EngagementState engagement = ref.read(engagementProvider);
    final AppLanguage language = ref.read(appLanguageProvider);
    final LearningReminderSettings settings =
        ref.read(learningReminderSettingsProvider);
    if (!engagement.isLoaded) return;
    final DateTime now = engagement.trusted(DateTime.now());
    final StreakInfo info = engagement.streakInfo(now);
    final String signature = <Object>[
      engagement.isDoneToday(now),
      info.count,
      info.status.name,
      engagement.lessonsCompleted == 0,
      language.name,
      settings.enabled,
      settings.hour,
      settings.minute,
      '${now.year}-${now.month}-${now.day}',
    ].join('|');
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    await LearningReminderService.instance.reschedule(
      engagement: engagement,
      language: language,
      settings: settings,
      now: now,
    );
    // Optional online push: a topic per language that the team can message
    // from the Firebase console or a Cloud Function.
    try {
      await ref
          .read(firebaseMessagingServiceProvider)
          .syncLearningTopic(language: language.name, enabled: settings.enabled);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<EngagementState>(engagementProvider, (_, __) => _schedule());
    ref.listen<AppLanguage>(appLanguageProvider, (_, __) => _schedule());
    ref.listen<LearningReminderSettings>(
        learningReminderSettingsProvider, (_, __) => _schedule());
    return widget.child;
  }
}
