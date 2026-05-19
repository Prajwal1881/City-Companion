import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';

class FriendsTabScreen extends StatefulWidget {
  const FriendsTabScreen({super.key});
  @override
  State<FriendsTabScreen> createState() => _FriendsTabScreenState();
}

class _FriendsTabScreenState extends State<FriendsTabScreen> {
  List<dynamic> _friends  = [];
  int _requestCount       = 0;
  bool _loading           = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiClient.getFriends(),
        ApiClient.getFriendRequests(),
      ]);
      if (mounted) setState(() {
        _friends      = results[0] as List<dynamic>;
        _requestCount = (results[1] as List<dynamic>).length;
        _loading      = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDM(String friendId) async {
    try {
      final res = await ApiClient.getOrCreateDM(friendId);
      final convId = res['conversation_id'] as String?;
      if (convId != null && mounted) context.push('/chat/$convId');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          // ── Requests banner ──────────────────────────────────────────
          if (_requestCount > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF3FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.blue.withOpacity(0.2)),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.blue,
                  child: Icon(Icons.person_add_outlined, color: Colors.white, size: 20)),
                title: Text('$_requestCount pending friend request${_requestCount > 1 ? 's' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Tap to review', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.blue),
                onTap: () => context.go('/discover'),
              ),
            ),

          // ── Friends list ─────────────────────────────────────────────
          if (_friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(children: const [
                Text('🤝', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('No friends yet',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                SizedBox(height: 6),
                Text('Go to People → Discover to connect',
                  style: TextStyle(color: AppColors.sub, fontSize: 13)),
              ]),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                '${_friends.length} FRIEND${_friends.length > 1 ? 'S' : ''}',
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.sub, letterSpacing: 0.5),
              ),
            ),
            ..._friends.map((f) => _FriendRow(
              friend: f,
              onMessage: () => _openDM(f['id'].toString()),
            )),
          ],
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  final Map<String, dynamic> friend;
  final VoidCallback onMessage;
  const _FriendRow({required this.friend, required this.onMessage});

  @override
  Widget build(BuildContext context) {
    final name  = friend['name'] as String? ?? 'User';
    final prof  = friend['profession'] as String? ?? '';
    final photo = friend['profile_photo'] as String?;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildAvatar(name, photo),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: prof.isNotEmpty
          ? Text(prof, style: const TextStyle(fontSize: 12, color: AppColors.sub))
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        color: AppColors.orange,
        tooltip: 'Message',
        onPressed: onMessage,
      ),
    );
  }

  Widget _buildAvatar(String name, String? photo) {
    if (photo != null && photo.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: CachedNetworkImageProvider(ApiClient.photoUrl(photo)),
        backgroundColor: AppColors.orange,
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.orange,
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
    );
  }
}
