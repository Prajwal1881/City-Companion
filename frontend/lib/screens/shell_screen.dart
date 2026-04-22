import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../services/push_notification_service.dart';

class ShellScreen extends StatefulWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  @override
  void initState() {
    super.initState();
    // Register FCM token with backend once the user is logged in
    // and the main shell is mounted
    PushNotificationService.registerForCurrentUser();
  }

  static const _tabs = [
    _Tab('/feed',        Icons.home_rounded,         'Feed'),
    _Tab('/discover',    Icons.explore_rounded,       'People'),
    _Tab('/rooms',       Icons.apartment_rounded,     'Rooms'),
    _Tab('/communities', Icons.groups_rounded,        'Groups'),
    _Tab('/chat',        Icons.chat_bubble_rounded,   'Chat'),
    _Tab('/profile',     Icons.person_rounded,        'Me'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) => context.go(_tabs[i].path),
        items: _tabs.map((t) => BottomNavigationBarItem(
          icon: Icon(t.icon),
          label: t.label,
        )).toList(),
      ),
    );
  }
}

class _Tab {
  final String path;
  final IconData icon;
  final String label;
  const _Tab(this.path, this.icon, this.label);
}
