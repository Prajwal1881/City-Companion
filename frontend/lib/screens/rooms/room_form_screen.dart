import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../widgets/city_field.dart';

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

  bool get _isEdit => widget.room != null;

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
    }
  }

  @override
  void dispose() {
    _title.dispose(); _description.dispose(); _area.dispose();
    _city.dispose(); _rent.dispose();
    super.dispose();
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
      };
      if (_isEdit) {
        await ApiClient.updateRoom(widget.room!['id'].toString(), data);
      } else {
        await ApiClient.createRoom(data);
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
          _section('Basics'),
          TextField(
            controller: _title,
            decoration: const InputDecoration(hintText: 'Title (e.g. 1BHK near Metro) *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Description (optional)'),
          ),
          const SizedBox(height: 24),

          _section('Location'),
          CityField(controller: _city, hint: 'City *'),
          const SizedBox(height: 12),
          TextField(
            controller: _area,
            decoration: const InputDecoration(hintText: 'Area / Locality *'),
          ),
          const SizedBox(height: 24),

          _section('Pricing'),
          TextField(
            controller: _rent,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(hintText: 'Monthly Rent *', prefixText: '₹ '),
          ),
          const SizedBox(height: 24),

          _section('Room Details'),
          _label('Room Type'),
          const SizedBox(height: 8),
          _segmented(
            options: const {'private': 'Private', 'shared': 'Shared', 'full_flat': 'Full Flat'},
            selected: _roomType,
            onChanged: (v) => setState(() => _roomType = v),
          ),
          const SizedBox(height: 16),
          _label('Gender Preference'),
          const SizedBox(height: 8),
          _segmented(
            options: const {'any': 'Any', 'male': 'Male', 'female': 'Female'},
            selected: _genderPref,
            onChanged: (v) => setState(() => _genderPref = v),
          ),
          const SizedBox(height: 16),
          _toggle('Furnished', _furnished, (v) => setState(() => _furnished = v)),
          _toggle('Smoking Allowed', _smoking, (v) => setState(() => _smoking = v)),
          const SizedBox(height: 24),

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
                    color: _availableFrom == null ? AppColors.muted : AppColors.ink),
                ),
                const Spacer(),
                if (_availableFrom != null)
                  GestureDetector(
                    onTap: () => setState(() => _availableFrom = null),
                    child: const Icon(Icons.close, size: 16, color: AppColors.sub),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_isEdit ? 'Update Listing' : 'Post Room'),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)),
  );

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
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: active ? AppColors.orange : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(e.value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.sub)),
            ),
          ),
        );
      }).toList()),
    );
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
      ]),
    );
  }
}
