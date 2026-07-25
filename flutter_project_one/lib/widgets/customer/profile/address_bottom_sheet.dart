import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/customer_address.dart';

/// Shows a bottom sheet for adding a new address or editing an existing one.
///
/// Usage:
/// ```dart
/// final result = await showAddressBottomSheet(
///   context: context,
///   existing: address, // null = add new
/// );
/// if (result != null) { /* save result */ }
/// ```
Future<CustomerAddress?> showAddressBottomSheet({
  required BuildContext context,
  CustomerAddress? existing,
}) {
  return showModalBottomSheet<CustomerAddress>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddressBottomSheet(existing: existing),
  );
}

/// Thrown by _geocode when the address itself is the problem — no
/// match found, or a match was found but rejected as too imprecise
/// to trust (see geocode-address's confidence threshold). This is
/// the ONE case where saving is blocked — a network hiccup or the
/// geocoding service being briefly down should NOT block a customer
/// from saving what may well be a perfectly real address.
class _AddressQualityException implements Exception {
  final String message;
  _AddressQualityException(this.message);
}

class AddressBottomSheet extends StatefulWidget {
  /// If null → Add New mode. If provided → Edit mode.
  final CustomerAddress? existing;

  const AddressBottomSheet({super.key, this.existing});

  @override
  State<AddressBottomSheet> createState() => _AddressBottomSheetState();
}

class _AddressBottomSheetState extends State<AddressBottomSheet> {

  late final TextEditingController _streetCtrl;
  late final TextEditingController _barangayCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _provinceCtrl;
  late final TextEditingController _zipCodeCtrl;
  late final TextEditingController _landmarkCtrl;
  late String _region;
  bool _isDefault = false;

  // NEW — true while geocode-address is running, so the Save
  // button can show a spinner and block double-taps.
  bool _isSaving = false;

  // NEW — set when the last save attempt was blocked because the
  // address couldn't be verified as real. Shown inline above the
  // Save button so it's obvious why saving didn't go through.
  String? _addressErrorMessage;

  bool get _isEditing => widget.existing != null;

  // PH regions dropdown
  static const List<String> _regions = [
    'NCR – National Capital Region',
    'CAR – Cordillera Administrative Region',
    'Region I – Ilocos Region',
    'Region II – Cagayan Valley',
    'Region III – Central Luzon',
    'Region IV-A – CALABARZON',
    'Region IV-B – MIMAROPA',
    'Region V – Bicol Region',
    'Region VI – Western Visayas',
    'Region VII – Central Visayas',
    'Region VIII – Eastern Visayas',
    'Region IX – Zamboanga Peninsula',
    'Region X – Northern Mindanao',
    'Region XI – Davao Region',
    'Region XII – SOCCSKSARGEN',
    'Region XIII – Caraga',
    'BARMM – Bangsamoro',
  ];

  @override
  void initState() {
    super.initState();
    final CustomerAddress? a = widget.existing;
    _streetCtrl   = TextEditingController(text: a?.street   ?? '');
    _barangayCtrl = TextEditingController(text: a?.barangay ?? '');
    _cityCtrl     = TextEditingController(text: a?.city     ?? '');
    _provinceCtrl = TextEditingController(text: a?.province ?? '');
    _zipCodeCtrl  = TextEditingController(text: a?.zipCode  ?? '');
    _landmarkCtrl = TextEditingController(text: a?.landmark ?? '');
    // Match stored region against dropdown items.
    // Handles short forms like 'NCR' matching 'NCR – National Capital Region'.
    final String storedRegion = a?.region ?? '';
    if (storedRegion.isEmpty) {
      _region = _regions.first;
    } else {
      _region = _regions.firstWhere(
        (r) => r == storedRegion || r.startsWith(storedRegion),
        orElse: () => _regions.first,
      );
    }
    _isDefault    = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _streetCtrl.dispose();
    _barangayCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _zipCodeCtrl.dispose();
    _landmarkCtrl.dispose();
    super.dispose();
  }

  // ================================================
  // GEOCODE — calls the geocode-address Edge Function.
  //
  // Returns {lat, lng} on success.
  // Returns null on a service-side hiccup (network error, function
  //   down, unexpected response shape) — does NOT block saving,
  //   since a temporary outage isn't the address's fault.
  // Throws _AddressQualityException when the function explicitly
  //   says this isn't a real, deliverable address (no match found,
  //   or a match was found but confidence was too low to trust) —
  //   THIS case blocks saving, since it's not a transient problem,
  //   it's the address itself.
  // ================================================
  Future<Map<String, double>?> _geocode() async {
    late final dynamic responseData;

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'geocode-address',
        body: {
          'street': _streetCtrl.text.trim(),
          'barangay': _barangayCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'province': _provinceCtrl.text.trim(),
          'zipCode': _zipCodeCtrl.text.trim(),
        },
      );
      responseData = response.data;
    } catch (e) {
      // Network error, function completely unreachable, etc. — not
      // an address-quality signal, don't block the save.
      print('AddressBottomSheet._geocode error: $e');
      return null;
    }

    if (responseData == null) {
      print('AddressBottomSheet._geocode: null response data');
      return null;
    }

    final Map<String, dynamic> data = responseData is Map<String, dynamic>
        ? responseData
        : {};

    // The edge function returns a body even on 404/422/502 — check
    // for its 'error' field rather than relying on the client
    // throwing, since Supabase's functions.invoke doesn't always
    // throw for non-2xx (same pattern used in LalamoveService).
    final String? errorText = data['error'] as String?;

    if (errorText != null) {
      final String lower = errorText.toLowerCase();
      final bool isAddressQualityIssue =
          lower.contains('no results found') ||
          lower.contains('too imprecise') ||
          lower.contains('no address fields');

      if (isAddressQualityIssue) {
        throw _AddressQualityException(
          'We couldn\'t verify this as a real, deliverable address. '
          'Please check the street, barangay, and city and try again.',
        );
      }

      // Some other server-side error (e.g. geocoding provider down,
      // status 502) — treat like a network hiccup, don't block.
      print('AddressBottomSheet._geocode: service error — $errorText');
      return null;
    }

    if (data['lat'] == null || data['lng'] == null) {
      print('AddressBottomSheet._geocode: no coordinates in response — $data');
      return null;
    }

    return {
      'lat': (data['lat'] as num).toDouble(),
      'lng': (data['lng'] as num).toDouble(),
    };
  }

  Future<void> _save() async {
    // Validate required fields
    if (_streetCtrl.text.trim().isEmpty ||
        _barangayCtrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty ||
        _provinceCtrl.text.trim().isEmpty ||
        _zipCodeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all required fields.',
            style: TextStyle(fontFamily: 'Inter'),
          ),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _addressErrorMessage = null;
    });

    // Only re-geocode if the address text actually changed (or this
    // is a brand-new address) — no point burning a request re-geocoding
    // an unchanged address when editing just the "default" checkbox.
    final CustomerAddress? existing = widget.existing;
    final bool addressTextChanged = existing == null ||
        existing.street   != _streetCtrl.text.trim()   ||
        existing.barangay != _barangayCtrl.text.trim() ||
        existing.city     != _cityCtrl.text.trim()      ||
        existing.province != _provinceCtrl.text.trim()  ||
        existing.zipCode  != _zipCodeCtrl.text.trim();

    double? lat = existing?.lat;
    double? lng = existing?.lng;

    if (addressTextChanged) {
      try {
        final coords = await _geocode();
        lat = coords?['lat'];
        lng = coords?['lng'];
      } on _AddressQualityException catch (e) {
        // BLOCKED — this specifically means the address itself
        // looks fake/unmatchable, not a transient failure.
        if (mounted) {
          setState(() {
            _isSaving = false;
            _addressErrorMessage = e.message;
          });
        }
        return;
      }
    }

    if (!mounted) return;

    final CustomerAddress result = CustomerAddress(
      id:        widget.existing?.id ?? '',   // '' = new, not yet in Supabase
      street:    _streetCtrl.text.trim(),
      barangay:  _barangayCtrl.text.trim(),
      city:      _cityCtrl.text.trim(),
      province:  _provinceCtrl.text.trim(),
      region:    _region,
      zipCode:   _zipCodeCtrl.text.trim(),
      landmark:  _landmarkCtrl.text.trim(),
      isDefault: _isDefault,
      lat: lat,
      lng: lng,
    );

    setState(() => _isSaving = false);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.92;
    final double bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Drag handle ──────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFCFC4C5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'EDIT ADDRESS' : 'ADD NEW ADDRESS',
                  style: const TextStyle(
                    fontFamily: 'Archivo Narrow',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFCFC4C5)),

          // ── Scrollable form ──────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Street Address ──────────────────────────────
                  _FormField(
                    label: 'Street Address *',
                    controller: _streetCtrl,
                    hint: 'House no., Street name',
                  ),
                  const SizedBox(height: 16),

                  // ── Barangay ────────────────────────────────────
                  _FormField(
                    label: 'Barangay *',
                    controller: _barangayCtrl,
                    hint: 'e.g. Barangay Poblacion',
                  ),
                  const SizedBox(height: 16),

                  // ── City + Zip Code row ─────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _FormField(
                          label: 'City / Municipality *',
                          controller: _cityCtrl,
                          hint: 'e.g. Makati',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _FormField(
                          label: 'Zip Code *',
                          controller: _zipCodeCtrl,
                          hint: 'e.g. 1200',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Province ────────────────────────────────────
                  _FormField(
                    label: 'Province *',
                    controller: _provinceCtrl,
                    hint: 'e.g. Metro Manila',
                  ),
                  const SizedBox(height: 16),

                  // ── Region dropdown ─────────────────────────────
                  _label('Region *'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFCFC4C5)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _region,
                        isExpanded: true,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.black,
                        ),
                        items: _regions.map((String r) =>
                          DropdownMenuItem<String>(
                            value: r,
                            child: Text(r),
                          ),
                        ).toList(),
                        onChanged: (String? v) =>
                            setState(() => _region = v ?? _region),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Landmark (optional) ─────────────────────────
                  _FormField(
                    label: 'Landmark (optional)',
                    controller: _landmarkCtrl,
                    hint: 'e.g. Near SM Megamall',
                  ),
                  const SizedBox(height: 20),

                  // ── Set as default toggle ───────────────────────
                  Row(
                    children: [
                      Checkbox(
                        value: _isDefault,
                        activeColor: Colors.black,
                        onChanged: (bool? v) =>
                            setState(() => _isDefault = v ?? false),
                      ),
                      const Text(
                        'Set as default address',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),

                  // ── Address-quality error (blocks save) ─────────
                  if (_addressErrorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 16, color: Color(0xFFBA1A1A)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _addressErrorMessage!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFF7A1212),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Save button ─────────────────────────────────
                  GestureDetector(
                    onTap: _isSaving ? null : _save,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: _isSaving ? const Color(0xFF4C4546) : Colors.black,
                      alignment: Alignment.center,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditing ? 'SAVE CHANGES' : 'SAVE ADDRESS',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.0,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Cancel button ───────────────────────────────
                  GestureDetector(
                    onTap: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCFC4C5)),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.0,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Widget _label(String text) => Text(
  text.toUpperCase(),
  style: const TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: Color(0xFF656464),
  ),
);

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType keyboardType;

  const _FormField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFFCFC4C5),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFFCFC4C5)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Colors.black, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}