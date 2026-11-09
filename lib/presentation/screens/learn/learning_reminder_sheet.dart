import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/context_tr.dart';
import '../../../core/services/farm_notification_service.dart';
import '../../../core/services/learning_reminder_service.dart';
import '../../../providers/learning_reminder_provider.dart';

/// Bottom sheet where learners switch lesson and streak reminders on or off
/// and choose the time of day.
Future<void> showLearningReminderSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _LearningReminderSheet(),
  );
}

class _LearningReminderSheet extends ConsumerWidget {
  const _LearningReminderSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final LearningReminderSettings s =
        ref.watch(learningReminderSettingsProvider);
    final LearningReminderSettingsNotifier notifier =
        ref.read(learningReminderSettingsProvider.notifier);
    final String time = TimeOfDay(hour: s.hour, minute: s.minute).format(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              ctr(context, 'Lesson & streak reminders', 'Tunatarwar darasi da jerin kwanaki',
                  'Rappels de leçons et de série', 'Lesson & streak reminders'),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              ctr(
                  context,
                  'A daily nudge to start or continue a lesson, and an alert when your streak is at risk. They work with no internet, even when the app is closed.',
                  'Tunatarwa ta kullum don fara ko ci gaba da darasi, da gargadi idan jerin kwanakinka na cikin hatsari. Suna aiki ba tare da intanet ba, ko da manhajar a rufe take.',
                  'Un rappel quotidien pour commencer ou continuer une leçon, et une alerte quand votre série est en danger. Ils fonctionnent sans internet, même app fermée.',
                  'Daily reminder to start or continue lesson, and alert when your streak dey danger. E dey work without internet, even if the app close.'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(ctr(context, 'Remind me to learn', 'Tunatar da ni in koyi',
                  'Me rappeler d’apprendre', 'Remind me make I learn')),
              value: s.enabled,
              onChanged: (bool v) async {
                if (v) {
                  await FarmNotificationService.instance.requestPermissions();
                }
                await notifier.setEnabled(v);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: s.enabled,
              leading: const Icon(Icons.schedule_rounded),
              title: Text(ctr(context, 'Reminder time', 'Lokacin tunatarwa',
                  'Heure du rappel', 'Reminder time')),
              subtitle: Text(time),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: !s.enabled
                  ? null
                  : () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: s.hour, minute: s.minute),
                      );
                      if (picked != null) {
                        await notifier.setTime(picked.hour, picked.minute);
                      }
                    },
            ),
            if (s.enabled)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    await FarmNotificationService.instance.requestPermissions();
                    await FarmNotificationService.instance.showNow(
                      id: 9199,
                      title: ctr(context, 'Reminders are on 🔔', 'Tunatarwa tana aiki 🔔',
                          'Les rappels sont activés 🔔', 'Reminders don start 🔔'),
                      body: ctr(context, 'This is how your lesson reminders will look.',
                          'Haka tunatarwar darasinka za ta bayyana.',
                          'Voici à quoi ressembleront vos rappels de leçon.',
                          'Na so your lesson reminders go look.'),
                      channelId: 'learning_reminders',
                      channelName: 'Lesson and streak reminders',
                      channelDescription:
                          'Reminders to start or continue a lesson and to protect your streak',
                    );
                  },
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(ctr(context, 'Send a test now', 'Aika gwaji yanzu',
                      'Envoyer un test', 'Send test now')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
