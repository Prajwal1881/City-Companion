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

// ── Radar map tab ─────────────────────────────────────────────────────────────

class _RadarMapTab extends StatefulWidget {
  const _RadarMapTab();
  @override
  State<_RadarMapTab> createState() => _RadarMapTabState();
}

class _RadarMapTabState extends State<_RadarMapTab>
    with TickerProviderStateMixin {

  static const _allSteps  = [1.0, 3.0, 5.0, 10.0, 30.0];
  static const _stepMs    = 7000; // 7 s per ring (user-requested)
  static const _autoSecs  = 15;   // auto-refresh after full scan
  static final _fallback  = ll.LatLng(12.9716, 77.5946);

  ll.LatLng? _myLoc;
  List<Map<String, dynamic>> _plans     = [];
  double  _radiusKm   = 10.0;
  double? _customKm;
  bool    _scanning   = false;
  bool    _didScan    = false;
  int     _scanStep   = -1;
  int     _countdown  = 0;
  String? _stepBanner;   // brief "✓ 1km · 2 plans → 3km" between steps

  Timer? _countdownTimer;

  final _mapCtrl = MapController();
  List<CircleMarker> _circles = [];
  List<Marker>       _markers = [];

  late final AnimationController _sweepCtrl;
  late final AnimationController _pingCtrl;
  late final Animation<double>   _pingAnim;

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _pingCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _pingAnim = CurvedAnimation(parent: _pingCtrl, curve: Curves.easeOut);
    _init();
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    _pingCtrl.dispose();
    _mapCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── location ──────────────────────────────────────────────────────────────

  Future<void> _init() async {
    await _acquireLocation();
    if (mounted) _startScan();
  }

  Future<void> _acquireLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _myLoc = _fallback);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        setState(() => _myLoc = ll.LatLng(pos.latitude, pos.longitude));
        _mapCtrl.move(_myLoc!, 13);
      }
    } catch (_) {
      if (mounted) setState(() => _myLoc = _fallback);
    }
  }

  // ── scan logic ────────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    if (_scanning || _myLoc == null) return;
    _countdownTimer?.cancel();
    if (mounted) setState(() => _countdown = 0);

    final steps = _allSteps.where((r) => r <= _radiusKm).toList();

    if (mounted) setState(() {
      _scanning = true; _didScan = true; _scanStep = 0;
      _plans = []; _markers = []; _circles = [];
    });

    for (int i = 0; i < steps.length; i++) {
      if (!mounted) return;
      setState(() {
        _scanStep    = i;
        _stepBanner  = null;
        _circles     = _buildCircles(i, steps);
      });
      _pingCtrl.forward(from: 0);

      // Guarantee 7-second minimum per step
      final t0 = DateTime.now().millisecondsSinceEpoch;
      try {
        final found = await ApiClient.getNearbyPlans(
          lat: _myLoc!.latitude, lng: _myLoc!.longitude,
          radiusKm: steps[i]);
        if (mounted) _mergePlans(found);
      } catch (_) {}

      // Fill remaining time up to _stepMs
      final elapsed   = DateTime.now().millisecondsSinceEpoch - t0;
      final remaining = _stepMs - elapsed;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }

      // Brief banner before moving to next ring
      if (i < steps.length - 1 && mounted) {
        final count = _plans.length;
        final next  = steps[i + 1];
        setState(() => _stepBanner =
            '✓ ${steps[i].toInt()} km · $count plan${count == 1 ? '' : 's'} · scanning ${next.toInt()} km…');
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) setState(() => _stepBanner = null);
      }
    }

    if (mounted) {
      setState(() { _scanning = false; _scanStep = -1; _stepBanner = null; });
      _scheduleAutoRefresh();
    }
  }

  // Zoom map in / out by [delta] levels
  void _zoom(double delta) {
    try {
      final cam = _mapCtrl.camera;
      _mapCtrl.move(cam.center, (cam.zoom + delta).clamp(3.0, 19.0));
    } catch (_) {}
  }

  // Auto-rescan every _autoSecs seconds with visible countdown
  void _scheduleAutoRefresh() {
    if (!mounted) return;
    setState(() => _countdown = _autoSecs);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown = (_countdown - 1).clamp(0, _autoSecs));
      if (_countdown <= 0) {
        t.cancel();
        if (mounted && !_scanning) _startScan();
      }
    });
  }

  // Tap the radar → pick a specific distance or set custom km
  void _showRadarMenu() {
    _countdownTimer?.cancel();
    if (mounted) setState(() => _countdown = 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const Text('Scan Range',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          // Preset options
          ...[1.0, 3.0, 5.0, 10.0, 30.0].map((r) => ListTile(
            dense: true,
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: r == _radiusKm
                    ? AppColors.orange.withValues(alpha: 0.12)
                    : AppColors.bg,
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text('${r.toInt()}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: r == _radiusKm ? AppColors.orange : AppColors.ink)))),
            title: Text('${r.toInt()} km',
              style: TextStyle(
                color: r == _radiusKm ? AppColors.orange : AppColors.ink,
                fontWeight: r == _radiusKm ? FontWeight.w700 : FontWeight.w400)),
            trailing: r == _radiusKm
                ? const Icon(Icons.check_circle, color: AppColors.orange, size: 20)
                : null,
            onTap: () {
              Navigator.pop(ctx);
              setState(() { _radiusKm = r; _customKm = null; });
              _startScan();
            },
          )),
          // Custom option
          ListTile(
            dense: true,
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _customKm != null
                    ? AppColors.orange.withValues(alpha: 0.12)
                    : AppColors.bg,
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.tune, color: AppColors.orange, size: 18)),
            title: Text(
              _customKm != null
                  ? 'Custom: ${_customKm!.round()} km'
                  : 'Custom distance…',
              style: const TextStyle(
                  color: AppColors.orange, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              _showCustomKmSheet();
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // Slider-based custom km picker
  void _showCustomKmSheet() {
    double tempKm = _customKm ?? _radiusKm;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Row(children: [
              const Text('Custom Range',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${tempKm.round()} km',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ]),
            const SizedBox(height: 20),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.orange,
                thumbColor: AppColors.orange,
                overlayColor: AppColors.orange.withValues(alpha: 0.1),
                inactiveTrackColor: AppColors.border,
                trackHeight: 3,
              ),
              child: Slider(
                value: tempKm,
                min: 1, max: 50,
                divisions: 49,
                onChanged: (v) => setSheet(() => tempKm = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['1 km', '10', '20', '30', '50 km']
                    .map((l) => Text(l,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 10)))
                    .toList()),
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() { _radiusKm = tempKm; _customKm = tempKm; });
                _startScan();
              },
              child: Text('Search ${tempKm.round()} km',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            )),
          ]),
        ),
      ),
    );
  }

  void _mergePlans(List<Map<String, dynamic>> incoming) {
    final seen = _plans.map((p) => p['id'].toString()).toSet();
    for (final p in incoming) {
      if (seen.add(p['id'].toString())) {
        _plans.add(p);
        _addMarker(p);
      }
    }
    setState(() {});
  }

  void _addMarker(Map<String, dynamic> plan) {
    final lat  = (plan['latitude']  as num?)?.toDouble();
    final lng  = (plan['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    final em   = _catEmoji(plan['category'] as String? ?? '');
    final dist = (plan['distance_km'] as num?)?.toStringAsFixed(1) ?? '?';

    setState(() => _markers = [
      ..._markers,
      Marker(
        point: ll.LatLng(lat, lng),
        width: 44, height: 44,
        child: GestureDetector(
          onTap: () => _openPlan(plan),
          child: Tooltip(
            message: '${plan['title']} · $dist km',
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
      ),
    ]);
  }

  List<CircleMarker> _buildCircles(int activeIdx, List<double> steps) {
    const colors = [
      AppColors.orange, AppColors.blue, AppColors.teal,
      AppColors.violet, AppColors.green,
    ];
    return [
      for (int i = 0; i <= activeIdx && i < steps.length; i++)
        CircleMarker(
          point: _myLoc!,
          radius: steps[i] * 1000,
          useRadiusInMeter: true,
          color: colors[i % colors.length]
              .withValues(alpha: i == activeIdx ? 0.07 : 0.02),
          borderColor: colors[i % colors.length]
              .withValues(alpha: i == activeIdx ? 0.85 : 0.30),
          borderStrokeWidth: i == activeIdx ? 2 : 1,
        ),
    ];
  }

  void _openPlan(Map<String, dynamic> plan) =>
      context.push('/plan/details', extra: plan);

  static String _catEmoji(String cat) {
    const m = {
      'food': '🍔', 'play': '🎮', 'gym': '💪', 'ride': '🚗',
      'hangout': '☕', 'trek': '🥾', 'party': '🎉', 'music': '🎵',
    };
    return m[cat.toLowerCase()] ?? '📍';
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pad         = MediaQuery.of(context).padding;
    final target      = _myLoc ?? _fallback;
    final activeSteps = _allSteps.where((r) => r <= _radiusKm).toList();

    return Stack(children: [

      // ── 1. OpenStreetMap (flutter_map — no API key, all platforms) ───────
      FlutterMap(
        mapController: _mapCtrl,
        options: MapOptions(initialCenter: target, initialZoom: 13),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.syntra.city_companion',
          ),
          CircleLayer(circles: _circles),
          MarkerLayer(markers: _markers),
          // My-location blue dot
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

      // ── 2. Radius chips (top-left) ──────────────────────────────────────
      Positioned(
        top: pad.top + 10, left: 12,
        child: _RadiusChips(
          current: _radiusKm,
          customKm: _customKm,
          onSelect: (r) {
            setState(() { _radiusKm = r; _customKm = null; });
            _startScan();
          },
          onCustom: _showCustomKmSheet,
        ),
      ),

      // ── 3. Radar widget (top-right) — tap to open range picker ──────────
      Positioned(
        top: pad.top + 10, right: 12,
        child: GestureDetector(
          onTap: _showRadarMenu,
          child: _RadarWidget(
            sweep: _sweepCtrl,
            ping: _pingAnim,
            scanning: _scanning,
            step: _scanStep,
            steps: activeSteps,
            countdown: _countdown,
          ),
        ),
      ),

      // ── 4. Scanning status pill ─────────────────────────────────────────
      if (_scanning || _stepBanner != null)
        Positioned(
          bottom: _plans.isNotEmpty ? 268 : 80,
          left: 16, right: 16,
          child: Center(child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(_stepBanner ?? (_scanStep.toString())),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: _stepBanner != null
                    ? AppColors.orange.withValues(alpha: 0.92)
                    : Colors.black.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(24)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_stepBanner != null)
                  const Icon(Icons.check_circle_outline,
                      color: Colors.white, size: 15)
                else
                  const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(
                        color: AppColors.orange, strokeWidth: 2)),
                const SizedBox(width: 8),
                Flexible(child: Text(
                  _stepBanner ??
                    (_scanStep >= 0 && _scanStep < activeSteps.length
                      ? 'Scanning ${activeSteps[_scanStep].toInt()} km…'
                      : 'Scanning…'),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
              ]),
            ),
          )),
        ),

      // ── 5. No-plans result card ─────────────────────────────────────────
      if (!_scanning && _didScan && _plans.isEmpty)
        Positioned(
          bottom: 72, left: 32, right: 32,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 16)]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔭', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 6),
              const Text('No plans found nearby',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 3),
              Text('within ${_radiusKm.toInt()} km',
                style: const TextStyle(color: AppColors.sub, fontSize: 12)),
              if (_radiusKm < 30) ...[
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: OutlinedButton(
                  onPressed: () {
                    setState(() => _radiusKm = 30);
                    _startScan();
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

      // ── 6. Plans bottom sheet ───────────────────────────────────────────
      if (_plans.isNotEmpty)
        DraggableScrollableSheet(
          initialChildSize: 0.28,
          minChildSize: 0.10,
          maxChildSize: 0.65,
          snap: true,
          snapSizes: const [0.10, 0.28, 0.65],
          builder: (_, ctrl) => _PlansPanel(
            plans: _plans,
            controller: ctrl,
            radiusKm: _radiusKm,
            scanning: _scanning,
            onTap: _openPlan,
            onRescan: _scanning ? null : _startScan,
          ),
        ),

      // ── 7. Zoom controls ────────────────────────────────────────────────
      Positioned(
        right: 12,
        bottom: _plans.isNotEmpty ? 264 : 90,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _zoomBtn(Icons.add,    () => _zoom(1)),
          const SizedBox(height: 2),
          _zoomBtn(Icons.remove, () => _zoom(-1)),
        ]),
      ),
    ]);
  }

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
  final double? customKm;
  final void Function(double) onSelect;
  final VoidCallback onCustom;

  static const _opts = [1.0, 3.0, 5.0, 10.0, 30.0];
  const _RadiusChips({
    required this.current, required this.onSelect,
    required this.onCustom, this.customKm,
  });

  @override
  Widget build(BuildContext context) {
    final isCustomActive = customKm != null && !_opts.contains(current);
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: [
        ..._opts.map((r) {
          final active = r == current && !isCustomActive;
          return GestureDetector(
            onTap: () => onSelect(r),
            child: _chip(
              label: '${r.toInt()} km',
              active: active,
            ),
          );
        }),
        // Custom km chip
        GestureDetector(
          onTap: onCustom,
          child: _chip(
            label: isCustomActive ? '${current.round()} km ✏' : '+ km',
            active: isCustomActive,
            icon: isCustomActive ? null : Icons.tune,
          ),
        ),
      ],
    );
  }

  Widget _chip({required String label, required bool active, IconData? icon}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.orange : Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: active ? null : Border.all(color: Colors.white24),
      ),
      child: icon != null
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.white, size: 11),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(
                  color: Colors.white, fontSize: 11)),
            ])
          : Text(label, style: TextStyle(
              color: Colors.white, fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
    );
}

// ── Radar widget ──────────────────────────────────────────────────────────────

class _RadarWidget extends StatelessWidget {
  final Animation<double> sweep;
  final Animation<double> ping;
  final bool scanning;
  final int  step;
  final List<double> steps;
  final int  countdown;

  const _RadarWidget({
    required this.sweep, required this.ping,
    required this.scanning, required this.step,
    required this.steps, required this.countdown,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([sweep, ping]),
      builder: (_, __) => Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scanning
                ? AppColors.orange.withOpacity(0.5)
                : Colors.white12,
            width: scanning ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(alignment: Alignment.bottomCenter, children: [
            CustomPaint(
              size: const Size(90, 90),
              painter: _RadarPainter(
                sweepValue: sweep.value,
                pingValue:  ping.value,
                scanning:   scanning,
                countdown:  countdown,
                step:       step,
                totalSteps: steps.length,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                scanning && step >= 0 && step < steps.length
                    ? '${steps[step].toInt()} km'
                    : scanning
                        ? '…'
                        : countdown > 0
                            ? '${countdown}s'
                            : 'TAP',
                style: TextStyle(
                  color: scanning
                      ? AppColors.orange
                      : countdown > 0
                          ? Colors.white54
                          : Colors.white38,
                  fontSize: 9, fontWeight: FontWeight.w700,
                  letterSpacing: 0.8),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double sweepValue;
  final double pingValue;
  final bool   scanning;
  final int    countdown;
  final int    step;
  final int    totalSteps;

  const _RadarPainter({
    required this.sweepValue, required this.pingValue,
    required this.scanning,  required this.countdown,
    required this.step,      required this.totalSteps,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final maxR   = math.min(cx, cy) - 4;

    // Grid rings
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxR * i / 4, Paint()
        ..color = Colors.white.withOpacity(i == 4 ? 0.18 : 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5);
    }
    // Cross hairs
    for (final pts in [
      [Offset(cx - maxR, cy), Offset(cx + maxR, cy)],
      [Offset(cx, cy - maxR), Offset(cx, cy + maxR)],
    ]) {
      canvas.drawLine(pts[0], pts[1],
          Paint()..color = Colors.white.withOpacity(0.07)..strokeWidth = 0.5);
    }

    final angle = sweepValue * 2 * math.pi - math.pi / 2;

    if (scanning) {
      // Active sweep — bright orange trail
      const trail = math.pi * 0.65;
      const slices = 10;
      final rect = Rect.fromCircle(center: center, radius: maxR);
      for (int i = 0; i < slices; i++) {
        final frac = (i + 1) / slices;
        canvas.drawArc(
          rect,
          angle - trail + trail * i / slices,
          trail / slices,
          true,
          Paint()
            ..color = AppColors.orange.withValues(alpha: 0.38 * frac)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawLine(
        center,
        Offset(cx + maxR * math.cos(angle), cy + maxR * math.sin(angle)),
        Paint()..color = AppColors.orange..strokeWidth = 1.5,
      );
    } else if (countdown > 0) {
      // Ghost sweep while counting down — dim line only
      canvas.drawLine(
        center,
        Offset(cx + maxR * math.cos(angle), cy + maxR * math.sin(angle)),
        Paint()..color = Colors.white.withValues(alpha: 0.12)..strokeWidth = 0.8,
      );
    }

    // Ping ring when step advances
    if (pingValue > 0 && step >= 0 && totalSteps > 0) {
      final pingR = maxR * ((step + 1) / totalSteps) * pingValue;
      canvas.drawCircle(center, pingR, Paint()
        ..color = AppColors.orange.withValues(alpha: (1.0 - pingValue) * 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0);
    }

    // Center dot
    canvas.drawCircle(center, 3,
        Paint()..color = scanning ? AppColors.orange : Colors.white54);
  }

  @override
  bool shouldRepaint(_RadarPainter o) =>
      o.sweepValue != sweepValue || o.pingValue != pingValue ||
      o.scanning != scanning    || o.countdown != countdown || o.step != step;
}

// ── Plans bottom panel ────────────────────────────────────────────────────────

class _PlansPanel extends StatelessWidget {
  final List<Map<String, dynamic>> plans;
  final ScrollController controller;
  final double radiusKm;
  final bool scanning;
  final void Function(Map<String, dynamic>) onTap;
  final VoidCallback? onRescan;

  const _PlansPanel({
    required this.plans, required this.controller,
    required this.radiusKm, required this.scanning,
    required this.onTap, required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16,
            offset: Offset(0, -2))],
      ),
      child: Column(children: [
        // Handle
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.fromLTRB(0, 10, 0, 8),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2))),
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('${plans.length} plans',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
              child: Text('within ${radiusKm.toInt()} km',
                style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            if (onRescan != null)
              GestureDetector(
                onTap: onRescan,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.orange),
                    borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.radar, color: AppColors.orange, size: 13),
                    SizedBox(width: 4),
                    Text('Rescan',
                      style: TextStyle(
                          color: AppColors.orange, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        // List
        Expanded(child: ListView.separated(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          itemCount: plans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _PlanBottomCard(
            plan: plans[i], onTap: () => onTap(plans[i])),
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
              color: AppColors.orange.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10)),
            child: Center(
                child: Text(em, style: const TextStyle(fontSize: 22)))),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('by $host',
              style: const TextStyle(color: AppColors.sub, fontSize: 11)),
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.10),
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
