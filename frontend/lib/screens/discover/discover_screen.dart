import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0;
  final dlat = (lat2 - lat1) * math.pi / 180;
  final dlon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dlat / 2) * math.sin(dlat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
      math.sin(dlon / 2) * math.sin(dlon / 2);
  return R * 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('People'),
        backgroundColor: AppColors.card,
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.orange,
          unselectedLabelColor: AppColors.sub,
          indicatorColor: AppColors.orange,
          tabs: const [Tab(text: 'Discover'), Tab(text: 'Friends')],
        ),
      ),
      body: TabBarView(controller: _tab, children: const [
        _RadarMapTab(),
        _FriendsTab(),
      ]),
    );
  }
}

// ── Discover map tab ─────────────────────────────────────────────────────────

class _RadarMapTab extends StatefulWidget {
  const _RadarMapTab();
  @override
  State<_RadarMapTab> createState() => _RadarMapTabState();
}

class _RadarMapTabState extends State<_RadarMapTab> {
  static final _fallback = ll.LatLng(12.9716, 77.5946);

  ll.LatLng? _myLoc;
  bool _locDenied = false;
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _rooms = [];
  double _radiusKm = 3.0;
  bool _loading = false;
  bool _didFetch = false;
  bool _showPlans = true;
  bool _showRooms = true;

  final _mapCtrl = MapController();
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _acquireLocation();
    if (mounted && _myLoc != null) _fetchData();
  }

  Future<void> _acquireLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) setState(() => _locDenied = true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (mounted) {
        setState(() {
          _myLoc = ll.LatLng(pos.latitude, pos.longitude);
          _locDenied = false;
        });
        _mapCtrl.move(_myLoc!, 14);
      }
    } catch (_) {
      if (mounted) setState(() => _locDenied = true);
    }
  }

  Future<void> _fetchData() async {
    if (_myLoc == null || _loading) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.getNearbyPlans(
          lat: _myLoc!.latitude,
          lng: _myLoc!.longitude,
          radiusKm: _radiusKm,
        ),
        ApiClient.getRooms(),
      ]).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final plans = results[0] as List<Map<String, dynamic>>;
      final allRooms = results[1];
      final nearbyRooms = _filterNearbyRooms(allRooms);

      setState(() {
        _plans = plans;
        _rooms = nearbyRooms;
        _loading = false;
        _didFetch = true;
      });
      _buildMarkers();
    } catch (_) {
      if (mounted) setState(() { _loading = false; _didFetch = true; });
    }
  }

  List<Map<String, dynamic>> _filterNearbyRooms(List<dynamic> rooms) {
    if (_myLoc == null) return [];
    final result = <Map<String, dynamic>>[];
    for (final r in rooms) {
      final lat = (r['latitude'] as num?)?.toDouble();
      final lng = (r['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final dist = _haversineKm(_myLoc!.latitude, _myLoc!.longitude, lat, lng);
      if (dist <= _radiusKm) {
        result.add({...Map<String, dynamic>.from(r as Map), 'distance_km': dist});
      }
    }
    result.sort((a, b) =>
        (a['distance_km'] as double).compareTo(b['distance_km'] as double));
    return result;
  }

  void _buildMarkers() {
    final markers = <Marker>[];
    if (_showPlans) {
      for (final p in _plans) {
        final lat = (p['latitude'] as num?)?.toDouble();
        final lng = (p['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final em = _catEmoji(p['category'] as String? ?? '');
        markers.add(Marker(
          point: ll.LatLng(lat, lng),
          width: 44, height: 44,
          child: GestureDetector(
            onTap: () => context.push('/plan/details', extra: p),
            child: Tooltip(
              message: '${p['title']} · ${(p['distance_km'] as num?)?.toStringAsFixed(1) ?? '?'} km',
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: AppColors.orange.withValues(alpha: 0.4),
                      blurRadius: 8, spreadRadius: 1)],
                ),
                child: Center(child: Text(em,
                    style: const TextStyle(fontSize: 20))),
              ),
            ),
          ),
        ));
      }
    }
    if (_showRooms) {
      for (final r in _rooms) {
        final lat = (r['latitude'] as num?)?.toDouble();
        final lng = (r['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        markers.add(Marker(
          point: ll.LatLng(lat, lng),
          width: 44, height: 44,
          child: GestureDetector(
            onTap: () => _showRoomSheet(r),
            child: Tooltip(
              message: '${r['title']} · ${(r['distance_km'] as num?)?.toStringAsFixed(1) ?? '?'} km',
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.4),
                      blurRadius: 8, spreadRadius: 1)],
                ),
                child: const Center(child: Text('🏠',
                    style: TextStyle(fontSize: 20))),
              ),
            ),
          ),
        ));
      }
    }
    if (mounted) setState(() => _markers = markers);
  }

  void _showRoomSheet(Map<String, dynamic> room) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room['title'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              '₹${room['rent_inr']}/mo  ·  ${room['area'] ?? ''}, ${room['city'] ?? ''}',
              style: const TextStyle(color: AppColors.sub, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              _tag(room['room_type'] ?? 'shared', AppColors.blue),
              _tag('${room['gender_pref'] ?? 'any'} only', AppColors.violet),
              if (room['is_furnished'] == true) _tag('Furnished', AppColors.green),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Express Interest'))),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(99)),
    child: Text(text, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );

  void _zoom(double delta) {
    try {
      final cam = _mapCtrl.camera;
      _mapCtrl.move(cam.center, (cam.zoom + delta).clamp(3.0, 19.0));
    } catch (_) {}
  }

  static String _catEmoji(String cat) {
    const m = {
      'food': '🍔', 'play': '🎮', 'gym': '💪', 'ride': '🚗',
      'hangout': '☕', 'trek': '🥾', 'party': '🎉', 'music': '🎵',
    };
    return m[cat.toLowerCase()] ?? '📍';
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final target = _myLoc ?? _fallback;
    final hasItems = _plans.isNotEmpty || _rooms.isNotEmpty;

    if (_locDenied && _myLoc == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_off_rounded, size: 56, color: AppColors.sub),
            const SizedBox(height: 16),
            const Text('Location access is needed to discover\nplans and rooms nearby.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.sub, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() => _locDenied = false);
                _acquireLocation().then((_) {
                  if (_myLoc != null && mounted) _fetchData();
                });
              },
              child: const Text('Enable Location')),
          ]),
        ),
      );
    }

    return Stack(children: [
      FlutterMap(
        mapController: _mapCtrl,
        options: MapOptions(initialCenter: target, initialZoom: 14),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.syntra.city_companion',
          ),
          if (_myLoc != null)
            CircleLayer(circles: [
              CircleMarker(
                point: _myLoc!,
                radius: _radiusKm * 1000,
                useRadiusInMeter: true,
                color: AppColors.orange.withValues(alpha: 0.06),
                borderColor: AppColors.orange.withValues(alpha: 0.3),
                borderStrokeWidth: 1.5,
              ),
            ]),
          MarkerLayer(markers: _markers),
          if (_myLoc != null)
            MarkerLayer(markers: [
              Marker(
                point: _myLoc!,
                width: 20, height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.35),
                        blurRadius: 8)],
                  ),
                ),
              ),
            ]),
        ],
      ),

      // Radius chips
      Positioned(
        top: pad.top + 10, left: 12, right: 12,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _RadiusChips(
            current: _radiusKm,
            onSelect: (r) {
              setState(() => _radiusKm = r);
              _fetchData();
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            _toggleChip('Plans', _showPlans, AppColors.orange, () {
              setState(() => _showPlans = !_showPlans);
              _buildMarkers();
            }),
            const SizedBox(width: 8),
            _toggleChip('Rooms 🏠', _showRooms, AppColors.blue, () {
              setState(() => _showRooms = !_showRooms);
              _buildMarkers();
            }),
          ]),
        ]),
      ),

      // Loading pill
      if (_loading)
        Positioned(
          top: pad.top + 95, left: 0, right: 0,
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(24)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(
                    color: AppColors.orange, strokeWidth: 2)),
              const SizedBox(width: 8),
              Text('Searching ${_radiusKm.toInt()} km...',
                style: const TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w500)),
            ]),
          )),
        ),

      // No activity card
      if (!_loading && _didFetch && !hasItems)
        Positioned(
          bottom: 72, left: 32, right: 32,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16)]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔭', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 6),
              const Text('No activity nearby',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 3),
              Text('within ${_radiusKm.toInt()} km',
                style: const TextStyle(color: AppColors.sub, fontSize: 12)),
              if (_radiusKm < 30) ...[
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: OutlinedButton(
                  onPressed: () {
                    setState(() => _radiusKm = 30);
                    _fetchData();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.orange),
                    foregroundColor: AppColors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                  child: const Text('Expand to 30 km'))),
              ],
            ]),
          ),
        ),

      // Bottom sheet with plans + rooms
      if (hasItems)
        DraggableScrollableSheet(
          initialChildSize: 0.28,
          minChildSize: 0.10,
          maxChildSize: 0.65,
          snap: true,
          snapSizes: const [0.10, 0.28, 0.65],
          builder: (_, ctrl) => _ResultsPanel(
            plans: _showPlans ? _plans : [],
            rooms: _showRooms ? _rooms : [],
            controller: ctrl,
            radiusKm: _radiusKm,
            loading: _loading,
            onPlanTap: (p) => context.push('/plan/details', extra: p),
            onRoomTap: _showRoomSheet,
            onRefresh: _loading ? null : _fetchData,
          ),
        ),

      // Zoom controls
      Positioned(
        right: 12,
        bottom: hasItems ? 264 : 90,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _zoomBtn(Icons.add, () => _zoom(1)),
          const SizedBox(height: 2),
          _zoomBtn(Icons.remove, () => _zoom(-1)),
        ]),
      ),

      // Recenter button
      Positioned(
        right: 12,
        bottom: hasItems ? 312 : 138,
        child: Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              if (_myLoc != null) _mapCtrl.move(_myLoc!, 14);
            },
            child: const SizedBox(width: 36, height: 36,
                child: Icon(Icons.my_location, size: 18, color: AppColors.ink)),
          ),
        ),
      ),
    ]);
  }

  Widget _toggleChip(String label, bool active, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : Colors.white24, width: 1.5),
        ),
        child: Text(label, style: TextStyle(
            color: active ? color : Colors.white,
            fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );

  Widget _zoomBtn(IconData icon, VoidCallback onTap) => Material(
    color: Colors.white,
    elevation: 2,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: SizedBox(width: 36, height: 36,
          child: Icon(icon, size: 18, color: AppColors.ink)),
    ),
  );
}

// ── Friends tab ───────────────────────────────────────────────────────────────

class _FriendsTab extends StatefulWidget {
  const _FriendsTab();
  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _sub;
  @override
  void initState() { super.initState(); _sub = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _sub.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: AppColors.card,
        child: TabBar(
          controller: _sub,
          labelColor: AppColors.orange,
          unselectedLabelColor: AppColors.sub,
          indicatorColor: AppColors.orange,
          tabs: const [Tab(text: 'My Friends'), Tab(text: 'Requests')],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _sub, children: const [
          _FriendListView(),
          _RequestsView(),
        ]),
      ),
    ]);
  }
}

// ── Friends list ──────────────────────────────────────────────────────────────

class _FriendListView extends StatefulWidget {
  const _FriendListView();
  @override
  State<_FriendListView> createState() => _FriendListViewState();
}

class _FriendListViewState extends State<_FriendListView> {
  List<dynamic> _friends = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final f = await ApiClient.getFriends();
      if (mounted) setState(() { _friends = f; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_friends.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Text('🤝', style: TextStyle(fontSize: 48)),
        SizedBox(height: 12),
        Text('No friends yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        SizedBox(height: 6),
        Text('Discover people nearby and connect!',
          style: TextStyle(color: AppColors.sub)),
      ]));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _FriendTile(friend: _friends[i], onUnfriend: _load),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final Map<String, dynamic> friend;
  final VoidCallback onUnfriend;
  const _FriendTile({required this.friend, required this.onUnfriend});

  @override
  Widget build(BuildContext context) {
    final name  = friend['name'] as String? ?? 'User';
    final photo = friend['profile_photo'] as String?;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(children: [
        _avatar(name, photo, 24),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          if ((friend['profession'] ?? '').isNotEmpty)
            Text(friend['profession'], style: const TextStyle(fontSize: 12, color: AppColors.sub)),
        ])),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'unfriend') {
              await ApiClient.unfriend(friend['id']);
              onUnfriend();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'unfriend', child: Text('Unfriend', style: TextStyle(color: AppColors.rose))),
          ],
          child: const Icon(Icons.more_vert, color: AppColors.muted),
        ),
      ]),
    );
  }
}

// ── Incoming requests ─────────────────────────────────────────────────────────

class _RequestsView extends StatefulWidget {
  const _RequestsView();
  @override
  State<_RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends State<_RequestsView> {
  List<dynamic> _requests = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await ApiClient.getFriendRequests();
      if (mounted) setState(() { _requests = r; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_requests.isEmpty) return const Center(
      child: Text('No pending requests', style: TextStyle(color: AppColors.sub)));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _RequestTile(request: _requests[i], onAction: _load),
      ),
    );
  }
}

class _RequestTile extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAction;
  const _RequestTile({required this.request, required this.onAction});
  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool _loading = false;

  Future<void> _act(bool accept) async {
    setState(() => _loading = true);
    try {
      final id = widget.request['id'] as String;
      if (accept) {
        await ApiClient.acceptFriendRequest(id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You and ${widget.request['requester_name']} are now friends!')));
      } else {
        await ApiClient.declineFriendRequest(id);
      }
      widget.onAction();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name  = widget.request['requester_name'] as String? ?? 'User';
    final prof  = widget.request['requester_profession'] as String? ?? '';
    final city  = widget.request['requester_city'] as String? ?? '';
    final photo = widget.request['requester_photo'] as String?;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _avatar(name, photo, 26),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (prof.isNotEmpty || city.isNotEmpty)
              Text('${prof.isNotEmpty ? prof : ''}${prof.isNotEmpty && city.isNotEmpty ? ' · ' : ''}${city}',
                style: const TextStyle(fontSize: 12, color: AppColors.sub)),
          ])),
        ]),
        const SizedBox(height: 12),
        _loading
          ? const Center(child: SizedBox(height: 32, width: 32,
              child: CircularProgressIndicator(strokeWidth: 2)))
          : Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => _act(false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.sub,
                  padding: const EdgeInsets.symmetric(vertical: 9)),
                child: const Text('Decline'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () => _act(true),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 9)),
                child: const Text('Accept'))),
            ]),
      ]),
    );
  }
}

// ── User card (Discover) with live friend status ───────────────────────────────

class _UserCard extends StatefulWidget {
  final Map<String, dynamic> user;
  const _UserCard({required this.user});
  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  // 'none' | 'pending_sent' | 'pending_received' | 'friends'
  String _status = 'none';
  bool _loading  = false;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final res = await ApiClient.getFriendStatus(widget.user['id'].toString());
      if (mounted) setState(() => _status = res['status'] as String? ?? 'none');
    } catch (_) {}
  }

  Future<void> _onConnect() async {
    if (_status == 'friends' || _status == 'pending_sent') return;
    setState(() => _loading = true);
    try {
      if (_status == 'pending_received') {
        // Accept the incoming request
        final res = await ApiClient.getFriendStatus(widget.user['id'].toString());
        final rid = res['request_id'] as String?;
        if (rid != null) await ApiClient.acceptFriendRequest(rid);
        setState(() => _status = 'friends');
      } else {
        await ApiClient.sendFriendRequest(widget.user['id'].toString());
        setState(() => _status = 'pending_sent');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['name'] as String? ?? 'User';
    final photo = widget.user['profile_photo'] as String?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _avatar(name, photo, 26),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(
              '${widget.user['profession'] ?? ''}'
              '${(widget.user['profession'] ?? '').isNotEmpty && (widget.user['hometown'] ?? '').isNotEmpty ? ' · ' : ''}'
              '${widget.user['hometown'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.sub)),
          ])),
          Text('📍 ${widget.user['distance_km'] ?? '?'} km',
            style: const TextStyle(fontSize: 12, color: AppColors.sub)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              side: const BorderSide(color: AppColors.border)),
            child: const Text('💬 Message'))),
          const SizedBox(width: 10),
          Expanded(child: _connectButton()),
        ]),
      ]),
    );
  }

  Widget _connectButton() {
    if (_loading) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
        child: const SizedBox(height: 18, width: 18,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)));
    }
    switch (_status) {
      case 'friends':
        return ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            padding: const EdgeInsets.symmetric(vertical: 8)),
          child: const Text('✅ Friends'));
      case 'pending_sent':
        return ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.muted,
            padding: const EdgeInsets.symmetric(vertical: 8)),
          child: const Text('⏳ Pending'));
      case 'pending_received':
        return ElevatedButton(
          onPressed: _onConnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue,
            padding: const EdgeInsets.symmetric(vertical: 8)),
          child: const Text('Accept'));
      default:
        return ElevatedButton(
          onPressed: _onConnect,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
          child: const Text('🤝 Connect'));
    }
  }
}

// ── Radius chips ──────────────────────────────────────────────────────────────

class _RadiusChips extends StatelessWidget {
  final double current;
  final void Function(double) onSelect;

  static const _opts = [3.0, 5.0, 10.0, 30.0];
  const _RadiusChips({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: _opts.map((r) {
        final active = r == current;
        return GestureDetector(
          onTap: () => onSelect(r),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: active ? AppColors.orange : Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
              border: active ? null : Border.all(color: Colors.white24),
            ),
            child: Text('${r.toInt()} km', style: TextStyle(
                color: Colors.white, fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
          ),
        );
      }).toList(),
    );
  }
}

// ── Results bottom panel (plans + rooms) ─────────────────────────────────────

class _ResultsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> plans;
  final List<Map<String, dynamic>> rooms;
  final ScrollController controller;
  final double radiusKm;
  final bool loading;
  final void Function(Map<String, dynamic>) onPlanTap;
  final void Function(Map<String, dynamic>) onRoomTap;
  final VoidCallback? onRefresh;

  const _ResultsPanel({
    required this.plans, required this.rooms, required this.controller,
    required this.radiusKm, required this.loading,
    required this.onPlanTap, required this.onRoomTap, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final total = plans.length + rooms.length;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16,
            offset: Offset(0, -2))],
      ),
      child: Column(children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.fromLTRB(0, 10, 0, 8),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('$total nearby',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
              child: Text('within ${radiusKm.toInt()} km',
                style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            if (onRefresh != null)
              GestureDetector(
                onTap: onRefresh,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.orange),
                    borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh, color: AppColors.orange, size: 13),
                    SizedBox(width: 4),
                    Text('Refresh',
                      style: TextStyle(color: AppColors.orange, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(child: ListView.separated(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          itemCount: total,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i < plans.length) {
              return _PlanBottomCard(
                plan: plans[i], onTap: () => onPlanTap(plans[i]));
            }
            final room = rooms[i - plans.length];
            return _RoomBottomCard(room: room, onTap: () => onRoomTap(room));
          },
        )),
      ]),
    );
  }
}

class _PlanBottomCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onTap;
  const _PlanBottomCard({required this.plan, required this.onTap});

  static const _emoji = {
    'food': '🍔', 'play': '🎮', 'gym': '💪', 'ride': '🚗',
    'hangout': '☕', 'trek': '🥾', 'party': '🎉', 'music': '🎵',
  };

  @override
  Widget build(BuildContext context) {
    final cat   = plan['category'] as String? ?? '';
    final title = plan['title']   as String? ?? 'Plan';
    final host  = plan['host_name'] as String? ?? '';
    final dist  = (plan['distance_km'] as num?)?.toDouble() ?? 0.0;
    final em    = _emoji[cat.toLowerCase()] ?? '📍';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1.5)),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10)),
            child: Center(
                child: Text(em, style: const TextStyle(fontSize: 22)))),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('by $host',
              style: const TextStyle(color: AppColors.sub, fontSize: 11)),
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20)),
            child: Text('${dist.toStringAsFixed(1)} km',
              style: const TextStyle(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        ]),
      ),
    );
  }
}

class _RoomBottomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;
  const _RoomBottomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = room['title'] as String? ?? 'Room';
    final rent  = room['rent_inr'] as int? ?? 0;
    final area  = room['area'] as String? ?? '';
    final city  = room['city'] as String? ?? '';
    final dist  = (room['distance_km'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1.5)),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10)),
            child: const Center(
                child: Text('🏠', style: TextStyle(fontSize: 22)))),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('₹$rent/mo · $area${city.isNotEmpty ? ', $city' : ''}',
              style: const TextStyle(color: AppColors.sub, fontSize: 11)),
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20)),
            child: Text('${dist.toStringAsFixed(1)} km',
              style: const TextStyle(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        ]),
      ),
    );
  }
}

// ── Shared avatar widget ──────────────────────────────────────────────────────

Widget _avatar(String name, String? photo, double radius) {
  if (photo != null && photo.isNotEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: CachedNetworkImageProvider(ApiClient.photoUrl(photo)),
      backgroundColor: AppColors.orange,
    );
  }
  return CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.orange,
    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: radius * 0.77)),
  );
}
