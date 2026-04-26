import 'package:flutter/material.dart';
import 'widgets/messages_tab.dart';
import 'friends_tab_screen.dart';

// ─── Chat Tabs Container ──────────────────────────────────────────────────────

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title: const Text('Chat', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            labelColor: Color(0xFF1A73E8), // Google Blue
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF1A73E8),
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Messages'),
              Tab(text: 'Friends'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // TODO: Implement Global Search
              },
            )
          ],
        ),
        body: const TabBarView(
          children: [
            MessagesTabScreen(),
            FriendsTabScreen(),
          ],
        ),
      ),
    );
  }
}
