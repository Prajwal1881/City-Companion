import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../widgets/city_field.dart';
import '../../widgets/location_picker.dart';

class RoomFormScreen extends StatefulWidget {
  final Map<String, dynamic>? room;
  const RoomFormScreen({super.key, this.room});

  @override
  State<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends State<RoomFormScreen> {
  final _title       = TextEditingController();
  final _description = TextEditingController();
  final _area        = TextEditingController();
  final _city        = TextEditingController();
  final _rent        = TextEditingController();

  String _roomType   = 'shared';
  String _genderPref = 'any';
  bool _furnished    = false;
  bool _smoking      = false;
  DateTime? _availableFrom;
  bool _loading      = false;
  double? _latitude;
  double? _longitude;

  Timer? _areaDebounce;
  bool _locationConfirmed = false;
  bool _locationSearching = false;

  // Photos — existing (from backend) and newly picked
  List<Map<String, String>> _existingPhotos = []; // {id, url}
  List<_PickedPhoto>        _newPhotos      = [];

  bool get _isEdit => widget.room != null;
  int  get _totalPhotos => _existingPhotos.length + _newPhotos.length;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final r = widget.room!;
      _title.text       = r['title'] ?? '';
      _description.text = r['description'] ?? '';
      _area.text        = r['area'] ?? '';
      _city.text        = r['city'] ?? '';
      _rent.text        = (r['rent_inr'] ?? '').toString();
      _roomType         = r['room_type'] ?? 'shared';
      _genderPref       = r['gender_pref'] ?? 'any';
      _furnished        = r['is_furnished'] ?? false;
      _smoking          = r['smoking_allowed'] ?? false;
      if (r['available_from'] != null) {
        _availableFrom = DateTime.tryParse(r['available_from'].toString());
      }
      _latitude  = (r['latitude']  as num?)?.toDouble();
      _longitude = (r['longitude'] as num?)?.toDouble();
      if (_latitude != null && _longitude != null) _locationConfirmed = true;
      // Load existing photos
      final photos = r['photos'] as List<dynamic>? ?? [];
      _existingPhotos = photos.map((p) => {
        'id':  p['id']?.toString() ?? '',
        'url': p['url']?.toString() ?? '',
      }).toList();
    }
  }

  @override
  void dispose() {
    _areaDebounce?.cancel();
    _title.dispose(); _description.dispose(); _area.dispose();
    _city.dispose(); _rent.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_totalPhotos >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 photos per room')));
      return;
    }
    final remaining = 6 - _totalPhotos;
    final xfiles = await ImagePicker().pickMultiImage(
      imageQuality: 80, maxWidth: 1200, limit: remaining);
    if (xfiles.isEmpty) return;
    for (final xf in xfiles) {
      final bytes = await xf.readAsBytes();
      final ext   = xf.name.contains('.') ? xf.name.split('.').last.toLowerCase() : 'jpg';
      setState(() => _newPhotos.add(_PickedPhoto(bytes: bytes, ext: ext)));
    }
  }

  Future<void> _removeExisting(String photoId, String roomId) async {
    try {
      await ApiClient.deleteRoomPhoto(roomId, photoId);
      setState(() => _existingPhotos.removeWhere((p) => p['id'] == photoId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete photo: $e')));
    }
  }

  // Geocodes while typing — updates _latitude/_longitude and shows confirmation.
  // Works for all Indian cities regardless of OSM suburb coverage.
  Future<void> _geocodeAsYouType(String area) async {
    if (area.trim().length < 3) {
      if (mounted) setState(() {
        _locationConfirmed = false;
        _locationSearching = false;
        _latitude  = null;
        _longitude = null;
      });
      return;
    }
    if (mounted) setState(() { _locationSearching = true; _locationConfirmed = false; });
    final city  = _city.text.trim();
    final query = city.isNotEmpty ? '$area, $city, India' : '$area, India';
    try {
      final res = await Dio().get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'q': query, 'format': 'json', 'limit': 1},
        options: Options(headers: {'User-Agent': 'CityCompanionApp/1.0'}),
      );
      final results = res.data as List<dynamic>;
      if (!mounted) return;
      if (results.isNotEmpty) {
        _latitude  = double.tryParse(results[0]['lat'].toString());
        _longitude = double.tryParse(results[0]['lon'].toString());
        setState(() { _locationConfirmed = true; _locationSearching = false; });
      } else {
        setState(() { _locationConfirmed = false; _locationSearching = false;
          _latitude = null; _longitude = null; });
      }
    } catch (_) {
      if (mounted) setState(() { _locationConfirmed = false; _locationSearching = false; });
    }
  }

  // Geocodes "Area, City, India" via Nominatim — sets _latitude/_longitude silently.
  Future<void> _geocodeAddress() async {
    final query = '${_area.text.trim()}, ${_city.text.trim()}, India';
    try {
      final dio = Dio();
      final res = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'q': query, 'format': 'json', 'limit': 1},
        options: Options(headers: {'User-Agent': 'CityCompanionApp/1.0'}),
      );
      final results = res.data as List<dynamic>;
      if (results.isNotEmpty) {
        _latitude  = double.tryParse(results[0]['lat'].toString());
        _longitude = double.tryParse(results[0]['lon'].toString());
      }
    } catch (_) {
      // Geocoding is best-effort — proceed without coordinates if it fails
    }
  }

  // Opens the map pin picker, seeding it with the best location we have so far.
  Future<void> _openMapPicker() async {
    ll.LatLng? start;
    if (_latitude != null && _longitude != null) {
      start = ll.LatLng(_latitude!, _longitude!);
    } else if (_area.text.trim().length >= 3) {
      await _geocodeAddress();
      if (_latitude != null && _longitude != null) {
        start = ll.LatLng(_latitude!, _longitude!);
      }
    }
    if (!mounted) return;
    final areaQuery = [_area.text.trim(), _city.text.trim()]
        .where((s) => s.isNotEmpty)
        .join(', ');
    final picked = await showLocationPicker(
      context,
      initial: start,
      initialQuery: areaQuery,
    );
    if (picked != null && mounted) {
      setState(() {
        _latitude = picked.latitude;
        _longitude = picked.longitude;
        _locationConfirmed = true;
        _locationSearching = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _area.text.trim().isEmpty ||
        _city.text.trim().isEmpty || _rent.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')));
      return;
    }
    setState(() => _loading = true);
    try {
      // Use confirmed coordinates; fall back to Nominatim if user skipped autocomplete
      if (!_locationConfirmed) await _geocodeAddress();

      // Exact coordinates are required so the room appears on the Discover map.
      if (_latitude == null || _longitude == null) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Set the room location on the map first')));
        return;
      }

      final data = {
        'title':           _title.text.trim(),
        'description':     _description.text.trim().isEmpty ? null : _description.text.trim(),
        'area':            _area.text.trim(),
        'city':            _city.text.trim(),
        'rent_inr':        int.parse(_rent.text.trim()),
        'room_type':       _roomType,
        'gender_pref':     _genderPref,
        'is_furnished':    _furnished,
        'smoking_allowed': _smoking,
        'available_from':  _availableFrom?.toIso8601String(),
        'latitude':        _latitude,
        'longitude':       _longitude,
      };

      Map<String, dynamic> result;
      if (_isEdit) {
        result = await ApiClient.updateRoom(widget.room!['id'].toString(), data);
      } else {
        result = await ApiClient.createRoom(data);
      }

      // Upload new photos
      final roomId = result['id'].toString();
      for (final photo in _newPhotos) {
        await ApiClient.uploadRoomPhoto(roomId, photo.bytes, 'photo.${photo.ext}');
      }

      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableFrom ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _availableFrom = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Listing' : 'Post a Room'),
        backgroundColor: AppColors.card,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Photos section ──────────────────────────────────────────────
          _section('Photos'),
          Text('Add up to 6 photos · $_totalPhotos/6',
            style: const TextStyle(fontSize: 12, color: AppColors.sub)),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Existing photos (edit mode)
                ..._existingPhotos.map((p) => _photoThumb(
                  child: CachedNetworkImage(
                    imageUrl: ApiClient.photoUrl(p['url']!),
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image, color: AppColors.muted)),
                  onRemove: _isEdit
                      ? () => _removeExisting(p['id']!, widget.room!['id'].toString())
                      : null,
                )),

                // New (picked) photos
                ..._newPhotos.asMap().entries.map((e) => _photoThumb(
                  child: Image.memory(e.value.bytes, fit: BoxFit.cover),
                  onRemove: () => setState(() => _newPhotos.removeAt(e.key)),
                )),

                // Add button
                if (_totalPhotos < 6)
                  GestureDetector(
                    onTap: _pickPhotos,
                    child: Container(
                      width: 100, height: 100,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        border: Border.all(color: AppColors.border, width: 1.5, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.orange, size: 30),
                        SizedBox(height: 4),
                        Text('Add', style: TextStyle(fontSize: 12, color: AppColors.sub)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Basics ──────────────────────────────────────────────────────
          _section('Basics'),
          TextField(controller: _title,
            decoration: const InputDecoration(hintText: 'Title (e.g. 1BHK near Metro) *')),
          const SizedBox(height: 12),
          TextField(controller: _description, maxLines: 3,
            decoration: const InputDecoration(hintText: 'Description (optional)')),
          const SizedBox(height: 24),

          // ── Location ────────────────────────────────────────────────────
          _section('Location'),
          CityField(controller: _city, hint: 'City *'),
          const SizedBox(height: 12),
          TextField(
            controller: _area,
            decoration: InputDecoration(
              hintText: 'Area / Locality *',
              suffixIcon: _locationSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.orange)))
                  : _locationConfirmed
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF4CAF50), size: 20)
                      : null,
            ),
            onChanged: (v) {
              setState(() { _locationConfirmed = false; _locationSearching = false; });
              _areaDebounce?.cancel();
              _areaDebounce = Timer(const Duration(milliseconds: 700), () {
                _geocodeAsYouType(v);
              });
            },
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _locationConfirmed
                  ? '✓ Location found — room will appear on Discover map'
                  : _locationSearching
                      ? 'Finding location...'
                      : _latitude == null && _area.text.length >= 3
                          ? '⚠ Location not found — try a different spelling'
                          : 'ⓘ Type your area/locality name',
              style: TextStyle(
                fontSize: 11,
                color: _locationConfirmed
                    ? const Color(0xFF4CAF50)
                    : _latitude == null && !_locationSearching && _area.text.length >= 3
                        ? AppColors.rose
                        : AppColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openMapPicker,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _locationConfirmed ? const Color(0xFFEDFFF4) : AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _locationConfirmed ? const Color(0xFF4CAF50) : AppColors.border,
                    width: 1.5),
              ),
              child: Row(children: [
                Icon(
                    _locationConfirmed
                        ? Icons.check_circle_rounded
                        : Icons.map_outlined,
                    size: 20,
                    color: _locationConfirmed
                        ? const Color(0xFF4CAF50)
                        : AppColors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _locationConfirmed
                        ? 'Location pinned — tap to adjust on map'
                        : 'Set exact location on map',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _locationConfirmed
                            ? const Color(0xFF4CAF50)
                            : AppColors.ink),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: AppColors.sub),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          // ── Pricing ─────────────────────────────────────────────────────
          _section('Pricing'),
          TextField(controller: _rent,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(hintText: 'Monthly Rent *', prefixText: '₹ ')),
          const SizedBox(height: 24),

          // ── Room Details ─────────────────────────────────────────────────
          _section('Room Details'),
          _label('Room Type'),
          const SizedBox(height: 8),
          _segmented(
            options: const {'private': 'Private', 'shared': 'Shared', 'full_flat': 'Full Flat'},
            selected: _roomType,
            onChanged: (v) => setState(() => _roomType = v)),
          const SizedBox(height: 16),
          _label('Gender Preference'),
          const SizedBox(height: 8),
          _segmented(
            options: const {'any': 'Any', 'male': 'Male', 'female': 'Female'},
            selected: _genderPref,
            onChanged: (v) => setState(() => _genderPref = v)),
          const SizedBox(height: 16),
          _toggle('Furnished', _furnished, (v) => setState(() => _furnished = v)),
          _toggle('Smoking Allowed', _smoking, (v) => setState(() => _smoking = v)),
          const SizedBox(height: 24),

          // ── Availability ─────────────────────────────────────────────────
          _section('Availability'),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.border, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.sub),
                const SizedBox(width: 10),
                Text(
                  _availableFrom == null
                    ? 'Available from (optional)'
                    : DateFormat('d MMM yyyy').format(_availableFrom!),
                  style: TextStyle(
                    color: _availableFrom == null ? AppColors.muted : AppColors.ink)),
                const Spacer(),
                if (_availableFrom != null)
                  GestureDetector(
                    onTap: () => setState(() => _availableFrom = null),
                    child: const Icon(Icons.close, size: 16, color: AppColors.sub)),
              ]),
            ),
          ),
          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_isEdit ? 'Update Listing' : 'Post Room'),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _photoThumb({required Widget child, VoidCallback? onRemove}) {
    return Container(
      width: 100, height: 100,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: Stack(fit: StackFit.expand, children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
        if (onRemove != null)
          Positioned(top: 4, right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.black54),
                child: const Icon(Icons.close, size: 14, color: Colors.white)),
            )),
      ]),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)));

  Widget _label(String text) => Text(text,
    style: const TextStyle(fontSize: 13, color: AppColors.sub, fontWeight: FontWeight.w600));

  Widget _segmented({
    required Map<String, String> options,
    required String selected,
    required void Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: options.entries.map((e) {
        final active = e.key == selected;
        return Expanded(child: GestureDetector(
          onTap: () => onChanged(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: active ? AppColors.orange : Colors.transparent,
              borderRadius: BorderRadius.circular(9)),
            child: Text(e.value, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.sub)),
          )));
      }).toList()));
  }

  Widget _toggle(String label, bool value, void Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Switch(value: value, onChanged: onChanged, activeColor: AppColors.orange),
      ]));
  }
}

class _PickedPhoto {
  final Uint8List bytes;
  final String ext;
  const _PickedPhoto({required this.bytes, required this.ext});
}
