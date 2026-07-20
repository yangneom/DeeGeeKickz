import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/customer_cart_item.dart';
import '../../../models/customer_address.dart';
import '../../../services/customer/address/address_service.dart';
import '../../../widgets/customer/checkout/checkout_order_summary.dart';
import '../../../widgets/customer/checkout/checkout_address_selector.dart';
import '../../../widgets/customer/profile/address_bottom_sheet.dart';
import '../../../widgets/common/dialog/confirm_dialog.dart';

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
  final AddressService _addressService = AddressService();

  List<CustomerAddress> _savedAddresses = [];
  bool _isLoadingAddresses = true;
  bool _isSavingAddress = false; // guards against double-tap on Add/Edit

  String? _selectedAddressId;
  CustomerAddress? _selectedAddress;

  String _userName  = '';
  String _userPhone = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final addresses = await _addressService.getMyAddresses();
    if (!mounted) return;

    setState(() {
      _savedAddresses = addresses;
      _isLoadingAddresses = false;
    });

    final defaults = _savedAddresses.where((a) => a.isDefault).toList();
    if (defaults.isNotEmpty) {
      _selectAddress(defaults.first);
    } else if (_savedAddresses.isNotEmpty) {
      _selectAddress(_savedAddresses.first);
    }
  }

  Future<void> _loadUserInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await Supabase.instance.client
          .from('users')
          .select('first_name, last_name, phone')
          .eq('id', user.id)
          .single();

      if (!mounted) return;
      setState(() {
        _userName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
        _userPhone = profile['phone'] ?? '';
      });
    } catch (e) {
      print('CheckoutStep1Shipping._loadUserInfo error: $e');
    }
  }

  void _selectAddress(CustomerAddress address) {
    setState(() {
      _selectedAddressId = address.id;
      _selectedAddress   = address;
    });
  }

Future<void> _editAddress(CustomerAddress address) async {
    if (_isSavingAddress) return;

    final CustomerAddress? result = await showAddressBottomSheet(
      context: context,
      existing: address,
    );
    if (result == null) return;

    setState(() => _isSavingAddress = true);
    await _loadAddresses();

    if (!mounted) return;
    setState(() => _isSavingAddress = false);

    final updated = _savedAddresses.where((a) => a.id == result.id).toList();
    if (updated.isNotEmpty) _selectAddress(updated.first);
  }

Future<void> _addNew() async {
    if (_isSavingAddress) return;

    final CustomerAddress? result = await showAddressBottomSheet(
      context: context,
      existing: null,
    );
    if (result == null) return;

    setState(() => _isSavingAddress = true);
    await _loadAddresses();

    if (!mounted) return;
    setState(() => _isSavingAddress = false);

    if (_savedAddresses.isNotEmpty) {
      _selectAddress(_savedAddresses.last);
    }
  }

  Future<void> _deleteAddress(CustomerAddress address) async {
    if (_isSavingAddress) return;

    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Delete this address?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: const Color(0xFFBA1A1A),
    );
    if (confirmed != true) return;

setState(() => _isSavingAddress = true);
    final errorMessage = await _addressService.deleteAddress(address);

    if (!mounted) return;
    setState(() => _isSavingAddress = false);

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    final wasSelected = _selectedAddressId == address.id;
    await _loadAddresses();

    // _loadAddresses() already auto-selects default/first — but only
    // clear the old selection first if it was the one just deleted,
    // so a stale _selectedAddress object doesn't linger if the list
    // is now empty.
    if (wasSelected && _savedAddresses.isEmpty) {
      setState(() {
        _selectedAddressId = null;
        _selectedAddress = null;
      });
    }
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
    if (_isLoadingAddresses) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isDesktop = constraints.maxWidth >= 1024;

        final Widget formContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckoutAddressSelector(
              addresses:         _savedAddresses,
              selectedAddressId: _selectedAddressId,
              userName:          _userName,
              userPhone:         _userPhone,
              onSelected: (CustomerAddress? address) {
                if (address != null) _selectAddress(address);
              },
              onEdit:   _editAddress,
              onDelete: _deleteAddress,
              onAddNew: _addNew,
            ),

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