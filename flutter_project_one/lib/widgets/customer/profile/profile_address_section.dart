import 'package:flutter/material.dart';
import '../../../models/customer_address.dart';
import 'address_bottom_sheet.dart';

/// "Saved Addresses" card — lists all [CustomerAddress] entries.
/// Edit icon and "Add New" both open [AddressBottomSheet].
class ProfileAddressSection extends StatefulWidget {
  final List<CustomerAddress> addresses;

  const ProfileAddressSection({super.key, required this.addresses});

  @override
  State<ProfileAddressSection> createState() => _ProfileAddressSectionState();
}

class _ProfileAddressSectionState extends State<ProfileAddressSection> {
  late List<CustomerAddress> _addresses;

  @override
  void initState() {
    super.initState();
    _addresses = List.from(widget.addresses);
  }

  // ── Add new ────────────────────────────────────────────────────────────────
  Future<void> _onAddNew() async {
    final CustomerAddress? result = await showAddressBottomSheet(
      context: context,
      existing: null,
    );
    if (result == null) return;

    setState(() {
      if (result.isDefault) {
        _addresses = _addresses
            .map((a) => a.copyWith(isDefault: false))
            .toList();
      }
      _addresses.add(result);
    });
  }

  // ── Edit existing ──────────────────────────────────────────────────────────
  Future<void> _onEdit(CustomerAddress address) async {
    final CustomerAddress? result = await showAddressBottomSheet(
      context: context,
      existing: address,
    );
    if (result == null) return;

    setState(() {
      final int idx = _addresses.indexWhere((a) => a.id == result.id);
      if (idx == -1) return;

      if (result.isDefault) {
        _addresses = _addresses
            .map((a) => a.copyWith(isDefault: false))
            .toList();
      }
      _addresses[idx] = result;
    });
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
                onTap: _onAddNew,
                child: const Text(
                  'ADD NEW',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    color: Colors.black,
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

  const _AddressTile({required this.address, required this.onEdit});

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

          // ── Right: edit icon ────────────────────────────────────
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
        ],
      ),
    );
  }
}