import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/notification.dart';

/// Provider for managing notifications.
final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<Notification>>((ref) {
  return NotificationsNotifier();
});

/// State notifier for notifications management.
class NotificationsNotifier extends StateNotifier<List<Notification>> {
  NotificationsNotifier() : super([]) {
    _loadNotifications();
  }

  static const String _notificationsKey = 'notifications';
  final _uuid = const Uuid();

  /// Loads notifications from shared preferences.
  Future<void> _loadNotifications() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> notificationsJson = prefs.getStringList(_notificationsKey) ?? <String>[];
    if (notificationsJson.isEmpty) {
      state = _defaultNotifications();
      await _saveNotifications();
      return;
    }

    state = notificationsJson
        .map((String jsonStr) => Notification.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>))
        .toList()
      ..sort((Notification a, Notification b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Saves notifications to shared preferences.
  Future<void> _saveNotifications() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> payload = state
        .map((Notification notification) => jsonEncode(notification.toMap()))
        .toList(growable: false);
    await prefs.setStringList(_notificationsKey, payload);
  }

  /// Adds a new notification.
  void addNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
    String? actionUrl,
    Map<String, dynamic>? metadata,
  }) {
    final notification = Notification(
      id: _uuid.v4(),
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      actionUrl: actionUrl,
      metadata: metadata,
    );

    state = [notification, ...state];
    _saveNotifications();
  }

  /// Marks a notification as read.
  void markAsRead(String notificationId) {
    state = state.map((notification) {
      if (notification.id == notificationId) {
        return notification.copyWith(isRead: true);
      }
      return notification;
    }).toList();
    _saveNotifications();
  }

  /// Marks a notification as unread.
  void markAsUnread(String notificationId) {
    state = state.map((notification) {
      if (notification.id == notificationId) {
        return notification.copyWith(isRead: false);
      }
      return notification;
    }).toList();
    _saveNotifications();
  }

  /// Toggles a notification read state.
  void toggleRead(String notificationId) {
    state = state.map((notification) {
      if (notification.id == notificationId) {
        return notification.copyWith(isRead: !notification.isRead);
      }
      return notification;
    }).toList();
    _saveNotifications();
  }

  /// Marks all notifications as read.
  void markAllAsRead() {
    state = state.map((notification) => notification.copyWith(isRead: true)).toList();
    _saveNotifications();
  }

  /// Removes a notification.
  void removeNotification(String notificationId) {
    state = state.where((notification) => notification.id != notificationId).toList();
    _saveNotifications();
  }

  /// Restores an existing notification object, preserving its id and timestamp.
  void restoreNotification(Notification notification) {
    if (state.any((item) => item.id == notification.id)) {
      return;
    }
    state = <Notification>[notification, ...state]
      ..sort((Notification a, Notification b) => b.timestamp.compareTo(a.timestamp));
    _saveNotifications();
  }

  /// Clears all notifications.
  void clearAllNotifications() {
    state = [];
    _saveNotifications();
  }

  /// Gets unread notifications count.
  int get unreadCount => state.where((notification) => !notification.isRead).length;

  /// Gets read notifications count.
  int get readCount => state.where((notification) => notification.isRead).length;

  /// Mock notifications for demonstration.
  List<Notification> _defaultNotifications() {
    return [
      Notification(
        id: '1',
        title: 'Welcome to FarmSync!',
        message: 'Thank you for joining our farming community. Explore the app to manage your farm efficiently.',
        type: NotificationType.success,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        isRead: false,
        actionUrl: '/dashboard',
      ),
      Notification(
        id: '2',
        title: 'Crop Health Alert',
        message: 'Your maize crop in Field A shows signs of nutrient deficiency. Consider applying fertilizer.',
        type: NotificationType.warning,
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        isRead: false,
        actionUrl: '/crops',
      ),
      Notification(
        id: '3',
        title: 'Livestock Vaccination Due',
        message: 'Vaccination for your cattle is due tomorrow. Don\'t forget to schedule it.',
        type: NotificationType.info,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
      ),
      Notification(
        id: '4',
        title: 'Weather Update',
        message: 'Heavy rainfall expected in your area. Take necessary precautions for your crops.',
        type: NotificationType.warning,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isRead: false,
        actionUrl: '/farms',
        metadata: <String, dynamic>{
          'recommendedAction': 'Check drainage and raised beds',
          'precipitation': '18 mm forecast',
        },
      ),
      Notification(
        id: '5',
        title: 'Monthly Report Ready',
        message: 'Your farm performance report for this month is now available.',
        type: NotificationType.success,
        timestamp: DateTime.now().subtract(const Duration(days: 7)),
        isRead: true,
        actionUrl: '/finance',
      ),
    ];
  }
}
