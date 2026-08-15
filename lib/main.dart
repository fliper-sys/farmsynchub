import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/farm_notification_service.dart';
import 'app.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FarmNotificationService.instance.initialize();
  await FarmNotificationService.instance.showNow(
    id: message.messageId?.hashCode.abs() ?? DateTime.now().millisecondsSinceEpoch,
    title: message.notification?.title ?? message.data['title'] as String? ?? 'FarmSync update',
    body: message.notification?.body ?? message.data['body'] as String? ?? '',
    payload: message.data['actionUrl'] as String?,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _configureFirestoreOfflineCache();
    unawaited(_initializeCloudServices());
  } catch (error, stackTrace) {
    debugPrint('[Startup] Firebase core initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const ProviderScope(child: FarmsyncApp()));
}

void _configureFirestoreOfflineCache() {
  try {
    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    } else {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  } catch (error) {
    debugPrint('[Startup] Firestore offline cache setup skipped: $error');
  }
}

Future<void> _initializeCloudServices() async {
  // firebase_app_check has no native Windows/Linux provider - activate()
  // would just throw there every time, so skip the call entirely on those
  // platforms instead of relying on the catch below to hide it. Services
  // that read App Check (see GeminiService._appCheckForPlatform) treat it
  // as unconfigured on desktop for the same reason.
  final bool appCheckSupported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
  if (appCheckSupported) {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    } catch (error) {
      debugPrint('[Startup] App Check initialization skipped: $error');
    }
  }

  try {
    await FarmNotificationService.instance.initialize();
    await FarmNotificationService.instance.requestPermissions();
  } catch (error) {
    debugPrint('[Startup] Notification initialization skipped: $error');
  }
}
