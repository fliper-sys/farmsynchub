import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/services/farm_notification_service.dart';
import '../data/remote/firebase_service.dart';
import '../domain/models/notification.dart';
import 'auth_provider.dart';

/// Provider for managing notifications.
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<Notification>>((ref) {
  return NotificationsNotifier(
    ref.read(firebaseServiceProvider),
    ref.watch(authStateProvider).valueOrNull?.uid,
  );
});

/// State notifier for notifications management.
class NotificationsNotifier extends StateNotifier<List<Notification>> {
  NotificationsNotifier(this._firebaseService, this._currentUserId)
      : super([]) {
    _initialLoad = _loadNotifications();
  }

  final FirebaseService _firebaseService;
  final String? _currentUserId;
  late final Future<void> _initialLoad;
  static const String _notificationsKey = 'notifications';
  static const String _remoteCollection = 'app_notifications';
  final _uuid = const Uuid();

  String get _storageKey {
    final String? userId = _currentUserId ?? _firebaseService.currentUser?.uid;
    return userId == null || userId.isEmpty
        ? _notificationsKey
        : '${_notificationsKey}_$userId';
  }

  /// Loads notifications from shared preferences.
  Future<void> _loadNotifications() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    final List<String> notificationsJson =
        prefs.getStringList(_storageKey) ?? <String>[];
    final List<Notification> localNotifications = notificationsJson
        .map((String jsonStr) =>
            Notification.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>))
        .toList();
    final List<Notification> remoteNotifications =
        await _loadRemoteNotifications();
    final Map<String, bool> remoteReadStates =
        await _loadRemoteNotificationReadStates();
    if (!mounted) {
      return;
    }
    final Map<String, Notification> merged = <String, Notification>{};

    for (final Notification localNotification in localNotifications) {
      merged[localNotification.id] = localNotification;
    }

    for (final Notification remoteNotification in remoteNotifications) {
      final Notification? existing = merged[remoteNotification.id];
      if (existing != null) {
        merged[remoteNotification.id] = remoteNotification.copyWith(
          isRead: remoteReadStates[remoteNotification.id] ?? existing.isRead,
        );
      } else {
        merged[remoteNotification.id] = remoteNotification.copyWith(
          isRead: remoteReadStates[remoteNotification.id] ??
              remoteNotification.isRead,
        );
      }
    }

    for (final MapEntry<String, bool> readState in remoteReadStates.entries) {
      final Notification? existing = merged[readState.key];
      if (existing != null) {
        merged[readState.key] = existing.copyWith(isRead: readState.value);
      }
    }

    state = merged.values.toList()
      ..sort((Notification a, Notification b) =>
          b.timestamp.compareTo(a.timestamp));

    if (notificationsJson.isEmpty &&
        remoteNotifications.isEmpty &&
        state.isNotEmpty) {
      await _saveNotifications();
    }
  }

  Future<void> refresh() async {
    await _initialLoad;
    await _loadNotifications();
  }

  Future<List<Notification>> _loadRemoteNotifications() async {
    try {
      final List<Map<String, dynamic>> records =
          await _firebaseService.getGlobalFromFirestore(_remoteCollection);
      return records
          .map(Notification.fromMap)
          .where((Notification notification) =>
              _shouldShowRemoteNotification(notification))
          .toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('[Notifications] Remote notifications unavailable: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <Notification>[];
    }
  }

  Future<Map<String, bool>> _loadRemoteNotificationReadStates() async {
    final String? userId = _currentUserId ?? _firebaseService.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      return <String, bool>{};
    }

    try {
      return await _firebaseService.getNotificationReadStates(userId);
    } catch (error, stackTrace) {
      debugPrint('[Notifications] Remote read states unavailable: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <String, bool>{};
    }
  }

  bool _shouldShowRemoteNotification(Notification notification) {
    final Map<String, dynamic>? metadata = notification.metadata;
    if (metadata == null) {
      return true;
    }
    final String audience = metadata['audience'] as String? ?? 'all';
    if (audience == 'all') {
      return true;
    }
    final String? targetUserId = metadata['targetUserId'] as String?;
    final String? currentUserId =
        _currentUserId ?? _firebaseService.currentUser?.uid;
    return targetUserId != null && targetUserId == currentUserId;
  }

  /// Saves notifications to shared preferences.
  Future<void> _saveNotifications() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> payload = state
        .map((Notification notification) => jsonEncode(notification.toMap()))
        .toList(growable: false);
    await prefs.setStringList(_storageKey, payload);
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

  Future<void> publishNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
    String? actionUrl,
    String audience = 'all',
    String? targetUserId,
    Map<String, dynamic>? metadata,
    bool showDeviceNotification = true,
  }) async {
    final notification = Notification(
      id: _uuid.v4(),
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      actionUrl: actionUrl,
      metadata: <String, dynamic>{
        'audience': audience,
        if (targetUserId != null) 'targetUserId': targetUserId,
        if (metadata != null) ...metadata,
      },
    );

    await _firebaseService.syncGlobalToFirestore(
        _remoteCollection, notification.toMap());
    if (!mounted) {
      return;
    }

    if (_shouldShowRemoteNotification(notification)) {
      state = <Notification>[notification, ...state]..sort(
          (Notification a, Notification b) =>
              b.timestamp.compareTo(a.timestamp));
      await _saveNotifications();
      if (showDeviceNotification) {
        await FarmNotificationService.instance.showNow(
          id: notification.id.hashCode.abs(),
          title: title,
          body: message,
          payload: actionUrl,
        );
      }
    }
  }

  /// Marks a notification as read.
  Future<void> markAsRead(String notificationId) =>
      _setReadState(notificationId, true);

  /// Marks a notification as unread.
  Future<void> markAsUnread(String notificationId) =>
      _setReadState(notificationId, false);

  /// Toggles a notification read state.
  Future<void> toggleRead(String notificationId) async {
    final Notification? notification = _notificationById(notificationId);
    if (notification != null) {
      await _setReadState(notificationId, !notification.isRead);
    }
  }

  Future<void> _setReadState(String notificationId, bool isRead) async {
    final Notification? notification = _notificationById(notificationId);
    if (notification == null || notification.isRead == isRead) {
      return;
    }

    state = state
        .map((Notification item) =>
            item.id == notificationId ? item.copyWith(isRead: isRead) : item)
        .toList(growable: false);
    await _persistReadStates(<String, bool>{notificationId: isRead});
  }

  Notification? _notificationById(String notificationId) {
    for (final Notification notification in state) {
      if (notification.id == notificationId) {
        return notification;
      }
    }
    return null;
  }

  /// Marks all notifications as read.
  Future<void> markAllAsRead() async {
    final List<Notification> unreadNotifications = state
        .where((Notification notification) => !notification.isRead)
        .toList(growable: false);
    if (unreadNotifications.isEmpty) {
      return;
    }

    state = state
        .map((Notification notification) => notification.copyWith(isRead: true))
        .toList(growable: false);
    await _persistReadStates(<String, bool>{
      for (final Notification notification in unreadNotifications)
        notification.id: true,
    });
  }

  Future<void> _persistReadStates(Map<String, bool> readStates) async {
    await _saveNotifications();

    final String? userId = _currentUserId ?? _firebaseService.currentUser?.uid;
    if (userId == null || userId.isEmpty || readStates.isEmpty) {
      return;
    }

    try {
      await _firebaseService.saveNotificationReadStates(userId, readStates);
    } catch (error, stackTrace) {
      debugPrint('[Notifications] Remote read-state save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Removes a notification.
  void removeNotification(String notificationId) {
    state = state
        .where((notification) => notification.id != notificationId)
        .toList();
    _saveNotifications();
  }

  /// Restores an existing notification object, preserving its id and timestamp.
  void restoreNotification(Notification notification) {
    if (state.any((item) => item.id == notification.id)) {
      return;
    }
    state = <Notification>[notification, ...state]..sort(
        (Notification a, Notification b) => b.timestamp.compareTo(a.timestamp));
    _saveNotifications();
  }

  /// Clears all notifications.
  void clearAllNotifications() {
    state = [];
    _saveNotifications();
  }

  /// Gets unread notifications count.
  int get unreadCount =>
      state.where((notification) => !notification.isRead).length;

  /// Gets read notifications count.
  int get readCount =>
      state.where((notification) => notification.isRead).length;
}
