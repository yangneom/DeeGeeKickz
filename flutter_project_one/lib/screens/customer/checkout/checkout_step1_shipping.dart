import 'package:flutter/material.dart';
import '../../../models/customer_cart_item.dart';
import '../../../models/customer_address.dart';
import '../../../widgets/customer/checkout/checkout_shipping_form.dart';
import '../../../widgets/customer/checkout/checkout_order_summary.dart';
import '../../../widgets/customer/checkout/checkout_address_selector.dart';

/// Step 1 — Shipping Information.
/// Shows saved addresses if available, lets user pick/edit/add new.
/// Auto-fills form when a saved address is selected.
class CheckoutStep1Shipping extends StatefulWidget {
  final String initialFirstName;
  final String initialLastName;
  final String initialStreet;
  final String initialCity;
  final String initialPostal;
  final String initialPhone;
  final String initialCountry;
  final List<CustomerCartItem> items;
  final double subtotal, shipping, tax, total;
  final void Function({
    required String fn,
    required String ln,
    required String st,
    required String ct,
    required String ps,
    required String ph,
    required String co,
  }) onContinue;

  const CheckoutStep1Shipping({
    super.key,
    required this.initialFirstName,
    required this.initialLastName,
    required this.initialStreet,
    required this.initialCity,
    required this.initialPostal,
    required this.initialPhone,
    required this.initialCountry,
    required this.items,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    required this.onContinue,
  });

  @override
  State<CheckoutStep1Shipping> createState() =>
      _CheckoutStep1ShippingState();
}

class _CheckoutStep1ShippingState
    extends State<CheckoutStep1Shipping> {
  // ── Controllers ──────────────────────────────────────────────────────
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _postalCtrl;
  late final TextEditingController _phoneCtrl;
  late String _country;

  // ── Address selector state ────────────────────────────────────────────
  // Mock saved addresses — swap with Supabase fetch when ready
  final List<CustomerAddress> _savedAddresses =
      List.from(mockSavedAddresses);

  // null = adding new address, otherwise = selected address id
  String? _selectedAddressId;

  // Whether the form is visible (new address or editing)
  bool _showForm = false;

  // Whether we are editing an existing address
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();

    _firstNameCtrl =
        TextEditingController(text: widget.initialFirstName);
    _lastNameCtrl =
        TextEditingController(text: widget.initialLastName);
    _streetCtrl =
        TextEditingController(text: widget.initialStreet);
    _cityCtrl = TextEditingController(text: widget.initialCity);
    _postalCtrl =
        TextEditingController(text: widget.initialPostal);
    _phoneCtrl =
        TextEditingController(text: widget.initialPhone);
    _country = widget.initialCountry;

    // Auto-select default address on load
    final defaultAddress = _savedAddresses.where((a) => a.isDefault);
    if (defaultAddress.isNotEmpty) {
      _selectAddress(defaultAddress.first);
    }
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

  // ── Handlers ─────────────────────────────────────────────────────────

  void _selectAddress(CustomerAddress address) {
    setState(() {
      _selectedAddressId = address.id;
      _showForm = false;
      _isEditing = false;
      // Auto-fill form fields
      _firstNameCtrl.text = address.firstName;
      _lastNameCtrl.text = address.lastName;
      _streetCtrl.text = address.street;
      _cityCtrl.text = address.city;
      _postalCtrl.text = address.postal;
      _phoneCtrl.text = address.phone;
      _country = address.country;
    });
  }

  void _editAddress(CustomerAddress address) {
    setState(() {
      _selectedAddressId = address.id;
      _showForm = true;
      _isEditing = true;
      // Pre-fill form with address data
      _firstNameCtrl.text = address.firstName;
      _lastNameCtrl.text = address.lastName;
      _streetCtrl.text = address.street;
      _cityCtrl.text = address.city;
      _postalCtrl.text = address.postal;
      _phoneCtrl.text = address.phone;
      _country = address.country;
    });
  }

  void _addNew() {
    setState(() {
      _selectedAddressId = null;
      _showForm = true;
      _isEditing = false;
      // Clear form
      _firstNameCtrl.clear();
      _lastNameCtrl.clear();
      _streetCtrl.clear();
      _cityCtrl.clear();
      _postalCtrl.clear();
      _phoneCtrl.clear();
      _country = 'Philippines';
    });
  }

  void _cancelForm() {
    setState(() {
      _showForm = false;
      _isEditing = false;
      // Re-select default if available
      final defaultAddress =
          _savedAddresses.where((a) => a.isDefault);
      if (defaultAddress.isNotEmpty) {
        _selectAddress(defaultAddress.first);
      }
    });
  }

  void _saveEditedAddress() {
    if (_selectedAddressId == null) return;
    final index = _savedAddresses
        .indexWhere((a) => a.id == _selectedAddressId);
    if (index == -1) return;

    setState(() {
      _savedAddresses[index] = _savedAddresses[index].copyWith(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        street: _streetCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        postal: _postalCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        country: _country,
      );
      _showForm = false;
      _isEditing = false;
    });
  }

  void _saveNewAddress() {
    final newAddress = CustomerAddress(
      id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      street: _streetCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      postal: _postalCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      country: _country,
      isDefault: false,
    );

    setState(() {
      _savedAddresses.add(newAddress);
      _selectedAddressId = newAddress.id;
      _showForm = false;
      _isEditing = false;
    });
  }

  void _handleContinue() {
    // If form is open, validate it
    if (_showForm) {
      if (_firstNameCtrl.text.trim().isEmpty ||
          _lastNameCtrl.text.trim().isEmpty ||
          _streetCtrl.text.trim().isEmpty ||
          _cityCtrl.text.trim().isEmpty ||
          _postalCtrl.text.trim().isEmpty ||
          _phoneCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please fill in all shipping fields.',
              style: TextStyle(fontFamily: 'Inter'),
            ),
            backgroundColor: Colors.black,
          ),
        );
        return;
      }
    } else if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select or add a shipping address.',
            style: TextStyle(fontFamily: 'Inter'),
          ),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    widget.onContinue(
      fn: _firstNameCtrl.text.trim(),
      ln: _lastNameCtrl.text.trim(),
      st: _streetCtrl.text.trim(),
      ct: _cityCtrl.text.trim(),
      ps: _postalCtrl.text.trim(),
      ph: _phoneCtrl.text.trim(),
      co: _country,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 1024;

      final formContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Saved address selector ─────────────────
          CheckoutAddressSelector(
            addresses: _savedAddresses,
            selectedAddressId: _selectedAddressId,
            onSelected: (address) {
              if (address != null) _selectAddress(address);
            },
            onEdit: _editAddress,
            onAddNew: _addNew,
          ),

          // ── Selected address summary (when form hidden) ──
          if (!_showForm && _selectedAddressId != null) ...[
            const Text(
              'DELIVERING TO',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: Color(0xFF656464),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF3F3F4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_firstNameCtrl.text} ${_lastNameCtrl.text}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _streetCtrl.text,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF4C4546),
                    ),
                  ),
                  Text(
                    '${_cityCtrl.text}, ${_postalCtrl.text}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF4C4546),
                    ),
                  ),
                  Text(
                    _country,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF4C4546),
                    ),
                  ),
                  Text(
                    _phoneCtrl.text,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF4C4546),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],

          // ── Form (editing or adding new) ─────────────
          if (_showForm) ...[
            // Form title
            Text(
              _isEditing ? 'EDIT ADDRESS' : 'NEW ADDRESS',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: Color(0xFF656464),
              ),
            ),
            const SizedBox(height: 16),

            CheckoutShippingForm(
              firstNameController: _firstNameCtrl,
              lastNameController: _lastNameCtrl,
              streetController: _streetCtrl,
              cityController: _cityCtrl,
              postalController: _postalCtrl,
              phoneController: _phoneCtrl,
              selectedCountry: _country,
              onCountryChanged: (v) =>
                  setState(() => _country = v ?? _country),
            ),

            const SizedBox(height: 24),

            // Save / Cancel row
            Row(
              children: [
                Expanded(
                  child: _SaveAddressButton(
                    label: _isEditing
                        ? 'SAVE CHANGES'
                        : 'SAVE ADDRESS',
                    onTap: _isEditing
                        ? _saveEditedAddress
                        : _saveNewAddress,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CancelButton(onTap: _cancelForm),
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],

          // ── Continue button ──────────────────────────
          if (!_showForm)
            _ContinueButton(onTap: _handleContinue),
        ],
      );

      if (isDesktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.only(right: 40),
                child: formContent,
              ),
            ),
            Expanded(
              flex: 5,
              child: CheckoutOrderSummary(
                items: widget.items,
                subtotal: widget.subtotal,
                shipping: widget.shipping,
                tax: widget.tax,
                total: widget.total,
                showPlaceOrder: false,
                onPlaceOrder: () {},
              ),
            ),
          ],
        );
      }

      return formContent;
    });
  }
}

// ── Buttons ───────────────────────────────────────────────────────────────────

class _ContinueButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ContinueButton({required this.onTap});

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: Colors.black,
          alignment: Alignment.center,
          child: const Text(
            'CONTINUE TO REVIEW',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 3.0,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveAddressButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SaveAddressButton({required this.label, required this.onTap});

  @override
  State<_SaveAddressButton> createState() => _SaveAddressButtonState();
}

class _SaveAddressButtonState extends State<_SaveAddressButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: Colors.black,
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: const Color(0xFFCFC4C5)),
        ),
        alignment: Alignment.center,
        child: const Text(
          'CANCEL',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}