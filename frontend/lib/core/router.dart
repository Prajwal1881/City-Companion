import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/shell_screen.dart';
import '../screens/auth/phone_auth_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import '../screens/feed/feed_screen.dart';
import '../screens/discover/discover_screen.dart';
import '../screens/rooms/rooms_screen.dart';
import '../screens/communities/communities_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/chat_room_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/feed/plan_details_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      // Auth flow
      GoRoute(path: '/auth/phone',   builder: (_, __) => const PhoneAuthScreen()),
      GoRoute(path: '/auth/otp',     builder: (_, s)  => OtpScreen(phone: s.extra as String)),
      GoRoute(path: '/auth/setup',   builder: (_, __) => const ProfileSetupScreen()),

      // Plan Details — outside shell so back button works correctly
      GoRoute(
        path: '/plan/details',
        builder: (context, state) => PlanDetailsScreen(plan: state.extra as Map<String, dynamic>),
      ),

      // Chat Room — outside shell so back button pops correctly from any entry point
      GoRoute(
        path: '/chat/:convId',
        builder: (_, s) => ChatRoomScreen(convId: s.pathParameters['convId']!),
      ),

      // Main shell with bottom nav
      ShellRoute(
        builder: (_, __, child) => ShellScreen(child: child),
        routes: [
          GoRoute(path: '/feed',        builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/discover',    builder: (_, __) => const DiscoverScreen()),
          GoRoute(path: '/rooms',       builder: (_, __) => const RoomsScreen()),
          GoRoute(path: '/communities', builder: (_, __) => const CommunitiesScreen()),
          GoRoute(path: '/chat',        builder: (_, __) => const ChatListScreen()),
          GoRoute(path: '/profile',     builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
