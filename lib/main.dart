import 'package:firebase_app_check/firebase_app_check.dart';
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
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  }
  await FarmNotificationService.instance.initialize();
  await FarmNotificationService.instance.requestPermissions();

  runApp(const ProviderScope(child: FarmsyncApp()));
}
