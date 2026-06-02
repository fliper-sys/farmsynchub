import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class FarmNotificationService {
  FarmNotificationService._();

  static final FarmNotificationService instance = FarmNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      tzdata.initializeTimeZones();

        // FlutterTimezone.getLocalTimezone() returns a String with the timezone name.
        final dynamic timeZoneInfo = await FlutterTimezone.getLocalTimezone();
        final String timeZoneName = (timeZoneInfo is String) ? timeZoneInfo : (timeZoneInfo?.toString() ?? 'UTC');
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (error) {
      debugPrint('[Notifications] Falling back to UTC timezone: $error');
      tz.setLocalLocation(tz.UTC);
    }

    try {
      const AndroidInitializationSettings androidInitializationSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings darwinInitializationSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _plugin.initialize(
        const InitializationSettings(
          android: androidInitializationSettings,
          iOS: darwinInitializationSettings,
          macOS: darwinInitializationSettings,
        ),
      );
      _isInitialized = true;
    } catch (error) {
      debugPrint('[Notifications] Plugin initialization failed: $error');
      _isInitialized = false;
    }
  }

  Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final AndroidFlutterLocalNotificationsPlugin? android =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final bool? androidGranted = await android?.requestNotificationsPermission();
      final IOSFlutterLocalNotificationsPlugin? ios =
          _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final bool? iosGranted = await ios?.requestPermissions(alert: true, badge: true, sound: true);
      final MacOSFlutterLocalNotificationsPlugin? mac =
          _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      final bool? macGranted = await mac?.requestPermissions(alert: true, badge: true, sound: true);
      return (androidGranted ?? true) && (iosGranted ?? true) && (macGranted ?? true);
    } catch (error) {
      debugPrint('[Notifications] Permission request failed: $error');
      return false;
    }
  }

  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    if (!_isInitialized) {
      return;
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'crop_reminders',
          'Crop reminders',
          channelDescription: 'Crop reminders and farm work notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // The `uiLocalNotificationDateInterpretation` parameter was removed
      // in newer versions of flutter_local_notifications. Defaults are used.
      payload: payload,
    );
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'farm_updates',
    String channelName = 'Farm updates',
    String channelDescription = 'News, finance, farm schedule, and admin update notifications',
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    if (!_isInitialized) {
      return;
    }

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  Future<void> cancel(int id) async {
    if (!_isInitialized) {
      return;
    }
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (!_isInitialized) {
      return;
    }
    await _plugin.cancelAll();
  }
}
