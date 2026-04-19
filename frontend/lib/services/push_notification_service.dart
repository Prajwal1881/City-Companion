import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_client.dart';

class PushNotificationService {
  static bool _bootstrapped = false;

  static Future<void> bootstrap() async {
    if (_bootstrapped || kIsWeb) return;
    await Firebase.initializeApp();
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
