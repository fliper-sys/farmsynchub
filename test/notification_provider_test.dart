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

  test('keeps the locally saved read state when remote notifications reload', () async {
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

    final NotificationsNotifier notifier = NotificationsNotifier(fakeFirebaseService, userId);
    await notifier.refresh();

    expect(notifier.state, hasLength(1));
    expect(notifier.state.single.id, storedNotification.id);
    expect(notifier.state.single.isRead, isTrue);
  });
}

class FakeFirebaseService extends FirebaseService {
  FakeFirebaseService(this._records);

  final Map<String, List<Map<String, dynamic>>> _records;

  @override
  Future<List<Map<String, dynamic>>> getGlobalFromFirestore(String collection) async {
    return _records[collection] ?? <Map<String, dynamic>>[];
  }
}
