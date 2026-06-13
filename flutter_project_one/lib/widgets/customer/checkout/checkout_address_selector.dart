import 'package:flutter/material.dart';
import '../../../models/customer_address.dart';

/// Address selector shown at the top of Step 1.
/// Lets user pick a saved address (auto-fills form),
/// edit a saved address, or add a new one.
class CheckoutAddressSelector extends StatelessWidget {
  final List<CustomerAddress> addresses;
  final String? selectedAddressId;
  final ValueChanged<CustomerAddress?> onSelected;
  final ValueChanged<CustomerAddress> onEdit;
  final VoidCallback onAddNew;

  const CheckoutAddressSelector({
    super.key,
    required this.addresses,
    required this.selectedAddressId,
    required this.onSelected,
    required this.onEdit,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────
        const Text(
          'SAVED ADDRESSES',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
            color: Color(0xFF656464),
          ),
        ),
        const SizedBox(height: 16),

        // ── Saved address cards ──────────────────────
        ...addresses.map((address) {
          final isSelected = selectedAddressId == address.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AddressCard(
              address: address,
              isSelected: isSelected,
              onTap: () => onSelected(address),
              onEdit: () => onEdit(address),
            ),
          );
        }),

        const SizedBox(height: 4),

        // ── Add new address button ───────────────────
        GestureDetector(
          onTap: onAddNew,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(
                color: const Color(0xFFCFC4C5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.add, size: 16, color: Colors.black),
                SizedBox(width: 8),
                Text(
                  'ADD NEW ADDRESS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),
        const Divider(color: Color(0xFFCFC4C5), thickness: 1),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  final CustomerAddress address;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _AddressCard({
    required this.address,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF3F3F4)
              : const Color(0xFFF9F9F9),
          border: Border.all(
            color: isSelected ? Colors.black : const Color(0xFFCFC4C5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Radio indicator ────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.black : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? Colors.black
                        : const Color(0xFF7E7576),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.circle,
                        size: 8,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),

            const SizedBox(width: 16),

            // ── Address details ────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        address.fullName,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (address.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          color: Colors.black,
                          child: const Text(
                            'DEFAULT',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.street,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF4C4546),
                    ),
                  ),
                  Text(
                    '${address.city}, ${address.postal}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF4C4546),
                    ),
                  ),
                  Text(
                    address.country,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF4C4546),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.phone,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF4C4546),
                    ),
                  ),
                ],
              ),
            ),

            // ── Edit button ────────────────────────
            GestureDetector(
              onTap: onEdit,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  'EDIT',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: Colors.black,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}