import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/message.dart';

class MessageListView extends StatelessWidget {
  final List<Message> messages; // Assuming a Message model exists

  const MessageListView({Key? key, required this.messages}) : super(key: key);

  bool _isNewDay(DateTime prev, DateTime current) {
    return prev.year != current.year ||
        prev.month != current.month ||
        prev.day != current.day;
  }

  String _getDateDividerText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) return 'Today';
    if (messageDate == yesterday) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true, // Standard for chat apps
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final showDivider = index == messages.length - 1 ||
            _isNewDay(messages[index + 1].timestamp, message.timestamp);

        return Column(
          children: [
            // Fix 1.3: Google Chat style Date Divider
            if (showDivider)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getDateDividerText(message.timestamp),
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),

            // Message Bubble wrapper
            Align(
              alignment:
                  message.isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  crossAxisAlignment: message.isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message.isMe
                            ? Colors.blue.shade100
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16).copyWith(
                          bottomRight:
                              message.isMe ? const Radius.circular(0) : null,
                          bottomLeft:
                              !message.isMe ? const Radius.circular(0) : null,
                        ),
                      ),
                      child: Text(message.text),
                    ),
                    const SizedBox(height: 4),
                    // Fix 1.3: Timestamp display under message
                    Text(
                      DateFormat('h:mm a').format(message.timestamp),
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
