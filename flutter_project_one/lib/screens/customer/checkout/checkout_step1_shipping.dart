import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/customer_cart_item.dart';
import '../../../models/customer_address.dart';
import '../../../widgets/customer/checkout/checkout_order_summary.dart';
import '../../../widgets/customer/checkout/checkout_address_selector.dart';
import '../../../widgets/customer/profile/address_bottom_sheet.dart';

/// Step 1 — Shipping Information.
/// Shows saved addresses, lets user pick / edit / add new.
/// Auto-fills the delivery summary when a saved address is selected.
class CheckoutStep1Shipping extends StatefulWidget {
  final String initialStreet;
  final String initialCity;
  final String initialProvince;
  final String initialRegion;
  final String initialZipCode;
  final String initialLandmark;
  final String initialBarangay;
  final List<CustomerCartItem> items;
  final double subtotal, shipping, tax, total;
  final void Function({
    required String street,
    required String barangay,
    required String city,
    required String province,
    required String region,
    required String zipCode,
    required String landmark,
  }) onContinue;

  const CheckoutStep1Shipping({
    super.key,
    this.initialStreet    = '',
    this.initialCity      = '',
    this.initialProvince  = '',
    this.initialRegion    = '',
    this.initialZipCode   = '',
    this.initialLandmark  = '',
    this.initialBarangay  = '',
    required this.items,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    required this.onContinue,
  });

  @override
  State<CheckoutStep1Shipping> createState() => _CheckoutStep1ShippingState();
}

class _CheckoutStep1ShippingState extends State<CheckoutStep1Shipping> {

  // ── Saved addresses — swap with Supabase fetch when ready ─────────────
  final List<CustomerAddress> _savedAddresses = List.from(mockSavedAddresses);

  // ── Selected address id ───────────────────────────────────────────────
  String? _selectedAddressId;

  // ── Currently selected address object ────────────────────────────────
  CustomerAddress? _selectedAddress;

  // ── User name + phone from Supabase auth metadata ────────────────────
  String _userName  = '';
  String _userPhone = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();

    // Auto-select default address on load
    final List<CustomerAddress> defaults =
        _savedAddresses.where((a) => a.isDefault).toList();
    if (defaults.isNotEmpty) {
      _selectAddress(defaults.first);
    }
  }

  // ── Pull name + phone from the logged-in user's metadata ─────────────
  void _loadUserInfo() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final Map<String, dynamic> meta = user.userMetadata ?? {};
    final String firstName = meta['first_name'] ?? '';
    final String lastName  = meta['last_name']  ?? '';
    final String phone     = meta['phone']       ?? '';

    setState(() {
      _userName  = '$firstName $lastName'.trim();
      _userPhone = phone;
    });
  }

  // ── Handlers ──────────────────────────────────────────────────────────

  void _selectAddress(CustomerAddress address) {
    setState(() {
      _selectedAddressId = address.id;
      _selectedAddress   = address;
    });
  }

  Future<void> _editAddress(CustomerAddress address) async {
    final CustomerAddress? result = await showAddressBottomSheet(
      context: context,
      existing: address,
    );
    if (result == null) return;

    setState(() {
      final int idx = _savedAddresses.indexWhere((a) => a.id == result.id);
      if (idx == -1) return;

      if (result.isDefault) {
        for (int i = 0; i < _savedAddresses.length; i = i + 1) {
          _savedAddresses[i] = _savedAddresses[i].copyWith(isDefault: false);
        }
      }
      _savedAddresses[idx] = result;

      // Keep selection in sync
      if (_selectedAddressId == result.id) {
        _selectedAddress = result;
      }
    });
  }

  Future<void> _addNew() async {
    final CustomerAddress? result = await showAddressBottomSheet(
      context: context,
      existing: null,
    );
    if (result == null) return;

    setState(() {
      if (result.isDefault) {
        for (int i = 0; i < _savedAddresses.length; i = i + 1) {
          _savedAddresses[i] = _savedAddresses[i].copyWith(isDefault: false);
        }
      }
      _savedAddresses.add(result);
      _selectedAddressId = result.id;
      _selectedAddress   = result;
    });
  }

  void _handleContinue() {
    if (_selectedAddress == null) {
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
      street:   _selectedAddress!.street,
      barangay: _selectedAddress!.barangay,
      city:     _selectedAddress!.city,
      province: _selectedAddress!.province,
      region:   _selectedAddress!.region,
      zipCode:  _selectedAddress!.zipCode,
      landmark: _selectedAddress!.landmark,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isDesktop = constraints.maxWidth >= 1024;

        final Widget formContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Saved address selector ───────────────────────────
            CheckoutAddressSelector(
              addresses:         _savedAddresses,
              selectedAddressId: _selectedAddressId,
              userName:          _userName,
              userPhone:         _userPhone,
              onSelected: (CustomerAddress? address) {
                if (address != null) _selectAddress(address);
              },
              onEdit:   _editAddress,
              onAddNew: _addNew,
            ),

            // ── Delivering to summary ────────────────────────────
            if (_selectedAddress != null) ...[
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

                    // Name from profile
                    if (_userName.isNotEmpty)
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),

                    const SizedBox(height: 4),

                    Text(
                      _selectedAddress!.street,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xFF4C4546),
                      ),
                    ),

                    if (_selectedAddress!.barangay.isNotEmpty)
                      Text(
                        _selectedAddress!.barangay,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Color(0xFF4C4546),
                        ),
                      ),

                    Text(
                      [
                        _selectedAddress!.city,
                        _selectedAddress!.province,
                        _selectedAddress!.zipCode,
                      ].where((s) => s.isNotEmpty).join(', '),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xFF4C4546),
                      ),
                    ),

                    if (_selectedAddress!.region.isNotEmpty)
                      Text(
                        _selectedAddress!.region,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Color(0xFF4C4546),
                        ),
                      ),

                    if (_selectedAddress!.landmark.isNotEmpty)
                      Text(
                        _selectedAddress!.landmark,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                    if (_userPhone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _userPhone,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Color(0xFF4C4546),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],

            // ── Continue button ──────────────────────────────────
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
                  items:          widget.items,
                  subtotal:       widget.subtotal,
                  shipping:       widget.shipping,
                  tax:            widget.tax,
                  total:          widget.total,
                  showPlaceOrder: false,
                  onPlaceOrder:   () {},
                ),
              ),
            ],
          );
        }

        return formContent;
      },
    );
  }
}

// ─── Continue button ──────────────────────────────────────────────────────────

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