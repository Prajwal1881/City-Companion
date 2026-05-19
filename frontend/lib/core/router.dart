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
import '../screens/rooms/room_detail_screen.dart';
import '../screens/rooms/room_form_screen.dart';
import '../screens/communities/communities_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/chat_room_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/feed/plan_details_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, __) => const MaterialPage(key: ValueKey('/splash'), child: SplashScreen()),
      ),
      // Auth flow
      GoRoute(
        path: '/auth/phone',
        pageBuilder: (_, __) => const MaterialPage(key: ValueKey('/auth/phone'), child: PhoneAuthScreen()),
      ),
      GoRoute(
        path: '/auth/otp',
        pageBuilder: (_, s) => MaterialPage(key: const ValueKey('/auth/otp'), child: OtpScreen(phone: s.extra as String)),
      ),
      GoRoute(
        path: '/auth/setup',
        pageBuilder: (_, __) => const MaterialPage(key: ValueKey('/auth/setup'), child: ProfileSetupScreen()),
      ),

      // Plan Details (Not part of shell)
      GoRoute(
        path: '/plan/details',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: const ValueKey('/plan/details'),
          child: PlanDetailsScreen(plan: state.extra as Map<String, dynamic>),
          transitionsBuilder: (_, __, ___, child) => child,
        ),
      ),

      // Chat Room (Not part of shell)
      GoRoute(
        path: '/chat/:convId',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: ValueKey('/chat/${state.pathParameters['convId']}'),
          child: ChatRoomScreen(conversationId: state.pathParameters['convId']!),
          transitionsBuilder: (_, __, ___, child) => child,
        ),
      ),

      // Room screens (no bottom nav)
      GoRoute(
        path: '/rooms/detail',
        builder: (_, s) => RoomDetailScreen(room: s.extra as Map<String, dynamic>),
      ),
      GoRoute(
        path: '/rooms/form',
        builder: (_, s) => RoomFormScreen(room: s.extra as Map<String, dynamic>?),
      ),

      // Main shell with bottom nav
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        pageBuilder: (context, state, child) => MaterialPage(
          key: const ValueKey('shell'),
          child: ShellScreen(child: child),
        ),
        routes: [
          GoRoute(
            path: '/feed',
            pageBuilder: (_, state) => CustomTransitionPage(
              key: const ValueKey('/feed'),
              child: const FeedScreen(),
              transitionsBuilder: (_, __, ___, child) => child,
            ),
          ),
          GoRoute(
            path: '/discover',
            pageBuilder: (_, state) => CustomTransitionPage(
              key: const ValueKey('/discover'),
              child: const DiscoverScreen(),
              transitionsBuilder: (_, __, ___, child) => child,
            ),
          ),
          GoRoute(
            path: '/rooms',
            pageBuilder: (_, state) => CustomTransitionPage(
              key: const ValueKey('/rooms'),
              child: const RoomsScreen(),
              transitionsBuilder: (_, __, ___, child) => child,
            ),
          ),
          GoRoute(
            path: '/communities',
            pageBuilder: (_, state) => CustomTransitionPage(
              key: const ValueKey('/communities'),
              child: const CommunitiesScreen(),
              transitionsBuilder: (_, __, ___, child) => child,
            ),
          ),
          GoRoute(
            path: '/chat',
            pageBuilder: (_, state) => CustomTransitionPage(
              key: const ValueKey('/chat'),
              child: const ChatListScreen(),
              transitionsBuilder: (_, __, ___, child) => child,
            ),
          ),

          GoRoute(
            path: '/profile',
            pageBuilder: (_, state) => CustomTransitionPage(
              key: const ValueKey('/profile'),
              child: const ProfileScreen(),
              transitionsBuilder: (_, __, ___, child) => child,
            ),
          ),
        ],
      ),
    ],
  );
});
