import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/api_client.dart';

// ─── Create Plan Sheet ────────────────────────────────────────────────────────

class CreatePlanSheet extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onCreated;
  const CreatePlanSheet({super.key, required this.onCreated});
  @override
  State<CreatePlanSheet> createState() => _CreatePlanSheetState();
}

class _CreatePlanSheetState extends State<CreatePlanSheet> {
  int _step = 0;
  String? _cat;
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _loc = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _locationSuggestions = [];
  String? _autocompleteError;
  bool _locationLoading = false;
  bool _locationSelected = false;
  String? _selectedPlaceId;
  double? _selectedLat;
  double? _selectedLng;
  int _autocompleteRequestId = 0;
  int _max = 4;
  DateTime? _date;
  TimeOfDay? _time;
  bool _loading = false;

  static const _cats = [
    {
      'id': 'food',
      'label': 'Food',
      'emoji': '🍜',
      'color': Color(0xFFFF4D00),
      'bg': Color(0xFFFFF1EC)
    },
    {
      'id': 'play',
      'label': 'Play',
      'emoji': '🏏',
      'color': Color(0xFF0057FF),
      'bg': Color(0xFFEEF3FF)
    },
    {
      'id': 'gym',
      'label': 'Gym',
      'emoji': '💪',
      'color': Color(0xFF00C851),
      'bg': Color(0xFFEDFFF4)
    },
    {
      'id': 'ride',
      'label': 'Ride',
      'emoji': '🏍️',
      'color': Color(0xFFFFAB00),
      'bg': Color(0xFFFFFBEF)
    },
    {
      'id': 'hangout',
      'label': 'Hangout',
      'emoji': '☕',
      'color': Color(0xFF7C3AED),
      'bg': Color(0xFFF5F0FF)
    },
    {
      'id': 'trek',
      'label': 'Trek',
      'emoji': '🥾',
      'color': Color(0xFF00A896),
      'bg': Color(0xFFEDFAF8)
    },
  ];

  void _submit() async {
    if (_date == null || _time == null) return;
    setState(() => _loading = true);
    final dt = DateTime(
        _date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    await widget.onCreated({
      'category': _cat,
      'title': _title.text,
      'description': _desc.text,
      'location': _loc.text,
      'latitude': _selectedLat,
      'longitude': _selectedLng,
      'place_id': _selectedPlaceId,
      'max_members': _max,
      'plan_date': dt.toIso8601String(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _desc.dispose();
    _loc.dispose();
    super.dispose();
  }

  void _onLocationChanged(String value) {
    _debounce?.cancel();
    _autocompleteRequestId++;
    setState(() {
      _locationSelected = false;
      _selectedPlaceId = null;
      _selectedLat = null;
      _selectedLng = null;
      _autocompleteError = null;
    });

    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _locationSuggestions = [];
        _locationLoading = false;
      });
      return;
    }

    final requestId = _autocompleteRequestId;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() {
        _locationLoading = true;
        _autocompleteError = null;
      });
      try {
        final suggestions = await ApiClient.locationAutocomplete(query);
        if (!mounted || requestId != _autocompleteRequestId) return;
        setState(() {
          _locationSuggestions = suggestions;
          _locationLoading = false;
          _autocompleteError = null;
        });
      } on DioException {
        if (!mounted || requestId != _autocompleteRequestId) return;
        setState(() {
          _locationSuggestions = [];
          _locationLoading = false;
          _autocompleteError = "Couldn't fetch suggestions, try again";
        });
      } catch (_) {
        if (!mounted || requestId != _autocompleteRequestId) return;
        setState(() {
          _locationSuggestions = [];
          _locationLoading = false;
          _autocompleteError = "Couldn't fetch suggestions, try again";
        });
      }
    });
  }

  void _selectSuggestion(Map<String, dynamic> item) {
    final description = item['description']?.toString();
    final placeId = item['place_id']?.toString();
    final lat = (item['lat'] as num?)?.toDouble();
    final lng = (item['lng'] as num?)?.toDouble();
    if (description == null || placeId == null || lat == null || lng == null) {
      return;
    }

    setState(() {
      _loc.text = description;
      _locationSelected = true;
      _selectedPlaceId = placeId;
      _selectedLat = lat;
      _selectedLng = lng;
      _locationSuggestions = [];
      _autocompleteError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F6F2),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(children: [
              Text(['Pick category', 'Describe it', 'When & Where'][_step],
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 20)),
              const Spacer(),
              Row(
                  children: List.generate(
                      3,
                      (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(left: 5),
                            width: i == _step ? 22 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i <= _step
                                  ? AppColors.orange
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ))),
            ]),
          ),
          Expanded(
              child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  children: [
                if (_step == 0) ...[
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.1,
                    children: _cats
                        .map((c) => GestureDetector(
                              onTap: () =>
                                  setState(() => _cat = c['id'] as String),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: _cat == c['id']
                                      ? c['bg'] as Color
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: _cat == c['id']
                                          ? c['color'] as Color
                                          : AppColors.border,
                                      width: 2),
                                ),
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(c['emoji'] as String,
                                          style: const TextStyle(fontSize: 28)),
                                      const SizedBox(height: 6),
                                      Text(c['label'] as String,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _cat == c['id']
                                                  ? c['color'] as Color
                                                  : AppColors.sub)),
                                    ]),
                              ),
                            ))
                        .toList(),
                  ),
                ],
                if (_step == 1) ...[
                  _label('PLAN TITLE'),
                  TextField(
                      controller: _title,
                      decoration:
                          const InputDecoration(hintText: 'Give it a name')),
                  const SizedBox(height: 16),
                  _label('DESCRIPTION'),
                  TextField(
                      controller: _desc,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          hintText: 'Tell people what to expect...')),
                  const SizedBox(height: 16),
                  _label('MAX PEOPLE'),
                  Row(
                      children: [2, 3, 4, 6, 8, 10]
                          .map((n) => Expanded(
                                  child: Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: GestureDetector(
                                  onTap: () => setState(() => _max = n),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                        color: _max == n
                                            ? const Color(0xFFFFF1EC)
                                            : Colors.white,
                                        border: Border.all(
                                            color: _max == n
                                                ? AppColors.orange
                                                : AppColors.border,
                                            width: 2),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Center(
                                        child: Text('$n',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: _max == n
                                                    ? AppColors.orange
                                                    : AppColors.sub))),
                                  ),
                                ),
                              )))
                          .toList()),
                ],
                if (_step == 2) ...[
                  _label('LOCATION'),
                  TextField(
                    controller: _loc,
                    onChanged: _onLocationChanged,
                    decoration:
                        const InputDecoration(hintText: 'Search location'),
                  ),
                  if (_autocompleteError != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1EC),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          _autocompleteError!,
                          style: const TextStyle(
                              color: AppColors.sub,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                  if (_locationLoading) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  if (!_locationLoading &&
                      _loc.text.trim().isNotEmpty &&
                      !_locationSelected) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _locationSuggestions.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'No results found',
                                style: TextStyle(
                                    color: AppColors.sub, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: _locationSuggestions.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: AppColors.border),
                              itemBuilder: (_, i) {
                                final item = _locationSuggestions[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    item['description']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  onTap: () => _selectSuggestion(item),
                                );
                              },
                            ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          _label('DATE'),
                          GestureDetector(
                            onTap: () async {
                              final d = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)));
                              if (d != null) setState(() => _date = d);
                            },
                            child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppColors.border, width: 1.5)),
                                child: Text(
                                    _date == null
                                        ? 'Pick date'
                                        : '${_date!.day}/${_date!.month}/${_date!.year}',
                                    style: const TextStyle(fontSize: 14))),
                          ),
                        ])),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          _label('TIME'),
                          GestureDetector(
                            onTap: () async {
                              final t = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now());
                              if (t != null) setState(() => _time = t);
                            },
                            child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppColors.border, width: 1.5)),
                                child: Text(
                                    _time == null
                                        ? 'Pick time'
                                        : _time!.format(context),
                                    style: const TextStyle(fontSize: 14))),
                          ),
                        ])),
                  ]),
                ],
                const SizedBox(height: 24),
                Row(children: [
                  if (_step > 0)
                    Expanded(
                        child: OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          side: const BorderSide(
                              color: AppColors.border, width: 1.5)),
                      child: const Text('← Back',
                          style: TextStyle(
                              color: AppColors.sub,
                              fontWeight: FontWeight.w700)),
                    )),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _loading
                            ? null
                            : (_step < 2
                                ? () => setState(() => _step++)
                                : _submit),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Text(_step < 2 ? 'Continue →' : '🚀 Post Plan!',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15)),
                      )),
                ]),
                const SizedBox(height: 24),
              ])),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.sub,
                letterSpacing: 0.5)),
      );
}
