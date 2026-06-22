import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../core/theme.dart';
import '../services/api_client.dart';

/// Opens a full-screen map where the user can search for a nearby area, then
/// drag the map to place a centre pin precisely and confirm. Returns the chosen
/// [ll.LatLng], or null if cancelled.
///
/// Uses free OpenStreetMap tiles + the app's free autocomplete — no API key.
/// The in-map search lets users handle places OSM can't name (e.g. a small
/// business): search the nearest landmark, then drop the pin on the exact spot.
Future<ll.LatLng?> showLocationPicker(
  BuildContext context, {
  ll.LatLng? initial,
  String? initialQuery,
  String title = 'Set exact location',
}) {
  return showModalBottomSheet<ll.LatLng>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LocationPickerSheet(
        initial: initial, initialQuery: initialQuery, title: title),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  final ll.LatLng? initial;
  final String? initialQuery;
  final String title;
  const _LocationPickerSheet(
      {required this.initial, this.initialQuery, required this.title});

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  static const _fallback = ll.LatLng(12.9716, 77.5946); // Bengaluru
  final _mapCtrl = MapController();
  late ll.LatLng _center;
  bool _locating = false;

  // In-map search
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;
  List<Map<String, dynamic>> _suggestions = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _center = widget.initial ?? _fallback;
    // Carry over the query the user already typed so they can keep searching
    // on the map (helpful when text-only geocoding missed the exact place).
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      _searchCtrl.text = q;
      _onSearchChanged(q);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _requestId++;
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      return;
    }
    final requestId = _requestId;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _searching = true);
      try {
        final results = await ApiClient.locationAutocomplete(query);
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _suggestions = results;
          _searching = false;
        });
      } on DioException {
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _suggestions = [];
          _searching = false;
        });
      } catch (_) {
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _suggestions = [];
          _searching = false;
        });
      }
    });
  }

  void _selectSuggestion(Map<String, dynamic> item) {
    final lat = (item['lat'] as num?)?.toDouble();
    final lng = (item['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    final target = ll.LatLng(lat, lng);
    FocusScope.of(context).unfocus();
    setState(() {
      _center = target;
      _suggestions = [];
      _searchCtrl.text = item['description']?.toString() ?? '';
    });
    _mapCtrl.move(target, 16);
  }

  Widget _mapButton({required Widget child, required VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: child),
      ),
    );
  }

  void _zoom(double delta) {
    try {
      final cam = _mapCtrl.camera;
      _mapCtrl.move(cam.center, (cam.zoom + delta).clamp(3.0, 19.0));
    } catch (_) {}
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      final here = ll.LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _center = here);
        _mapCtrl.move(here, 16);
      }
    } catch (_) {
      // best-effort — keep current centre
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = widget.initial ?? _fallback;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      expand: false,
      builder: (_, __) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(children: [
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.sub),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search area or landmark',
                  hintStyle:
                      const TextStyle(color: AppColors.muted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.muted, size: 20),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.orange)))
                      : _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: AppColors.muted, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                ),
              ),
            ),
          ),

          Expanded(
            child: Stack(children: [
              FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: 15,
                  onPositionChanged: (camera, _) => _center = camera.center,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.syntra.city_companion',
                  ),
                ],
              ),

              // Fixed centre pin — sits slightly above true centre so the tip
              // points at the map centre.
              IgnorePointer(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -18),
                    child: const Icon(Icons.location_on,
                        size: 44, color: AppColors.orange),
                  ),
                ),
              ),

              // Search suggestions dropdown
              if (_suggestions.isNotEmpty)
                Positioned(
                  top: 0,
                  left: 12,
                  right: 12,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 12)
                      ],
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (_, i) {
                        final item = _suggestions[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined,
                              size: 18, color: AppColors.orange),
                          title: Text(
                            item['description']?.toString() ?? '',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          onTap: () => _selectSuggestion(item),
                        );
                      },
                    ),
                  ),
                ),

              // Hint pill (hidden while showing suggestions)
              if (_suggestions.isEmpty)
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Drag the map to position the pin',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),

              // Right-side controls: zoom + use-my-location
              Positioned(
                right: 14,
                bottom: 14,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _mapButton(
                    child: const Icon(Icons.add, size: 22, color: AppColors.ink),
                    onTap: () => _zoom(1),
                  ),
                  const SizedBox(height: 8),
                  _mapButton(
                    child:
                        const Icon(Icons.remove, size: 22, color: AppColors.ink),
                    onTap: () => _zoom(-1),
                  ),
                  const SizedBox(height: 16),
                  _mapButton(
                    onTap: _locating ? null : _useMyLocation,
                    child: _locating
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.orange))
                        : const Icon(Icons.my_location,
                            size: 20, color: AppColors.ink),
                  ),
                ]),
              ),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _center),
                  child: const Text('Confirm location',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
