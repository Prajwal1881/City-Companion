import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});
  @override State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List<dynamic> _rooms = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final rooms = await ApiClient.getRooms(city: 'Bangalore');
      setState(() { _rooms = rooms; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Roommates'),
        backgroundColor: AppColors.card,
        actions: [
          Padding(padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton(onPressed: () {}, child: const Text('+ Post Room'))),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _rooms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) => _RoomCard(room: _rooms[i]),
          ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0,2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 100, decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFFEEF3FF), const Color(0xFFE8F5F4)]),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
        ), child: const Center(child: Text('🏠', style: TextStyle(fontSize: 44)))),
        Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(room['area'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            RichText(text: TextSpan(children: [
              TextSpan(text: '₹${room['rent_inr'] ?? '?'}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.orange)),
              const TextSpan(text: '/mo', style: TextStyle(fontSize: 12, color: AppColors.sub)),
            ])),
          ]),
          const SizedBox(height: 6),
          Text(room['description'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.sub, height: 1.5)),
          const SizedBox(height: 10),
          Wrap(spacing: 7, children: [
            _tag(room['room_type'] ?? 'shared', AppColors.blue, const Color(0xFFEEF3FF)),
            _tag('${room['gender_pref'] ?? 'any'} only', const Color(0xFF7C3AED), const Color(0xFFF5F0FF)),
            if (room['is_furnished'] == true) _tag('Furnished', AppColors.green, const Color(0xFFEDFFF4)),
          ]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {},
            child: const Text('Express Interest 💬'),
          )),
        ])),
      ]),
    );
  }

  Widget _tag(String text, Color color, Color bg) {
    return Container(margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)));
  }
}
