import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/api_client.dart';
import 'services/push_notification_service.dart';
import 'core/router.dart';
import 'core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.init();
  await PushNotificationService.bootstrap();
  runApp(const ProviderScope(child: CityCompanionApp()));
}

class CityCompanionApp extends ConsumerWidget {
  const CityCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'City Companion',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
