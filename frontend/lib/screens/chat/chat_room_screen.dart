import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/api_endpoints.dart';
import '../../services/api_client.dart';
import '../../services/chat_service.dart';
import '../../services/local_storage_service.dart';

// ==========================================
// 1. CHAT ROOM APP BAR WIDGET
// ==========================================
class ChatRoomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final int memberCount;
  final bool isOnline;

  const ChatRoomAppBar({
    Key? key,
    required this.title,
    this.memberCount = 0,
    this.isOnline = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.card,
      foregroundColor: AppColors.ink,
      leading: BackButton(
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/chat');
          }
        },
      ),
      title: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: AppColors.bg,
                  child: Icon(Icons.group, color: AppColors.sub),
                ),
                if (isOnline)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  )
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                if (memberCount > 2)
                  Text(
                    '$memberCount members',
                    style: const TextStyle(fontSize: 11, color: AppColors.sub),
                  )
                else if (memberCount > 0)
                  Text(
                    isOnline ? 'Active now' : 'Offline',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isOnline ? AppColors.green : AppColors.sub),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            // TODO: Open Group Info / Plan Details
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ==========================================
// 2. MAIN CHAT ROOM SCREEN
// ==========================================
class ChatRoomScreen extends StatefulWidget {
  final String conversationId;

  const ChatRoomScreen({Key? key, required this.conversationId})
      : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _chat = ChatService();
  final List<Map<String, dynamic>> _messages = [];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = true;
  String? _myId;
  String _title = 'Chat';
  int _memberCount = 0;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadMe();
    await _loadHistory();
    _connectWs();
    _loadMetadata();
  }

  Future<void> _loadMe() async {
    try {
      final me = await ApiClient.getMe();
      if (mounted) setState(() => _myId = me['id']?.toString());
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      // 1. Load from local DB immediately
      final localMsgs = await LocalStorageService.getMessages(widget.conversationId);
      if (mounted && localMsgs.isNotEmpty) {
        setState(() {
          _messages.clear();
          _messages.addAll(localMsgs);
          _loading = false;
        });
      }

      // 2. Fetch from network
      final msgs = await ApiClient.getMessages(widget.conversationId);
      
      // 3. Sync to local DB
      await LocalStorageService.syncMessages(widget.conversationId, msgs);

      // 4. Reload from local DB
      final updatedLocalMsgs = await LocalStorageService.getMessages(widget.conversationId);
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(updatedLocalMsgs);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadMetadata() async {
    try {
      final convs = await ApiClient.getConversations();
      final current = convs.firstWhere(
        (c) => c['id']?.toString() == widget.conversationId,
        orElse: () => null,
      );
      if (current != null && mounted) {
        setState(() {
          _title = current['name'] ?? 'Chat';
          _memberCount = (current['member_count'] as num?)?.toInt() ?? 0;
          _isOnline = current['is_online'] == true;
        });
      }
    } catch (_) {}
  }

  DateTime? _messageTimestamp(Map<String, dynamic> message) {
    final raw = message['timestamp'] ?? message['sent_at'] ?? message['created_at'];
    if (raw == null) return null;
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is String) {
      return DateTime.tryParse(raw)?.toLocal();
    }
    return null;
  }

  void _connectWs() {
    _chat.connect(widget.conversationId).then((_) {
      _chat.onMessage((msg) async {
        // Save to local storage
        final localMap = LocalStorageService.mapServerMessageToLocal(msg);
        await LocalStorageService.saveServerMessage(
           id: localMap['id'],
           conversationId: localMap['conversation_id'],
           senderId: localMap['sender_id'],
           text: localMap['text'],
           timestamp: localMap['timestamp'],
        );

        if (mounted) {
          setState(() {
            // 1. Check if this message ID already exists (deduplication)
            final existingIdIdx = _messages.indexWhere((m) => m['id']?.toString() == localMap['id']?.toString());
            if (existingIdIdx != -1) {
              _messages[existingIdIdx] = localMap;
              return;
            }

            // 2. Find if we have a pending message matching this content to replace
            final pendingIdx = _messages.indexWhere((m) => 
              m['status_code'] == 0 && 
              (m['text'] == msg['content'] || m['content'] == msg['content'])
            );

            if (pendingIdx != -1) {
              _messages[pendingIdx] = localMap; // Replace pending with official server message
            } else {
              _messages.insert(0, localMap); // New message from someone else
            }
          });
        }
      });
    }).catchError((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect to live chat')),
      );
    });
  }

  void _send() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    _ctrl.clear();

    final ts = DateTime.now().millisecondsSinceEpoch;
    
    // 1. Save locally as pending
    final msgId = await LocalStorageService.savePendingMessage(
      conversationId: widget.conversationId,
      senderId: _myId ?? '',
      text: txt,
      timestamp: ts,
    );

    // 2. Display instantly
    if (mounted) {
      setState(() {
        _messages.insert(0, {
          'id': msgId,
          'sender_id': _myId,
          'text': txt,
          'timestamp': ts,
          'status_code': 0, // 0 = Pending
        });
      });
    }

    // 3. Send over network
    _chat.send(txt);
  }

  @override
  void dispose() {
    _chat.disconnect();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _formatDateDivider(DateTime date) {
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: ChatRoomAppBar(
        title: _title,
        memberCount: _memberCount,
        isOnline: _isOnline,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true,
                    controller: _scroll,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final isMe =
                          _myId != null && m['sender_id']?.toString() == _myId;
                      final ts = _messageTimestamp(m);
                      if (ts == null) return const SizedBox.shrink();

                      bool showDivider = false;
                      if (index == _messages.length - 1) {
                        showDivider = true;
                      } else {
                        final currentMsgDate = ts;
                        final prevMsgDate =
                            _messageTimestamp(_messages[index + 1]) ?? ts;
                        showDivider = currentMsgDate.day != prevMsgDate.day ||
                            currentMsgDate.month != prevMsgDate.month ||
                            currentMsgDate.year != prevMsgDate.year;
                      }

                      // Timestamp Clustering Logic
                      bool showTimestamp = true;
                      if (index > 0) {
                        final newerMessage = _messages[index - 1];
                        final newerIsMe = _myId != null && newerMessage['sender_id']?.toString() == _myId;
                        final newerTs = _messageTimestamp(newerMessage);
                        
                        if (newerTs != null) {
                          final isSameUser = newerIsMe == isMe;
                          final timeDiff = newerTs.difference(ts).inMinutes.abs();
                          if (isSameUser && timeDiff < 1) {
                            showTimestamp = false;
                          }
                        }
                      }

                      final textContent = m['text'] ?? m['content'] ?? '';
                      final statusCode = m['status_code'] as int? ?? 1;

                      return Column(
                        children: [
                          if (showDivider)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.border,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatDateDivider(ts),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.sub,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(16, showTimestamp ? 4 : 2, 16, showTimestamp ? 4 : 2),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? const Color(0xFFD4E6FF)
                                          : AppColors.card,
                                      borderRadius:
                                          BorderRadius.circular(16).copyWith(
                                        bottomRight: isMe && showTimestamp
                                            ? const Radius.circular(0)
                                            : null,
                                        bottomLeft: !isMe && showTimestamp
                                            ? const Radius.circular(0)
                                            : null,
                                      ),
                                      border: isMe
                                          ? null
                                          : Border.all(color: AppColors.border),
                                    ),
                                    child: Text(
                                      textContent,
                                      style: const TextStyle(
                                        color: AppColors.ink,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (showTimestamp) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          DateFormat('h:mm a').format(ts),
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.sub,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 4),
                                          if (statusCode == 3)
                                            const Text(
                                              '• Seen',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.blue,
                                                  fontWeight: FontWeight.w700),
                                            )
                                          else if (statusCode == 2)
                                            const Text(
                                              '• Delivered',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.sub),
                                            )
                                          else if (statusCode == 1)
                                            const Text(
                                              '• Sent',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.sub),
                                            )
                                          else
                                            const Icon(Icons.access_time, size: 10, color: AppColors.sub),
                                        ],
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 20),
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: const TextStyle(color: AppColors.sub),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.bg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: AppColors.orange, size: 24),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
