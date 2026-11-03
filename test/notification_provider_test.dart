import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farmsynchub/data/remote/firebase_service.dart';
import 'package:farmsynchub/domain/models/notification.dart';
import 'package:farmsynchub/providers/notification_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('keeps the locally saved read state when remote notifications reload',
      () async {
    const String userId = 'test-user';
    final Notification storedNotification = Notification(
      id: 'notification-1',
      title: 'Watering reminder',
      message: 'Water the tomatoes before noon.',
      type: NotificationType.info,
      timestamp: DateTime.parse('2024-01-01T10:00:00.000Z'),
      isRead: true,
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'notifications_$userId',
      <String>[jsonEncode(storedNotification.toMap())],
    );

    final FakeFirebaseService fakeFirebaseService = FakeFirebaseService(
      <String, List<Map<String, dynamic>>>{
        'app_notifications': <Map<String, dynamic>>[
          storedNotification.copyWith(isRead: false).toMap(),
        ],
      },
    );

    final NotificationsNotifier notifier =
        NotificationsNotifier(fakeFirebaseService, userId);
    await notifier.refresh();

    expect(notifier.state, hasLength(1));
    expect(notifier.state.single.id, storedNotification.id);
    expect(notifier.state.single.isRead, isTrue);
  });

  test('loads and persists per-user read state with Firebase', () async {
    const String userId = 'test-user';
    final Notification notification = Notification(
      id: 'notification-2',
      title: 'Feed reminder',
      message: 'Check the feed store.',
      type: NotificationType.info,
      timestamp: DateTime.parse('2024-01-02T10:00:00.000Z'),
    );
    final FakeFirebaseService fakeFirebaseService = FakeFirebaseService(
      <String, List<Map<String, dynamic>>>{
        'app_notifications': <Map<String, dynamic>>[notification.toMap()],
      },
    )..readStates[notification.id] = true;

    final NotificationsNotifier notifier =
        NotificationsNotifier(fakeFirebaseService, userId);
    await notifier.refresh();

    expect(notifier.state.single.isRead, isTrue);

    await notifier.markAsUnread(notification.id);
    expect(
        fakeFirebaseService.savedReadStates[userId]![notification.id], isFalse);
    expect(notifier.state.single.isRead, isFalse);

    await notifier.markAsRead(notification.id);
    expect(
        fakeFirebaseService.savedReadStates[userId]![notification.id], isTrue);
    expect(notifier.state.single.isRead, isTrue);
  });

  test('persists read-all changes with Firebase', () async {
    const String userId = 'test-user';
    final Notification first = Notification(
      id: 'notification-3',
      title: 'First reminder',
      message: 'First message.',
      type: NotificationType.info,
      timestamp: DateTime.parse('2024-01-03T10:00:00.000Z'),
    );
    final Notification second = Notification(
      id: 'notification-4',
      title: 'Second reminder',
      message: 'Second message.',
      type: NotificationType.info,
      timestamp: DateTime.parse('2024-01-04T10:00:00.000Z'),
    );
    final FakeFirebaseService fakeFirebaseService = FakeFirebaseService(
      <String, List<Map<String, dynamic>>>{
        'app_notifications': <Map<String, dynamic>>[
          first.toMap(),
          second.toMap(),
        ],
      },
    );
    final NotificationsNotifier notifier =
        NotificationsNotifier(fakeFirebaseService, userId);
    await notifier.refresh();

    await notifier.markAllAsRead();

    expect(fakeFirebaseService.savedReadStates[userId], <String, bool>{
      first.id: true,
      second.id: true,
    });
    expect(notifier.state.every((Notification item) => item.isRead), isTrue);
  });
}

class FakeFirebaseService extends FirebaseService {
  FakeFirebaseService(this._records);

  final Map<String, List<Map<String, dynamic>>> _records;
  final Map<String, bool> readStates = <String, bool>{};
  final Map<String, Map<String, bool>> savedReadStates =
      <String, Map<String, bool>>{};

  @override
  Future<List<Map<String, dynamic>>> getGlobalFromFirestore(
      String collection) async {
    return _records[collection] ?? <Map<String, dynamic>>[];
  }

  @override
  Future<Map<String, bool>> getNotificationReadStates(String userId) async {
    return readStates;
  }

  @override
  Future<void> saveNotificationReadStates(
    String userId,
    Map<String, bool> readStates,
  ) async {
    savedReadStates
        .putIfAbsent(userId, () => <String, bool>{})
        .addAll(readStates);
    this.readStates.addAll(readStates);
  }
}
