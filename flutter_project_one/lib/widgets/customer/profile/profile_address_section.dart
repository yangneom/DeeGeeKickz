import 'package:flutter/material.dart';
import '../../../models/customer_address.dart';
import '../../../services/customer/address/address_service.dart';
import 'address_bottom_sheet.dart';

/// "Saved Addresses" card — lists all [CustomerAddress] entries.
/// Edit icon and "Add New" both open [AddressBottomSheet].
class ProfileAddressSection extends StatefulWidget {
  final List<CustomerAddress> addresses;

  /// Called after a successful add/edit/delete, so the parent
  /// (ProfileScreen) can re-fetch from Supabase and pass fresh data down.
  final VoidCallback? onChanged;

  const ProfileAddressSection({
    super.key,
    required this.addresses,
    this.onChanged,
  });

  @override
  State<ProfileAddressSection> createState() => _ProfileAddressSectionState();
}

class _ProfileAddressSectionState extends State<ProfileAddressSection> {
  late List<CustomerAddress> _addresses;
  final AddressService _addressService = AddressService();
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _addresses = List.from(widget.addresses);
  }

  @override
  void didUpdateWidget(covariant ProfileAddressSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _addresses = List.from(widget.addresses);
  }

  // ── Add new ────────────────────────────────────────────────────────────────
  Future<void> _onAddNew() async {
    if (_isSaving) return;

    final CustomerAddress? result = await showAddressBottomSheet(
      context: context,
      existing: null,
    );
    if (result == null) return;

    setState(() => _isSaving = true);
    final bool success = await _addressService.addAddress(result);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      widget.onChanged?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save address. Please try again.'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  // ── Edit existing ──────────────────────────────────────────────────────────
  Future<void> _onEdit(CustomerAddress address) async {
    if (_isSaving) return;

    final CustomerAddress? result = await showAddressBottomSheet(
      context: context,
      existing: address,
    );
    if (result == null) return;

    setState(() => _isSaving = true);
    final bool success = await _addressService.updateAddress(result);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      widget.onChanged?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save changes. Please try again.'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> _onDelete(CustomerAddress address) async {
    if (_isDeleting) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF9F9F9),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'DELETE ADDRESS',
          style: TextStyle(
            fontFamily: 'Archivo Narrow',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this address?',
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF4C4546)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF656464))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DELETE', style: TextStyle(fontFamily: 'Inter', color: Color(0xFFBA1A1A))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    final String? errorMessage = await _addressService.deleteAddress(address);

    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (errorMessage == null) {
      widget.onChanged?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 768;
    final double padding = isDesktop ? 48.0 : 16.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5), width: 1),
      ),
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SAVED ADDRESSES',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                  color: Colors.black,
                ),
              ),
              GestureDetector(
                onTap: _isSaving ? null : _onAddNew,
                child: Text(
                  'ADD NEW',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    color: _isSaving ? const Color(0xFFCFC4C5) : Colors.black,
                  ),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 16),
            child: Divider(height: 1, color: Color(0xFFCFC4C5)),
          ),

          // ── Address list ────────────────────────────────────────
          if (_addresses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(Icons.location_off_outlined,
                      size: 40, color: Color(0xFFCFC4C5)),
                  const SizedBox(height: 12),
                  const Text(
                    'No saved addresses yet.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF656464),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _onAddNew,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      color: Colors.black,
                      child: const Text(
                        'ADD ADDRESS',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _addresses
                  .map((CustomerAddress addr) => _AddressTile(
                        address: addr,
                        onEdit: () => _onEdit(addr),
                        onDelete: () => _onDelete(addr),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ─── Single address tile ──────────────────────────────────────────────────────

class _AddressTile extends StatelessWidget {
  final CustomerAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressTile({required this.address, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        border: Border.all(
          color: address.isDefault
              ? Colors.black
              : const Color(0xFFCFC4C5),
          width: address.isDefault ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Left: address details ───────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // DEFAULT badge
                Row(
                  children: [
                    if (address.isDefault) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        color: Colors.black,
                        child: const Text(
                          'DEFAULT',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Text(
                      'HOME',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Street
                Text(
                  address.street,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF4C4546),
                  ),
                ),

                // Barangay
                if (address.barangay.isNotEmpty)
                  Text(
                    address.barangay,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF4C4546),
                    ),
                  ),

                // City, Province, Zip
                Text(
                  [address.city, address.province, address.zipCode]
                      .where((s) => s.isNotEmpty)
                      .join(', '),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF4C4546),
                  ),
                ),

                // Region
                if (address.region.isNotEmpty)
                  Text(
                    address.region,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF4C4546),
                    ),
                  ),

                // Landmark
                if (address.landmark.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    address.landmark,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Right: edit + delete icons ───────────────────────────
          Column(
            children: [
              GestureDetector(
                onTap: onEdit,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: Color(0xFF656464),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Color(0xFFBA1A1A),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}