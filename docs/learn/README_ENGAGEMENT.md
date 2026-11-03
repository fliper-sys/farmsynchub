# FarmSync learn enhancements: streak, XP, calendar, shareable achievements

## 1. Where the files go

| File | Put it in |
|---|---|
| `lib/providers/engagement_provider.dart` | `lib/providers/` (next to `learning_provider.dart`) |
| `lib/ui/learning/*.dart` (4 files) | the same folder as `lesson_certificate_screen.dart` |

The UI files use the same relative imports as your certificate screen (`../../../providers/...`, `../../../core/services/...`). If the folder depth differs, adjust those paths.

## 2. pubspec.yaml

```yaml
dependencies:
  lottie: ^3.1.2   # use the latest 3.x

flutter:
  assets:
    - assets/lottie/
```

## 3. Lottie files (free)

I could not download files from here, so the animation files are not included. The app will not crash without them: every spot falls back to an icon until the files exist.

Download these 3 from LottieFiles (choose "Lottie JSON") and save them with exactly these names in `assets/lottie/`:

| Save as | Browse and pick one |
|---|---|
| `trophy.json` | https://lottiefiles.com/free-animations/trophy |
| `confetti.json` | https://lottiefiles.com/free-animations/confetti (transparent background works best) |
| `streak_fire.json` | https://lottiefiles.com/free-animations/fire-streak |

Licence: LottieFiles free animations use the Lottie Simple License. Commercial use in apps and edits are allowed and attribution is not required (but is encouraged). You may not redistribute the files as standalone animation files, so keep them bundled in the app only. Check the licence on each animation's page before you pick it.

To use a different animation for a specific achievement, set the `lottie:` field on that entry in `Achievements.all`.

## 4. Wire it into your lesson flow

At the end of a lesson, replace your current "lesson finished" navigation with:

```dart
Navigator.of(context).pushReplacement(fluidRoute(LessonCompleteScreen(
  lessonId: lesson.id,
  lessonTitle: lesson.title,
  correctAnswers: correct,
  totalQuestions: total,
  nextLessonTitle: next?.title,
  onNextLesson: next == null
      ? null
      : () => Navigator.of(context)
          .pushReplacement(fluidRoute(LessonScreen(lesson: next))),
)));
```

`LessonCompleteScreen` calls `learningProvider.completeLesson` itself, so remove that call from your lesson screen to avoid doing it twice.

Add the streak and XP chip to the learn hub app bar:

```dart
AppBar(actions: const [StreakChip()])
```

Tapping it opens the calendar. For a Duolingo-style week row on the hub, drop in `const WeekStrip()`.

Optional: reward other actions with small XP, which also keeps the streak alive:

```dart
final unlocked = await ref.read(engagementProvider.notifier).awardXp(5);
if (unlocked.isNotEmpty && context.mounted) {
  showAchievementCelebrations(context, unlocked);
}
```

## 5. How points and streaks work

- First time finishing a lesson: 10 XP + 2 per correct answer + 5 if every answer is correct. Replaying a lesson pays 5 XP so it can't be farmed.
- A day counts toward the streak once any XP is earned that day (local time).
- If today is not done yet, yesterday's streak is still alive until midnight.
- Achievements pay bonus XP. Bonus XP can unlock further achievements (for example 100 XP).
- Calendar days: orange = passed (shows XP), red = missed (only after the learner's first active day), outlined = today, gold trophy = award earned that day. Tap a day for XP, lessons and awards.

## 6. Streak freezes and restorations (v2)

- Miss one day: the fire turns ice-blue and the streak number is kept ("frozen"). Finishing any lesson that day restores it. This uses 1 of 3 restorations.
- After 3 restorations are used, the next missed day resets the streak to the beginning, and all 3 restorations refill.
- Missing 2 or more days in a row always resets the streak, unless owned freezes cover every missed day.
- Streak freeze (optional item): bought with gems (30 gems, max 2 owned). It auto-protects a missed day and does not use a restoration. Gems come from finishing lessons (5, +5 if perfect, 1 on a replay) and achievements (10 each).
- Calendar: frozen days show an ice-blue snowflake. The streak banner and a freeze shop sheet are in `streak_freeze_sheet.dart`.
- Existing saved data keeps working: the new fields default to zero.
- To change the rules, edit `maxRestorations`, `maxFreezes` and `freezeCostGems` at the top of `EngagementState`.

## 7. Notes

- The Hausa strings are my best attempt. Please have a native speaker review them.
- Weekly leaderboards and a daily XP goal are the next Duolingo features you could add. They are not included yet.
- I could not compile this in my environment (no Flutter SDK), so run `flutter pub get` and `flutter analyze` and send me any errors.
