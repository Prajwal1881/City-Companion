import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/chat_service.dart';

// ─── Chat List ────────────────────────────────────────────────────────────────

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<dynamic> _convos = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final c = await ApiClient.getConversations();
      setState(() { _convos = c; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Messages'), backgroundColor: AppColors.card),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView.separated(
            itemCount: _convos.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEBEBEB)),
            itemBuilder: (_, i) {
              final c = _convos[i];
              final id = c['id']?.toString() ?? '';
              final unread = (c['unread_count'] as num?)?.toInt() ?? 0;
              return ListTile(
                tileColor: AppColors.card,
                leading: CircleAvatar(radius: 24, backgroundColor: AppColors.orange,
                  child: Text((c['name'] as String? ?? 'C')[0],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                title: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                subtitle: Text(c['last_message'] ?? 'No messages yet',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.sub)),
                trailing: unread > 0
                  ? Container(width: 22, height: 22, decoration: BoxDecoration(
                      color: AppColors.orange, shape: BoxShape.circle),
                    child: Center(child: Text('$unread', style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))))
                  : null,
                onTap: () => context.push('/chat/$id'),
              );
            },
          ),
    );
  }
}

// ─── Chat Room ────────────────────────────────────────────────────────────────

class ChatRoomScreen extends StatefulWidget {
  final String convId;
  const ChatRoomScreen({super.key, required this.convId});
  @override State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _chat = ChatService();
  final List<Map<String, dynamic>> _messages = [];
  final _ctrl  = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = true;
  // Hardcode current user id for demo — in production read from auth provider
  final _myId = 'me';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _chat.connect(widget.convId).then((_) {
      _chat.onMessage((msg) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      });
    });
  }

  Future<void> _loadHistory() async {
    try {
      final msgs = await ApiClient.getMessages(widget.convId);
      setState(() {
        _messages.addAll(msgs.cast<Map<String, dynamic>>());
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) { setState(() => _loading = false); }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  void _send() {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    _chat.send(txt);
    setState(() => _messages.add({'sender_id': _myId, 'content': txt, 'sent_at': DateTime.now().toIso8601String()}));
    _ctrl.clear();
    _scrollToBottom();
  }

  @override
  void dispose() { _chat.disconnect(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1ED),
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: AppColors.card,
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Column(children: [
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final isMe = m['sender_id']?.toString() == _myId;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.orange : AppColors.card,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0,1))],
                    ),
                    child: Text(m['content'] ?? '',
                      style: TextStyle(fontSize: 14, color: isMe ? Colors.white : AppColors.ink, height: 1.5)),
                  ),
                );
              },
            )),
        Container(color: AppColors.card, padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          child: Row(children: [
            Expanded(child: TextField(controller: _ctrl,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true, fillColor: AppColors.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
              ))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(width: 42, height: 42, decoration: BoxDecoration(
                color: AppColors.orange, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.orange.withOpacity(0.4), blurRadius: 8, offset: const Offset(0,3))]),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20)),
            ),
          ])),
      ]),
    );
  }
}
