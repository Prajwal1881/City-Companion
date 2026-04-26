import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/chat_service.dart';

// ─── Chat List ────────────────────────────────────────────────────────────────

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
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
      setState(() {
        _convos = c;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _formatLastMessageTime(String? rawTime) {
    if (rawTime == null) return '';
    try {
      final dt = DateTime.parse(rawTime).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return DateFormat('h:mm a').format(dt);
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return DateFormat('EEE').format(dt);
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.card,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : _convos.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.orange,
                  child: ListView.separated(
                    itemCount: _convos.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72, color: AppColors.border),
                    itemBuilder: (_, i) {
                      final c = _convos[i];
                      final id = c['id']?.toString() ?? '';
                      final unread = (c['unread_count'] as num?)?.toInt() ?? 0;
                      final canDelete = c['can_delete'] == true;
                      final name = (c['name']?.toString().trim().isNotEmpty ?? false)
                          ? c['name'].toString().trim()
                          : 'Chat';
                      final lastMsg = c['last_message'] as String?;
                      final lastMsgTime = c['last_message_time'] as String?;
                      final avatarText = name.substring(0, 1).toUpperCase();
                      final hasUnread = unread > 0;

                      return InkWell(
                        onTap: () => context.push('/chat/$id'),
                        child: Container(
                          color: AppColors.card,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              // Avatar
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: AppColors.orange,
                                    child: Text(
                                      avatarText,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: hasUnread
                                                  ? FontWeight.w900
                                                  : FontWeight.w700,
                                              fontSize: 15,
                                              color: AppColors.ink,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (lastMsgTime != null)
                                          Text(
                                            _formatLastMessageTime(lastMsgTime),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: hasUnread
                                                  ? AppColors.orange
                                                  : AppColors.sub,
                                              fontWeight: hasUnread
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lastMsg ?? 'No messages yet',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: hasUnread
                                                  ? AppColors.ink
                                                  : AppColors.sub,
                                              fontWeight: hasUnread
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        if (hasUnread)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.orange,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              unread > 99 ? '99+' : '$unread',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        if (canDelete && !hasUnread)
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert,
                                                size: 18, color: AppColors.muted),
                                            padding: EdgeInsets.zero,
                                            onSelected: (value) async {
                                              if (value != 'delete') return;
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Delete Chat Thread'),
                                                  content: const Text(
                                                      'Delete this hosted plan chat thread for everyone?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(ctx, false),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(ctx, true),
                                                      style: TextButton.styleFrom(
                                                          foregroundColor: AppColors.rose),
                                                      child: const Text('Delete'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm != true) return;
                                              try {
                                                await ApiClient.deleteConversation(id);
                                                if (!mounted) return;
                                                setState(() => _convos.removeAt(i));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          'Plan chat thread deleted')),
                                                );
                                              } catch (_) {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          'Could not delete thread')),
                                                );
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem<String>(
                                                value: 'delete',
                                                child: Text('Delete thread'),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 48, color: AppColors.orange),
          ),
          const SizedBox(height: 16),
          const Text(
            'No conversations yet',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join a plan to start chatting\nwith people in your city!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.sub, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─── Chat Room ────────────────────────────────────────────────────────────────

class ChatRoomScreen extends StatefulWidget {
  final String convId;
  const ChatRoomScreen({super.key, required this.convId});
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
  String _convName = 'Chat';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadMe();
    _loadConvInfo();
    _chat.connect(widget.convId).then((_) {
      _chat.onMessage((msg) {
        if (mounted) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      });
    });
  }

  Future<void> _loadConvInfo() async {
    try {
      final convos = await ApiClient.getConversations();
      final conv = convos.firstWhere(
        (c) => c['id']?.toString() == widget.convId,
        orElse: () => <String, dynamic>{},
      );
      if (mounted && conv.isNotEmpty) {
        setState(() {
          _convName = (conv['name']?.toString().trim().isNotEmpty ?? false)
              ? conv['name'].toString().trim()
              : 'Chat';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMe() async {
    try {
      final me = await ApiClient.getMe();
      if (!mounted) return;
      setState(() => _myId = me['id']?.toString());
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final msgs = await ApiClient.getMessages(widget.convId);
      if (!mounted) return;
      setState(() {
        _messages.addAll(
          msgs.map((m) => Map<String, dynamic>.from(m as Map)).toList(),
        );
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    _chat.send(txt);
    _ctrl.clear();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _chat.disconnect();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatMessageTime(String? rawTime) {
    if (rawTime == null) return '';
    try {
      final dt = DateTime.parse(rawTime).toLocal();
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  String _formatDateDivider(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(dt);
    return DateFormat('MMMM d, y').format(dt);
  }

  bool _shouldShowDateDivider(int index) {
    if (index == 0) return true;
    final curr = _messages[index]['sent_at'] as String?;
    final prev = _messages[index - 1]['sent_at'] as String?;
    if (curr == null || prev == null) return false;
    try {
      final currDt = DateTime.parse(curr).toLocal();
      final prevDt = DateTime.parse(prev).toLocal();
      return currDt.day != prevDt.day ||
          currDt.month != prevDt.month ||
          currDt.year != prevDt.year;
    } catch (_) {
      return false;
    }
  }

  bool _shouldShowSenderName(int index) {
    final m = _messages[index];
    final isMe = _myId != null && m['sender_id']?.toString() == _myId;
    if (isMe) return false;
    if (index == 0) return true;
    final prev = _messages[index - 1];
    return prev['sender_id']?.toString() != m['sender_id']?.toString();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1ED),
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.ink, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/chat');
            }
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.orange,
              child: Text(
                _convName.isNotEmpty ? _convName[0].toUpperCase() : 'C',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _convName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Plan Chat',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.sub,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.orange))
                : _messages.isEmpty
                    ? _buildEmptyChat()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final m = _messages[i];
                          final isMe = _myId != null &&
                              m['sender_id']?.toString() == _myId;
                          final timeStr =
                              _formatMessageTime(m['sent_at'] as String?);
                          final showDivider = _shouldShowDateDivider(i);
                          final showSender = _shouldShowSenderName(i);

                          return Column(
                            children: [
                              // ── Date divider ──────────────────────────
                              if (showDivider)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: [
                                      const Expanded(
                                          child: Divider(
                                              color: AppColors.border,
                                              thickness: 1)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: Text(
                                          () {
                                            try {
                                              return _formatDateDivider(
                                                  DateTime.parse(
                                                          m['sent_at'] ?? '')
                                                      .toLocal());
                                            } catch (_) {
                                              return '';
                                            }
                                          }(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.sub,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const Expanded(
                                          child: Divider(
                                              color: AppColors.border,
                                              thickness: 1)),
                                    ],
                                  ),
                                ),

                              // ── Sender name (group chats) ─────────────
                              if (showSender && !isMe)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        left: 4, bottom: 3),
                                    child: Text(
                                      m['sender_name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.sub,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),

                              // ── Message bubble ────────────────────────
                              Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin:
                                          const EdgeInsets.only(bottom: 2),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.75),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? AppColors.orange
                                            : AppColors.card,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(18),
                                          topRight: const Radius.circular(18),
                                          bottomLeft:
                                              Radius.circular(isMe ? 18 : 4),
                                          bottomRight:
                                              Radius.circular(isMe ? 4 : 18),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.06),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1))
                                        ],
                                      ),
                                      child: Text(
                                        m['content'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isMe
                                              ? Colors.white
                                              : AppColors.ink,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                    // ── Timestamp ────────────────────
                                    if (timeStr.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Text(
                                          timeStr,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.muted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // ── Input bar ─────────────────────────────────────────────────────
          Container(
            color: AppColors.card,
            padding: EdgeInsets.fromLTRB(
                12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    onSubmitted: (_) => _send(),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle:
                          const TextStyle(color: AppColors.muted, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                            color: AppColors.border, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                            color: AppColors.border, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                            color: AppColors.orange, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.orange.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.waving_hand_rounded,
                size: 40, color: AppColors.orange),
          ),
          const SizedBox(height: 14),
          const Text(
            'Say hello! 👋',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          const Text(
            'Be the first to send a message.',
            style: TextStyle(fontSize: 13, color: AppColors.sub),
          ),
        ],
      ),
    );
  }
}
