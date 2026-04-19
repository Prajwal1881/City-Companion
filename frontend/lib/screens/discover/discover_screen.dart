// ─── Discover Screen ──────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<dynamic> _users = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      // TODO: use real device location
      final users = await ApiClient.getNearby(lat: 12.9716, lng: 77.5946);
      setState(() { _users = users; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Discover People'), backgroundColor: AppColors.card),
      body: Column(children: [
        Container(color: AppColors.card, padding: const EdgeInsets.fromLTRB(16,8,16,12),
          child: TextField(controller: _search, onChanged: (_) => setState((){}),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search name, interest...',
              filled: true, fillColor: AppColors.bg))),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _UserCard(user: _users[i]),
            )),
      ]),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user['name'] as String? ?? 'User';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 26, backgroundColor: AppColors.orange,
            child: Text(name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text('${user['profession'] ?? ''} · ${user['hometown'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.sub)),
          ])),
          Text('📍 ${user['distance_km'] ?? '?'} km', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8),
            side: const BorderSide(color: AppColors.border)), child: const Text('💬 Message'))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8)),
            child: const Text('🤝 Connect'))),
        ]),
      ]),
    );
  }
}
