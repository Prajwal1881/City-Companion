import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
          // ── Photo gallery / hero header ───────────────────────────────
          _RoomPhotoGallery(room: _room, rent: rent),

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

// ── Photo gallery / fallback hero ─────────────────────────────────────────────

class _RoomPhotoGallery extends StatefulWidget {
  final Map<String, dynamic> room;
  final dynamic rent;
  const _RoomPhotoGallery({required this.room, required this.rent});

  @override
  State<_RoomPhotoGallery> createState() => _RoomPhotoGalleryState();
}

class _RoomPhotoGalleryState extends State<_RoomPhotoGallery> {
  int _current = 0;

  void _openFullscreen(BuildContext context, List<String> photos, int index) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _FullscreenGallery(
        urls: photos.map((p) => ApiClient.photoUrl(p)).toList(),
        initialIndex: index,
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  String _fmt(dynamic v) {
    if (v == null) return '?';
    final n = int.tryParse(v.toString()) ?? 0;
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final photos = (widget.room['photos'] as List<dynamic>? ?? [])
        .map((p) => p['url']?.toString() ?? '')
        .where((u) => u.isNotEmpty)
        .toList();

    // No photos — show gradient + emoji fallback
    if (photos.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF3FF), Color(0xFFE8F5F4)])),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🏠', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(99)),
            child: Text('₹${_fmt(widget.rent)}/mo',
              style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ]),
      );
    }

    // Has photos — swipeable PageView gallery
    return SizedBox(
      height: 240,
      child: Stack(children: [
        PageView.builder(
          itemCount: photos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _openFullscreen(context, photos, i),
            child: CachedNetworkImage(
              imageUrl: ApiClient.photoUrl(photos[i]),
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFFEEF3FF),
                child: const Center(child: Icon(Icons.broken_image,
                  color: AppColors.muted, size: 48))),
            ),
          ),
        ),

        // Rent badge
        Positioned(
          bottom: 14, left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(99),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2),
                blurRadius: 8)]),
            child: Text('₹${_fmt(widget.rent)}/mo',
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ),

        // Page dots
        if (photos.length > 1)
          Positioned(
            bottom: 14, right: 16,
            child: Row(children: List.generate(photos.length, (i) => Container(
              width: i == _current ? 18 : 7,
              height: 7,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: i == _current ? AppColors.orange : Colors.white70,
                borderRadius: BorderRadius.circular(99)),
            ))),
          ),
      ]),
    );
  }
}

// ── Full-screen pinch-zoom gallery ────────────────────────────────────────────

class _FullscreenGallery extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _FullscreenGallery({required this.urls, required this.initialIndex});

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          // Swipeable + pinch-zoom pages
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white54)),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image, color: Colors.white30, size: 64),
                ),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context))),

          // Counter (1/3)
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(99)),
              child: Text('${_current + 1} / ${widget.urls.length}',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            )),

          // Page dots
          if (widget.urls.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0, right: 0,
              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.urls.length, (i) => Container(
                  width: i == _current ? 20 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _current ? AppColors.orange : Colors.white38,
                    borderRadius: BorderRadius.circular(99)),
                )))),
        ]),
      ),
    );
  }
}
