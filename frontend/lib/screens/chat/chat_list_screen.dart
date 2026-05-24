import 'package:flutter/material.dart';
import 'widgets/messages_tab.dart';

// ─── Chat Screen ─────────────────────────────────────────────────────────────

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('Chat', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement Global Search
            },
          )
        ],
      ),
      body: const MessagesTabScreen(),
    );
  }
}
