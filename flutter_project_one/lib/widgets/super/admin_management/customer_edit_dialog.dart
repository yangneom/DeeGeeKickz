import 'package:flutter/material.dart';
import '../../../models/customer_account.dart';
import 'customer_disable_dialog.dart';

// ================================================
// CUSTOMER VIEW DIALOG
//
// Shows when super admin clicks Edit & View
// on a customer account row.
//
// Customers manage their own name/contact/address/
// password on their own profile — admin has NO edit
// access to that data. This dialog is VIEW ONLY,
// plus the ability to Disable the account.
// ================================================

void showCustomerEditDialog({
  required BuildContext context,
  required CustomerAccount account,
  required Function(String reason) onDisable,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return CustomerEditDialog(
        account: account,
        onDisable: onDisable,
      );
    },
  );
}

class CustomerEditDialog extends StatelessWidget {
  final CustomerAccount account;
  final Function(String reason) onDisable;

  const CustomerEditDialog({
    super.key,
    required this.account,
    required this.onDisable,
  });

  // ================================================
  // BUILD READ ONLY INFO ROW
  // label + value, no text field
  // ================================================
  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '-' : value,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── FIXED HEADER ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB)),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Customer account details (view only)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),

            // ── SCROLLABLE CONTENT ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // name row
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoRow('First Name', account.firstName),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInfoRow('Last Name', account.lastName),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _buildInfoRow('Contact Number', account.phone),
                    const SizedBox(height: 12),
                    _buildInfoRow('Email', account.email),
                    const SizedBox(height: 12),
                    _buildInfoRow('Address', account.address),
                    const SizedBox(height: 12),
                    _buildInfoRow('Landmark', account.landmark),
                    const SizedBox(height: 12),
                    _buildInfoRow('Status', account.status),
                    const SizedBox(height: 12),
                    _buildInfoRow('Last Login', account.lastLogin),
                    const SizedBox(height: 12),
                    _buildInfoRow('Registered On', account.registeredOn),

                    if (account.isDisabled) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Disable Reason',
                        account.disableReason ?? '-',
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── FOOTER BUTTONS ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        if (!account.isDisabled) ...[
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // close view dialog first
                              showCustomerDisableDialog(
                                context: context,
                                account: account,
                                onDisable: onDisable,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 11,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Disable Account',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}