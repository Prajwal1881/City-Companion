import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import 'conversation_tile.dart';

class MessagesTabScreen extends StatefulWidget {
  const MessagesTabScreen({super.key});
  @override
  State<MessagesTabScreen> createState() => _MessagesTabScreenState();
}

class _MessagesTabScreenState extends State<MessagesTabScreen> {
  List<dynamic> _convos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await ApiClient.getConversations();
      if (!mounted) return;
      setState(() {
        _convos = c;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _formatTime(int? timestampMs) {
    if (timestampMs == null) return '';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final messageDate = DateTime(date.year, date.month, date.day);

      if (messageDate == today) {
        return DateFormat('h:mm a').format(date);
      } else if (messageDate == yesterday) {
        return 'Yesterday';
      } else {
        return DateFormat('MMM d').format(date);
      }
    } catch (_) {
      return '';
    }
  }

  void _showDeleteDialog(int index) async {
    final c = _convos[index];
    final id = c['id']?.toString() ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat Thread'),
        content: const Text('Delete this chat thread for everyone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiClient.deleteConversation(id);
      if (!mounted) return;
      setState(() => _convos.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thread deleted')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete thread')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              itemCount: _convos.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFEBEBEB)),
              itemBuilder: (_, i) {
                final c = _convos[i];
                final id = c['id']?.toString() ?? '';
                final name = (c['name']?.toString().trim().isNotEmpty ?? false)
                    ? c['name'].toString().trim()
                    : 'Chat';

                return ConversationTile(
                  name: name,
                  lastMessage: c['last_message'] ?? 'No messages yet',
                  time: _formatTime(c['last_message_at'] as int? ?? c['updated_at'] as int?),
                  unreadCount: (c['unread_count'] as num?)?.toInt() ?? 0,
                  isOnline: c['is_online'] == true,
                  onTap: () => context.push('/chat/$id'),
                  onDelete: c['can_delete'] == true
                      ? () => _showDeleteDialog(i)
                      : null,
                );
              },
            ),
          );
  }
}
