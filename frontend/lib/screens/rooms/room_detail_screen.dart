import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';

class RoomDetailScreen extends StatefulWidget {
  final Map<String, dynamic> room;
  const RoomDetailScreen({super.key, required this.room});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late Map<String, dynamic> _room;
  String? _myId;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _room = Map<String, dynamic>.from(widget.room);
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final me = await ApiClient.getMe();
      if (mounted) setState(() => _myId = me['id']?.toString());
    } catch (_) {}
  }

  bool get _isOwner =>
      _myId != null && _myId == _room['owner_id']?.toString();

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete listing?'),
        content: const Text('This removes your room listing permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ApiClient.deleteRoom(_room['id'].toString());
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _deleting = false);
      }
    }
  }

  Future<void> _expressInterest() async {
    try {
      await ApiClient.connectUser(_room['owner_id'].toString());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interest sent! Owner will be notified.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send interest. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final area        = _room['area'] ?? '';
    final city        = _room['city'] ?? '';
    final rent        = _room['rent_inr'];
    final title       = _room['title'] ?? '$area Room';
    final description = _room['description'];
    final roomType    = _room['room_type'] ?? 'shared';
    final genderPref  = _room['gender_pref'] ?? 'any';
    final furnished   = _room['is_furnished'] == true;
    final smoking     = _room['smoking_allowed'] == true;
    final ownerName   = _room['owner_name'] ?? 'Unknown';
    final availableFrom = _room['available_from'] != null
        ? DateTime.tryParse(_room['available_from'].toString())
        : null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        title: Text('$area, $city'),
        actions: _isOwner
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: () async {
                    final updated = await context.push<bool>(
                        '/rooms/form', extra: _room);
                    if (updated == true && mounted) context.pop(true);
                  },
                ),
                _deleting
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ))
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: AppColors.rose,
                        tooltip: 'Delete',
                        onPressed: _delete,
                      ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Hero header ──────────────────────────────────────────────────
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEEF3FF), Color(0xFFE8F5F4)]),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🏠', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '₹${_fmt(rent)}/mo',
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ]),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 15, color: AppColors.sub),
                const SizedBox(width: 4),
                Text('$area, $city',
                  style: const TextStyle(color: AppColors.sub, fontSize: 13)),
              ]),
              const SizedBox(height: 18),

              // Tags
              Wrap(spacing: 8, runSpacing: 8, children: [
                _tag(_typeLabel(roomType), AppColors.blue, const Color(0xFFEEF3FF)),
                _tag(_genderLabel(genderPref), AppColors.violet, const Color(0xFFF5F0FF)),
                if (furnished) _tag('Furnished', AppColors.green, const Color(0xFFEDFFF4)),
                if (smoking) _tag('Smoking OK', AppColors.amber, const Color(0xFFFFF8E1)),
              ]),
              const SizedBox(height: 22),

              // Description
              if (description != null && description.toString().isNotEmpty) ...[
                const Text('About this room',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 8),
                Text(description.toString(),
                  style: const TextStyle(color: AppColors.sub, height: 1.65, fontSize: 14)),
                const SizedBox(height: 22),
              ],

              // Details card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  _detail('Posted by', ownerName, Icons.person_outline),
                  if (availableFrom != null)
                    _detail('Available from',
                      DateFormat('d MMM yyyy').format(availableFrom),
                      Icons.calendar_today_outlined),
                  _detail('Smoking',
                    smoking ? 'Allowed' : 'Not allowed',
                    Icons.smoking_rooms_outlined),
                  _detail('Furnished',
                    furnished ? 'Yes' : 'No',
                    Icons.chair_outlined),
                ]),
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ]),
      ),

      // ── Bottom CTA (non-owners only) ────────────────────────────────────
      bottomNavigationBar: _isOwner
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: ElevatedButton(
                  onPressed: _expressInterest,
                  child: const Text('Express Interest 💬'),
                ),
              ),
            ),
    );
  }

  Widget _tag(String text, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
    child: Text(text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
  );

  Widget _detail(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.sub),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: AppColors.sub, fontSize: 13)),
      const Spacer(),
      Text(value,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    ]),
  );

  String _fmt(dynamic v) {
    if (v == null) return '?';
    final n = int.tryParse(v.toString()) ?? 0;
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    return n.toString();
  }

  String _typeLabel(String t) =>
    const {'private': 'Private Room', 'shared': 'Shared Room', 'full_flat': 'Full Flat'}[t] ?? t;

  String _genderLabel(String g) =>
    const {'any': 'Any Gender', 'male': 'Males Only', 'female': 'Females Only'}[g] ?? g;
}
