import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_client.dart';
import '../core/router.dart';

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

    // Listen to foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification!.title}');
        final context = rootNavigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${message.notification?.title}: ${message.notification?.body}'),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Dismiss',
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    });

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        await ApiClient.registerDeviceToken(token);
        print('Successfully registered device token: $token');
      } catch (e) {
        print('Failed to register device token: $e');
      }
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (newToken.isEmpty) return;
      try {
        await ApiClient.registerDeviceToken(newToken);
        print('Successfully refreshed device token: $newToken');
      } catch (e) {
        print('Failed to refresh device token: $e');
      }
    });
  }
}
