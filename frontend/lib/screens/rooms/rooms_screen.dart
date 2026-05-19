import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});
  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List<dynamic> _rooms = [];
  bool _loading = true;
  String? _cityFilter;
  String? _typeFilter;

  static const _filterCities = [
    'Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai',
    'Pune', 'Kolkata', 'Ahmedabad', 'Gurgaon', 'Noida',
  ];
  static const _typeOptions = <String, String>{
    'private': 'Private', 'shared': 'Shared', 'full_flat': 'Full Flat',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rooms = await ApiClient.getRooms(
          city: _cityFilter, roomType: _typeFilter);
      setState(() {
        _rooms = rooms;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Roommates'),
        backgroundColor: AppColors.card,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: () =>
                  context.push('/rooms/form').then((_) => _load()),
              child: const Text('+ Post Room'),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // ── City filter chips ──────────────────────────────────────────────
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: _filterCities.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (i == 0) {
                return _chip('All Cities', _cityFilter == null,
                    () => setState(() { _cityFilter = null; _load(); }));
              }
              final city = _filterCities[i - 1];
              return _chip(city, _cityFilter == city,
                  () => setState(() { _cityFilter = city; _load(); }));
            },
          ),
        ),

        // ── Room type filter chips ─────────────────────────────────────────
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              _chip('All Types', _typeFilter == null,
                  () => setState(() { _typeFilter = null; _load(); })),
              ..._typeOptions.entries.map((e) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _chip(e.value, _typeFilter == e.key,
                    () => setState(() { _typeFilter = e.key; _load(); })),
              )),
            ],
          ),
        ),

        const Divider(height: 1, color: AppColors.border),

        // ── Room list ──────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rooms.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _rooms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => _RoomCard(
                          room: _rooms[i],
                          onTap: () => context
                              .push('/rooms/detail', extra: _rooms[i])
                              .then((_) => _load()),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.orange : AppColors.card,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: selected ? AppColors.orange : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.sub,
            )),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🏠', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        const Text('No rooms found',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 8),
        Text(
          'Be the first to post in ${_cityFilter ?? 'your city'}!',
          style: const TextStyle(color: AppColors.sub),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () =>
              context.push('/rooms/form').then((_) => _load()),
          child: const Text('+ Post a Room'),
        ),
      ]),
    );
  }
}

// ── Room card ────────────────────────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;
  const _RoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rent = room['rent_inr'];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Card header
          Container(
            height: 100,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFFEEF3FF), Color(0xFFE8F5F4)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Stack(children: [
              const Center(child: Text('🏠', style: TextStyle(fontSize: 44))),
              Positioned(
                top: 12,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '₹${_fmt(rent)}/mo',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                ),
              ),
            ]),
          ),

          // Card body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                room['title'] ?? room['area'] ?? '',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.sub),
                const SizedBox(width: 4),
                Text(
                  '${room['area'] ?? ''}, ${room['city'] ?? ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.sub),
                ),
              ]),
              if (room['description'] != null &&
                  room['description'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    room['description'].toString(),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.sub, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(spacing: 7, runSpacing: 6, children: [
                _tag(room['room_type'] ?? 'shared',
                    AppColors.blue, const Color(0xFFEEF3FF)),
                _tag(room['gender_pref'] ?? 'any',
                    AppColors.violet, const Color(0xFFF5F0FF)),
                if (room['is_furnished'] == true)
                  _tag('Furnished', AppColors.green, const Color(0xFFEDFFF4)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.person_outline, size: 13, color: AppColors.muted),
                const SizedBox(width: 4),
                Text('by ${room['owner_name'] ?? ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _tag(String text, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration:
        BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
    child: Text(text,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );

  String _fmt(dynamic v) {
    if (v == null) return '?';
    final n = int.tryParse(v.toString()) ?? 0;
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return n.toString();
  }
}
