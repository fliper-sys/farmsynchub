import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/firebase_service.dart';
import '../../providers/auth_provider.dart';

final firebaseMessagingServiceProvider = Provider<FirebaseMessagingService>((ref) {
  return FirebaseMessagingService(ref.watch(firebaseServiceProvider));
});

class FirebaseMessagingService {
  FirebaseMessagingService(this._firebaseService);

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseService _firebaseService;
  StreamSubscription<User?>? _authStateSubscription;

  Future<void> initialize() async {
    await _requestPermissions();

    await _saveTokenIfAvailable();
    _messaging.onTokenRefresh.listen((String token) async {
      try {
        await _firebaseService.saveDeviceToken(token);
      } catch (error) {
        debugPrint('[Messaging] Token refresh save skipped: $error');
      }
    });

    _authStateSubscription = _firebaseService.authStateChanges.listen((User? user) async {
      if (user != null) {
        await _saveTokenIfAvailable();
      }
    });
  }

  Future<void> _saveTokenIfAvailable() async {
    try {
      final String? token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _firebaseService.saveDeviceToken(token);
      }
    } catch (error) {
      debugPrint('[Messaging] Device token unavailable: $error');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
    } catch (error) {
      debugPrint('[Messaging] Permission request skipped: $error');
    }
  }

  void dispose() {
    _authStateSubscription?.cancel();
  }
}
