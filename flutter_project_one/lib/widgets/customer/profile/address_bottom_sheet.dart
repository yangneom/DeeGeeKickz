import 'package:flutter/material.dart';
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

class AddressBottomSheet extends StatefulWidget {
  /// If null → Add New mode. If provided → Edit mode.
  final CustomerAddress? existing;

  const AddressBottomSheet({super.key, this.existing});

  @override
  State<AddressBottomSheet> createState() => _AddressBottomSheetState();
}

class _AddressBottomSheetState extends State<AddressBottomSheet> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _postalCtrl;
  late final TextEditingController _phoneCtrl;
  late String _country;
  bool _isDefault = false;

  bool get _isEditing => widget.existing != null;

  // Countries list — matches checkout form
  static const List<String> _countries = [
    'Philippines',
    'United States',
    'Japan',
    'South Korea',
    'Singapore',
    'Australia',
    'United Kingdom',
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _firstNameCtrl = TextEditingController(text: a?.firstName ?? '');
    _lastNameCtrl  = TextEditingController(text: a?.lastName ?? '');
    _streetCtrl    = TextEditingController(text: a?.street ?? '');
    _cityCtrl      = TextEditingController(text: a?.city ?? '');
    _postalCtrl    = TextEditingController(text: a?.postal ?? '');
    _phoneCtrl     = TextEditingController(text: a?.phone ?? '');
    _country       = a?.country ?? 'Philippines';
    _isDefault     = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _postalCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _save() {
    // Basic validation
    if (_firstNameCtrl.text.trim().isEmpty ||
        _lastNameCtrl.text.trim().isEmpty ||
        _streetCtrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty ||
        _postalCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all fields.',
            style: TextStyle(fontFamily: 'Inter'),
          ),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    final result = CustomerAddress(
      id: widget.existing?.id ??
          'addr_${DateTime.now().millisecondsSinceEpoch}',
      firstName: _firstNameCtrl.text.trim(),
      lastName:  _lastNameCtrl.text.trim(),
      street:    _streetCtrl.text.trim(),
      city:      _cityCtrl.text.trim(),
      postal:    _postalCtrl.text.trim(),
      phone:     _phoneCtrl.text.trim(),
      country:   _country,
      isDefault: _isDefault,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    // Sheet takes up to 90% of screen height so keyboard doesn't clip it
    final maxHeight = MediaQuery.of(context).size.height * 0.90;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFCFC4C5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ─────────────────────────────────────────────
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

          // ── Scrollable form ────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First name + Last name row
                  Row(
                    children: [
                      Expanded(
                        child: _FormField(
                          label: 'First Name',
                          controller: _firstNameCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FormField(
                          label: 'Last Name',
                          controller: _lastNameCtrl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Street
                  _FormField(
                    label: 'Street Address',
                    controller: _streetCtrl,
                    hint: 'House no., Street, Barangay',
                  ),
                  const SizedBox(height: 16),

                  // City + Postal row
                  Row(
                    children: [
                      Expanded(
                        child: _FormField(
                          label: 'City',
                          controller: _cityCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FormField(
                          label: 'Postal Code',
                          controller: _postalCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  _FormField(
                    label: 'Phone Number',
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    hint: '+63 9XX XXX XXXX',
                  ),
                  const SizedBox(height: 16),

                  // Country dropdown
                  _label('Country'),
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
                        value: _country,
                        isExpanded: true,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          color: Colors.black,
                        ),
                        items: _countries
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _country = v ?? _country),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Set as default toggle
                  Row(
                    children: [
                      Checkbox(
                        value: _isDefault,
                        activeColor: Colors.black,
                        onChanged: (v) =>
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
                  const SizedBox(height: 24),

                  // Save button
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: Text(
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

                  // Cancel button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
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
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: const BorderSide(color: Color(0xFFCFC4C5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}