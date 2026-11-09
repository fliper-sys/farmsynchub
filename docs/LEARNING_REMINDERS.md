# Lesson and streak reminders

## Offline reminders (local notifications)

`LearningReminderService` queues local notifications with the phone's alarm
system, so they fire **with no internet and with the app closed**.

- Daily lesson reminder at the learner's chosen time (default 18:00). Says
  "start your first lesson" for new learners and "continue" afterwards.
- Streak alert 2.5 hours later (capped 21:45) while a streak is at stake.
  Skipped once the learner has finished a lesson that day.
- The next 7 days are queued. The queue is rebuilt (`LearningReminderBinder`)
  when the app opens or resumes, after a lesson, and when the language or the
  settings change. If the learner never opens the app for 7 days, reminders stop.
- Ids 9100-9199 are reserved. Channel: `learning_reminders`.
- Android: inexact alarms (no special permission; may be a few minutes late).
  `ScheduledNotificationBootReceiver` in the manifest restores them after a reboot.
  Some phones (Tecno/Infinix/Xiaomi) kill background apps; tell users to allow
  "auto-start" / disable battery optimisation for FarmSync Hub.
- Learners control it from Learn > Streak > bell icon.

## Online push (Firebase Cloud Messaging)

Push needs a connection and a sender. Each device subscribes to the topic
`learn_reminders_<language>` (english, hausa, french, pidgin) when reminders are on.
Send from the Firebase console (Messaging > New campaign > topic) or a scheduled
Cloud Function, for example a daily 17:30 message:

```js
exports.dailyLearnPush = onSchedule("every day 17:30", async () => {
  await getMessaging().send({
    topic: "learn_reminders_english",
    notification: { title: "Time to learn 🌾", body: "Continue your lesson today." },
  });
});
```

Repeat per language with translated text. Push cannot know each learner's
streak; the personalised nudges are the local ones.
