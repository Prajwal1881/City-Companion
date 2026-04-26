import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class ConversationTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isOnline;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ConversationTile({
    Key? key,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
    required this.onTap,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isUnread = unreadCount > 0;

    return ListTile(
      onTap: onTap,
      tileColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.bg,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontSize: 15,
          // MAXIMUM BOLD for unread
          fontWeight: isUnread ? FontWeight.w900 : FontWeight.w600,
          color: isUnread ? AppColors.ink : AppColors.sub,
        ),
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          // Bold preview for unread
          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
          color: isUnread ? AppColors.ink : AppColors.muted,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isUnread ? FontWeight.w800 : FontWeight.w500,
                  color: isUnread ? AppColors.blue : AppColors.sub,
                ),
              ),
              const SizedBox(height: 6),
              if (isUnread)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              else
                const SizedBox(height: 18),
            ],
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 18, color: AppColors.muted),
              onPressed: onDelete,
            ),
          ]
        ],
      ),
    );
  }
}
