import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final u = await ApiClient.getMe();
      setState(() => _user = u);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }
    
    final name = _user?['name'] as String? ?? 'User';
    final profession = _user?['profession'] as String? ?? 'Explorer';
    final hometown = _user?['hometown'] as String?;
    
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Container(
          color: AppColors.ink,
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
          child: Column(children: [
            Container(width: 84, height: 84, decoration: BoxDecoration(
              shape: BoxShape.circle, color: AppColors.orange,
              border: Border.all(color: AppColors.orange, width: 3),
              boxShadow: [BoxShadow(color: AppColors.orange.withOpacity(0.5), blurRadius: 16, spreadRadius: 2)]),
              child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)))),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(profession, style: const TextStyle(color: Colors.white54, fontSize: 13)),
            if (hometown != null && hometown.isNotEmpty)
              Text('From $hometown 🧡', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _stat('⭐', '4.8', 'Score'),
              const SizedBox(width: 32),
              _stat('🤝', '12', 'Friends'),
              const SizedBox(width: 32),
              _stat('🚀', '5', 'Hosted'),
            ]),
          ]),
        )),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Verification card
            _card('VERIFICATION', [
              _row('📱', 'Phone number', '✅ Verified', true),
              _row('📧', 'Email address', '✅ Verified', true),
              _row('🪪', 'ID check', '⏳ Pending', false),
            ]),
            const SizedBox(height: 8),
            // Settings
            ...['⚙️ Settings', '🔔 Notifications', '🔒 Privacy & Safety', '❓ Help & Support', '🚪 Log out'].map((item) =>
              Container(margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, width: 1.5)),
                child: ListTile(title: Text(item, style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () async {
                    if (item == '🚪 Log out') {
                      await ApiClient.logout();
                      if (context.mounted) {
                        context.go('/auth/phone');
                      }
                    }
                  })),
            ),
          ])),
        ),
      ]),
    );
  }

  Widget _stat(String icon, String val, String label) => Column(children: [
    Text('$icon $val', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
  ]);

  Widget _card(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border, width: 1.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sub, letterSpacing: 0.5)),
      const SizedBox(height: 10),
      ...children,
    ]),
  );

  Widget _row(String icon, String label, String status, bool ok) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Text('$icon $label', style: const TextStyle(fontSize: 14)),
      const Spacer(),
      Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
        color: ok ? AppColors.green : AppColors.amber)),
      if (i != 2) const Divider(height: 1),
    ]),
  );

  int get i => 0; // placeholder
}
