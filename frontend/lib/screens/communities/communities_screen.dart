import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});
  @override State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  List<dynamic> _communities = [];
  final _joined = <String>{};
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final c = await ApiClient.getCommunities(city: 'Bangalore');
      setState(() { _communities = c; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Communities'), backgroundColor: AppColors.card),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _communities.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final c = _communities[i];
              final id = c['id']?.toString() ?? '';
              final isJoined = _joined.contains(id);
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border, width: 1.5)),
                child: Row(children: [
                  Container(width: 52, height: 52, decoration: BoxDecoration(
                    color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text(c['emoji'] ?? '👥', style: const TextStyle(fontSize: 26)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(c['description'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.sub), maxLines: 2),
                    const SizedBox(height: 5),
                    Text('👥 ${c['member_count'] ?? 0} members', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                  ])),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () async {
                      if (isJoined) {
                        await ApiClient.leaveCommunity(id);
                        setState(() => _joined.remove(id));
                      } else {
                        await ApiClient.joinCommunity(id);
                        setState(() => _joined.add(id));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isJoined ? AppColors.bg : AppColors.orange,
                      foregroundColor: isJoined ? AppColors.sub : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(isJoined ? '✓ Joined' : '+ Join',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ]),
              );
            },
          ),
    );
  }
}
