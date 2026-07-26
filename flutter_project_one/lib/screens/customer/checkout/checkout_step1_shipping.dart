import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/customer_cart_item.dart';
import '../../../models/customer_address.dart';
import '../../../services/customer/address/address_service.dart';
import '../../../services/customer/delivery/lalamove_service.dart';
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

  /// NEW — fired whenever the shipping fee changes: right after an
  /// address is selected (fee = 0, isLoading = true, while the quote
  /// is in flight), then again once the quote resolves (real fee,
  /// isLoading = false). If the quote fails, this is NOT called with
  /// a fake fallback fee anymore — see _fetchShippingQuote.
  final void Function(double shippingFee, bool isLoading) onShippingFeeChanged;

  final void Function({
    String? addressId,
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
    required this.onShippingFeeChanged,
    required this.onContinue,
  });

  @override
  State<CheckoutStep1Shipping> createState() => _CheckoutStep1ShippingState();
}

class _CheckoutStep1ShippingState extends State<CheckoutStep1Shipping> {
  final AddressService _addressService = AddressService();
  final LalamoveService _lalamoveService = LalamoveService();

  List<CustomerAddress> _savedAddresses = [];
  bool _isLoadingAddresses = true;
  bool _isSavingAddress = false; // guards against double-tap on Add/Edit

  String? _selectedAddressId;
  CustomerAddress? _selectedAddress;

  // ── Shipping quote state ──────────────────────────────────────
  bool _isLoadingQuote = false;

  // NEW — replaces the old silent-fallback approach. When non-null,
  // checkout is BLOCKED — the customer cannot continue to Review
  // until this clears (either by fixing the address, or by a
  // successful retry for a service-side failure).
  String? _quoteErrorMessage;

  // Distinguishes "this address is the problem" (needs editing) from
  // "the pricing service is temporarily unreachable" (worth retrying)
  // so the UI can offer the right action.
  bool _isAddressProblem = false;

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
    _fetchShippingQuote(address);
  }

  // ================================================
  // FETCH SHIPPING QUOTE
  //
  // UPDATE (Option 1 — block instead of silently falling back):
  // If Lalamove can't price this address — whether because it has
  // no coordinates at all, or the quote call itself fails — checkout
  // is now BLOCKED. No flat-rate fallback fee is charged anymore,
  // since that fee would be a guess for a delivery we can't actually
  // confirm is possible. The customer must fix the address (or, for
  // a service outage, retry) before they can continue.
  // ================================================
  Future<void> _fetchShippingQuote(CustomerAddress address) async {
    setState(() {
      _isLoadingQuote = true;
      _quoteErrorMessage = null;
      _isAddressProblem = false;
    });
    widget.onShippingFeeChanged(0, true);

    try {
      final quote = await _lalamoveService.getShippingQuote(
        dropoffAddress: address,
      );

      if (!mounted) return;
      setState(() {
        _isLoadingQuote = false;
        _quoteErrorMessage = null;
      });
      widget.onShippingFeeChanged(quote.priceTotal, false);
    } on MissingCoordinatesException catch (_) {
      // The address itself is the problem — geocoding failed, or was
      // rejected as too low-confidence to trust (see geocode-address).
      // Nothing to charge for a delivery we can't confirm is real.
      if (!mounted) return;
      setState(() {
        _isLoadingQuote = false;
        _isAddressProblem = true;
        _quoteErrorMessage =
            'We can\'t calculate shipping for this address — please double-check '
            'it and make sure the street, barangay, and city are correct, then '
            'try again.';
      });
      widget.onShippingFeeChanged(0, false);
    } catch (e) {
      // Service-side failure (network, Lalamove API down, etc.) —
      // not necessarily the address's fault, so offer a retry instead
      // of steering the customer toward editing an address that may
      // be perfectly fine.
      print('CheckoutStep1Shipping._fetchShippingQuote error: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingQuote = false;
        _isAddressProblem = false;
        _quoteErrorMessage =
            'We couldn\'t reach the delivery pricing service. Please try again.';
      });
      widget.onShippingFeeChanged(0, false);
    }
  }

  // Checkout can't proceed while a quote is in flight, or while the
  // last attempt failed and hasn't been resolved.
  bool get _canContinue =>
      _selectedAddress != null && !_isLoadingQuote && _quoteErrorMessage == null;

Future<void> _editAddress(CustomerAddress address) async {
    if (_isSavingAddress) return;

    final CustomerAddress? result = await showAddressBottomSheet(
      context: context,
      existing: address,
    );
    if (result == null) return;

    setState(() => _isSavingAddress = true);

    // BUG FIX: this previously never actually saved the edited
    // address — it just re-fetched the (unchanged) list from the
    // DB, so edits silently did nothing.
    final bool ok = await _addressService.updateAddress(result);

    if (!mounted) return;

    if (!ok) {
      setState(() => _isSavingAddress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save changes. Please try again.'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

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

    // BUG FIX: this previously never actually saved the new address
    // — it just re-fetched the (unchanged) list from the DB, so
    // "adding" an address silently did nothing.
    final bool ok = await _addressService.addAddress(result);

    if (!mounted) return;

    if (!ok) {
      setState(() => _isSavingAddress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save address. Please try again.'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

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

    if (_isLoadingQuote) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please wait — calculating your shipping fee.',
            style: TextStyle(fontFamily: 'Inter'),
          ),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    // BLOCKED — quote failed (bad address or service error). Do not
    // let the customer proceed to Review/Payment with no confirmed
    // shipping fee.
    if (_quoteErrorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAddressProblem
                ? 'Please fix your shipping address before continuing.'
                : 'Please retry calculating shipping before continuing.',
            style: const TextStyle(fontFamily: 'Inter'),
          ),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    widget.onContinue(
      addressId: _selectedAddress!.id.isEmpty ? null : _selectedAddress!.id,
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

                    // ── Shipping fee status row ───────────────────
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFCFC4C5)),
                    const SizedBox(height: 12),
                    if (_isLoadingQuote)
                      const Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Calculating delivery fee…',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Color(0xFF656464),
                            ),
                          ),
                        ],
                      )
                    else if (_quoteErrorMessage != null)
                      // BLOCKED state — bad address or service error.
                      // Styled as a warning (not a subtle grey hint)
                      // since it's actively preventing checkout.
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 16, color: Color(0xFFBA1A1A)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _quoteErrorMessage!,
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
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: _isAddressProblem
                                  ? () => _editAddress(_selectedAddress!)
                                  : () => _fetchShippingQuote(_selectedAddress!),
                              child: Text(
                                _isAddressProblem
                                    ? 'EDIT ADDRESS'
                                    : 'TRY AGAIN',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: Color(0xFFBA1A1A),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        'Delivery fee: ₱${widget.shipping.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],

            _ContinueButton(onTap: _handleContinue, enabled: _canContinue),
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
                  total:          widget.total,
                  showPlaceOrder: false,
                  onPlaceOrder:   () {},
                  shippingUnavailable: _isLoadingQuote || _quoteErrorMessage != null,
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
  final bool enabled;
  const _ContinueButton({required this.onTap, this.enabled = true});

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: widget.enabled ? Colors.black : const Color(0xFFCFC4C5),
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