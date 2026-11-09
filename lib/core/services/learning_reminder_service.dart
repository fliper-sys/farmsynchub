import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/app_preferences_provider.dart';
import '../../providers/engagement_provider.dart';
import 'farm_notification_service.dart';

/// User choices for the learning reminders.
class LearningReminderSettings {
  const LearningReminderSettings({
    this.enabled = true,
    this.hour = 18,
    this.minute = 0,
  });

  final bool enabled;
  final int hour;
  final int minute;

  LearningReminderSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      LearningReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  static const String _enabledKey = 'learn_reminders_enabled';
  static const String _hourKey = 'learn_reminders_hour';
  static const String _minuteKey = 'learn_reminders_minute';

  static Future<LearningReminderSettings> load() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      return LearningReminderSettings(
        enabled: p.getBool(_enabledKey) ?? true,
        hour: (p.getInt(_hourKey) ?? 18).clamp(0, 23),
        minute: (p.getInt(_minuteKey) ?? 0).clamp(0, 59),
      );
    } catch (_) {
      return const LearningReminderSettings();
    }
  }

  Future<void> save() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setBool(_enabledKey, enabled);
      await p.setInt(_hourKey, hour);
      await p.setInt(_minuteKey, minute);
    } catch (error) {
      debugPrint('[LearnReminders] Could not save settings: $error');
    }
  }
}

/// Schedules lesson and streak reminders as local notifications.
///
/// Local notifications are handed to the phone's alarm system, so they fire
/// when the phone is offline and the app is closed. Because the text depends
/// on the streak, the next [_daysAhead] days are queued and the queue is
/// rebuilt every time the app opens, a lesson is finished or a setting changes.
class LearningReminderService {
  LearningReminderService._();
  static final LearningReminderService instance = LearningReminderService._();

  static const int _daysAhead = 7;
  // Two ids per day: lesson reminder and streak alert. 9100-9199 is reserved.
  static const int _baseId = 9100;
  static const String _channelId = 'learning_reminders';
  static const String _channelName = 'Lesson and streak reminders';
  static const String _channelDescription =
      'Reminders to start or continue a lesson and to protect your streak';

  Future<void> cancelAll() async {
    for (int i = 0; i < _daysAhead * 2; i++) {
      try {
        await FarmNotificationService.instance.cancel(_baseId + i);
      } catch (_) {}
    }
  }

  Future<void> reschedule({
    required EngagementState engagement,
    required AppLanguage language,
    required LearningReminderSettings settings,
    DateTime? now,
  }) async {
    await cancelAll();
    if (!settings.enabled || !engagement.isLoaded) return;

    final DateTime t = engagement.trusted(now ?? DateTime.now());
    final DateTime today = DateTime(t.year, t.month, t.day);
    final StreakInfo streak = engagement.streakInfo(t);
    final bool doneToday = engagement.isDoneToday(t);
    final bool isNew = engagement.lessonsCompleted == 0;
    final int count = streak.count;
    final bool streakAlive = count > 0 &&
        (streak.status == StreakStatus.doneToday ||
            streak.status == StreakStatus.alive ||
            streak.status == StreakStatus.frozen);

    for (int d = 0; d < _daysAhead; d++) {
      final DateTime day = DateTime(today.year, today.month, today.day + d);

      // 1. The daily lesson reminder at the user's chosen time.
      final bool skipLesson = d == 0 && doneToday;
      if (!skipLesson) {
        final _Text text = _lessonText(language, isNew: isNew, variant: d);
        await _schedule(
          id: _baseId + d * 2,
          at: DateTime(day.year, day.month, day.day, settings.hour,
              settings.minute),
          text: text,
        );
      }

      // 2. A streak alert two and a half hours later, only while a streak is
      // at stake. Today it is skipped once the user has learned. Tomorrow it
      // uses the current count (it only holds if they learn tomorrow). Later
      // days say nothing about the streak because it would already be lost.
      final bool alertToday = d == 0 && !doneToday && streakAlive;
      final bool alertTomorrow = d == 1 && streakAlive;
      if (alertToday || alertTomorrow) {
        int alertMinutes = settings.hour * 60 + settings.minute + 150;
        if (alertMinutes > 21 * 60 + 45) alertMinutes = 21 * 60 + 45;
        await _schedule(
          id: _baseId + d * 2 + 1,
          at: DateTime(day.year, day.month, day.day, alertMinutes ~/ 60,
              alertMinutes % 60),
          text: _streakText(language, count),
        );
      }
    }
  }

  Future<void> _schedule({
    required int id,
    required DateTime at,
    required _Text text,
  }) async {
    try {
      await FarmNotificationService.instance.scheduleOneShot(
        id: id,
        title: text.title,
        body: text.body,
        scheduledAt: at,
        channelId: _channelId,
        channelName: _channelName,
        channelDescription: _channelDescription,
        payload: '/learn',
      );
    } catch (error) {
      debugPrint('[LearnReminders] Could not schedule $id: $error');
    }
  }

  _Text _lessonText(AppLanguage l, {required bool isNew, required int variant}) {
    final bool a = variant.isEven;
    if (isNew) {
      return _Text(
        l.tr(
            en: 'Ready for your first lesson? 🌱',
            ha: 'Ka shirya don darasinka na farko? 🌱',
            fr: 'Prêt pour votre première leçon ? 🌱',
            pcm: 'You ready for your first lesson? 🌱'),
        l.tr(
            en: 'Just a few minutes of farm learning. Open FarmSync Learn to start.',
            ha: 'Mintuna kaɗan na koyon noma. Buɗe FarmSync Learn ka fara.',
            fr: 'Quelques minutes pour apprendre l’agriculture. Ouvrez FarmSync Learn pour commencer.',
            pcm: 'Just small minutes for farm learning. Open FarmSync Learn make you start.'),
      );
    }
    return _Text(
      a
          ? l.tr(
              en: 'Time to learn something new 🌾',
              ha: 'Lokaci ne na koyon wani sabon abu 🌾',
              fr: 'C’est l’heure d’apprendre du nouveau 🌾',
              pcm: 'Time don reach to learn something new 🌾')
          : l.tr(
              en: 'Your next lesson is waiting 📚',
              ha: 'Darasinka na gaba yana jiranka 📚',
              fr: 'Votre prochaine leçon vous attend 📚',
              pcm: 'Your next lesson dey wait you 📚'),
      a
          ? l.tr(
              en: 'Take 5 minutes to continue your farm learning today.',
              ha: 'Ɗauki mintuna 5 ka ci gaba da koyon noma yau.',
              fr: 'Prenez 5 minutes pour continuer à apprendre aujourd’hui.',
              pcm: 'Take 5 minutes continue your farm learning today.')
          : l.tr(
              en: 'Continue where you stopped and earn today’s XP.',
              ha: 'Ci gaba daga inda ka tsaya ka samu XP na yau.',
              fr: 'Reprenez où vous vous êtes arrêté et gagnez vos XP du jour.',
              pcm: 'Continue from where you stop and collect today XP.'),
    );
  }

  _Text _streakText(AppLanguage l, int count) => _Text(
        l.tr(
            en: 'Don’t lose your $count-day streak! 🔥',
            ha: 'Kada ka rasa jerin kwanakinka na $count! 🔥',
            fr: 'Ne perdez pas votre série de $count jours ! 🔥',
            pcm: 'No lose your $count-day streak! 🔥'),
        l.tr(
            en: 'One quick lesson keeps your fire burning. Open the app now.',
            ha: 'Darasi guda ɗaya zai ci gaba da kunna wutarka. Buɗe manhajar yanzu.',
            fr: 'Une courte leçon garde votre flamme allumée. Ouvrez l’app maintenant.',
            pcm: 'One quick lesson go keep your fire burning. Open the app now.'),
      );
}

class _Text {
  const _Text(this.title, this.body);
  final String title;
  final String body;
}
