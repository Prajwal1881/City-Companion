import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_client.dart';

// MUST be a top-level function (not inside a class) for background handling to work
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // FCM auto-displays the system notification when the app is in background/killed
  // as long as the backend sends a 'notification' block in the FCM payload
}

class PushNotificationService {
  static bool _bootstrapped = false;

  static Future<void> bootstrap() async {
    if (_bootstrapped || kIsWeb) return;
    await Firebase.initializeApp();

    // Register background message handler so system notifications appear
    // when app is backgrounded or killed
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    _bootstrapped = true;
  }

  static Future<void> registerForCurrentUser() async {
    if (kIsWeb) return;
    await bootstrap();

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        await ApiClient.registerDeviceToken(token);
      } catch (_) {}
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (newToken.isEmpty) return;
      try {
        await ApiClient.registerDeviceToken(newToken);
      } catch (_) {}
    });
  }
}
