# FarmSync Firebase Offline Learning + Streak Sync Patch

## What this patch does

- Keeps existing learning state on the device using the current SharedPreferences storage.
- Stores local progress under the authenticated user ID and adds a durable per-user outbox (`farmsync.sync.outbox.<uid>`).
- Writes immutable activity events to `users/{uid}/learningEvents/{eventId}` in Cloud Firestore.
- Retries queued writes on connectivity restoration, app resume, app startup, and Firebase Auth user changes.
- Uses stable event document IDs so retrying an interrupted upload cannot create duplicate event documents.
- Pulls the user's cloud event history and merges it into the local provider using sets.
- Tracks local calendar activity dates for completed lessons, completed practices, and answered questions. Offline dates are uploaded as the original activity date, not the later sync date.
- Exposes `state.currentStreak` and `state.longestStreak` for streak UI.

## Files

Place `firebase_learning_sync.dart` in the same directory as `learning_provider.dart`.
Replace the existing `learning_provider.dart` with `FarmSync_learning_provider_migrated.dart` from this patch (rename it to `learning_provider.dart`).
Keep the existing enriched `learn_screen.dart`; this patch does not add lessons or replace the lesson bank.
Deploy `firestore.rules` to the Firebase project.

## Dependencies

The project already has Firebase Authentication according to the project owner. Ensure Firebase Core initialization is already completed before `ProviderScope` / the learning provider is used. Add these dependencies to `pubspec.yaml` if missing:

```yaml
dependencies:
  firebase_core: ^3.8.0
  firebase_auth: ^5.3.3
  cloud_firestore: ^5.5.0
  connectivity_plus: ^6.1.0
  flutter_riverpod: any # keep the version already used by the app
  shared_preferences: any # keep the version already used by the app
```

Do not downgrade existing Firebase packages. If the project already uses newer compatible versions, keep those versions.

Then run:

```bash
flutter pub get
```

## Firebase setup

1. Open Firebase Console -> Firestore Database.
2. Create the Firestore database if it does not exist.
3. Open Firestore Rules, replace/deploy with the contents of `firestore.rules`.
4. Keep Firebase Authentication enabled with the sign-in methods already used by FarmSync.
5. Verify that Firebase is initialized once at app startup (usually `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`). Do not initialize Firebase a second time in the provider.

The rules allow a signed-in learner to read and create only their own event documents. Events cannot be edited or deleted; an exact-content retry is allowed so an interrupted client acknowledgement can safely retry.

## Streak rules

A day counts when the learner completes a lesson, completes a practical activity, or answers a quiz question. Skipping a lesson/question and sharing an item do not count. The activity date is captured on the device at the time of the learning action and remains unchanged when it syncs later. Current streak remains active if the learner has activity today or yesterday; longest streak is calculated from all recorded activity dates.

If the product's intended streak definition is different (for example, a minimum of 5 minutes or 3 questions per day), change `_recordActivityDay` call sites accordingly.

## Showing streak and sync state

The provider now exposes:

```dart
final learning = ref.watch(learningProvider);
Text('Current streak: ${learning.currentStreak} days');
Text('Best streak: ${learning.longestStreak} days');
```

The sync service can be manually triggered from a retry button:

```dart
await FirebaseLearningSync.instance.syncNow();
```

For a status label, you can read `FirebaseLearningSync.instance.isSyncing` and `lastError`. These are simple service properties, not a reactive Riverpod provider; wire them into a `StateProvider`/`StreamProvider` if the UI needs live status updates.

## Important limitations / next hardening steps

- This patch synchronizes learning events and rebuilds the existing progress sets. It does not synchronize media files. YouTube/video playback still requires internet unless videos are separately downloaded and licensed for offline use.
- The existing lesson content is bundled in Dart, so text, quizzes and practices can load offline. Any remote images, attachments or external links need their own cache/download handling.
- On first upgrade, legacy unscoped progress is migrated to the account currently signed in on that device. Thereafter progress and outbox data are stored per UID, and the provider reloads when the signed-in account changes. If the old installation was shared by multiple people before this upgrade, confirm which account owns the old local progress before running the migration.
- The provider currently stores the progress snapshot in SharedPreferences. For very long activity histories or larger offline media, migrate the local store/outbox to SQLite/Drift/Isar.
- Firestore event history is fetched as a full collection during reconciliation. For very large cohorts/long-lived accounts, add a server-maintained aggregate plus a paginated event cursor.
- Run `flutter analyze` and test with airplane mode, app force-close, reconnect, app restart, and a second signed-in device before production release.

## Suggested acceptance test

1. Sign in while online and open the learning screen once.
2. Enable airplane mode.
3. Complete a lesson, answer a question and complete a practice on three different calendar days (change device date only in a test environment).
4. Force-close and reopen the app while offline. Verify local progress and streak dates remain.
5. Restore internet and reopen the app. Verify events appear under `users/{uid}/learningEvents`.
6. Sign in on a second test device. Verify the provider rebuilds the same completed lessons, practices, question progress, certificates and activity dates.
7. Repeat the reconnect several times. Verify event document count and earned progress do not increase from retries.
