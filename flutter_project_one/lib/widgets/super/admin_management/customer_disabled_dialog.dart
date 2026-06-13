import 'package:flutter/material.dart';
import '../../../models/customer_account.dart';
import '../../common/tables/common_table.dart';
import '../../common/dialog/confirm_dialog.dart';

// ================================================
// CUSTOMER DISABLED DIALOG
//
// Shows when super admin clicks "Disabled Account"
// Lists all disabled customers with Activate button
// Uses CommonTable — same as all other screens
// ================================================

void showCustomerDisabledDialog({
  required BuildContext context,
  required List<CustomerAccount> disabledAccounts,
  required Function(CustomerAccount account) onActivate,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return CustomerDisabledDialog(
        disabledAccounts: disabledAccounts,
        onActivate: onActivate,
      );
    },
  );
}

class CustomerDisabledDialog extends StatefulWidget {
  final List<CustomerAccount> disabledAccounts;
  final Function(CustomerAccount account) onActivate;

  const CustomerDisabledDialog({
    super.key,
    required this.disabledAccounts,
    required this.onActivate,
  });

  @override
  State<CustomerDisabledDialog> createState() => _CustomerDisabledDialogState();
}

class _CustomerDisabledDialogState extends State<CustomerDisabledDialog> {

  // ================================================
  // HANDLE ACTIVATE
  // uses ConfirmDialog before activating
  // ================================================
  Future<void> _handleActivate(CustomerAccount account) async {
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Activate this account?',
      message:
          '${account.fullName} will regain access to their account '
          'and will be able to log in again.',
      confirmLabel: 'Activate',
      confirmColor: const Color(0xFF16A34A),
    );

    if (confirmed != true) return;

    widget.onActivate(account);
  }

  // ================================================
  // BUILD ROWS for CommonTable
  // each row = List<Widget>
  // ================================================
  List<List<Widget>> _buildRows() {
    List<List<Widget>> tableRows = [];

    for (int i = 0; i < widget.disabledAccounts.length; i = i + 1) {
      CustomerAccount account = widget.disabledAccounts[i];

      List<Widget> oneRow = [

        // column 1 — name
        Text(
          account.fullName,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 2 — email
        Text(
          account.email,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
          overflow: TextOverflow.ellipsis,
        ),

        // column 3 — reason
        Text(
          account.disableReason ?? '-',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
          overflow: TextOverflow.ellipsis,
        ),

        // column 4 — date disabled
        Text(
          account.disabledDate ?? '-',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 5 — activate button
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(
            onPressed: () => _handleActivate(account),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Activate',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      ];

      tableRows.add(oneRow);
    }

    return tableRows;
  }

  // ================================================
  // BUILD
  // fixed header + scrollable CommonTable + fixed footer
  // same pattern as feedback_details_dialog.dart
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 700,
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
                        'Disabled Accounts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage and review disabled user accounts.',
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
                child: widget.disabledAccounts.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No disabled accounts found.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      )
                    : CommonTable(
                        headers: const [
                          'Name',
                          'Email',
                          'Reason',
                          'Date Disabled',
                          'Action',
                        ],
                        rows: _buildRows(),
                      ),
              ),
            ),

            // ── FIXED FOOTER ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Row(
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
                      'Cancel',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}