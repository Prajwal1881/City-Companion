import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
import '../../core/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Add a small delay for the splash screen
    await Future.delayed(const Duration(milliseconds: 500));
    final loggedIn = await ApiClient.isLoggedIn();
    if (mounted) {
      if (loggedIn) {
        try {
          final user = await ApiClient.getMe();
          if (mounted) {
            if (user['is_profile_complete'] == true) {
              context.go('/feed');
            } else {
              await ApiClient.logout();
              if (mounted) context.go('/auth/phone');
            }
          }
        } catch (_) {
          // If profile fetch fails (e.g. 401), ApiClient will handle it
          // But as a fallback, go to login
          if (mounted) context.go('/auth/phone');
        }
      } else {
        context.go('/auth/phone');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.orange),
      ),
    );
  }
}
