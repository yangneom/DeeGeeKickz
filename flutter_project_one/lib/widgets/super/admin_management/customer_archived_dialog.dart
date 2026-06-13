import 'package:flutter/material.dart';
import '../../../models/customer_account.dart';
import '../../common/tables/common_table.dart';
import '../../common/dialog/confirm_dialog.dart';

// ================================================
// CUSTOMER ARCHIVED DIALOG
//
// Shows when super admin clicks "Archived" button
// Lists all archived customers with Restore button
// Uses CommonTable — same as all other screens
// ================================================

void showCustomerArchivedDialog({
  required BuildContext context,
  required List<CustomerAccount> archivedAccounts,
  required Function(CustomerAccount account) onRestore,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return CustomerArchivedDialog(
        archivedAccounts: archivedAccounts,
        onRestore: onRestore,
      );
    },
  );
}

class CustomerArchivedDialog extends StatefulWidget {
  final List<CustomerAccount> archivedAccounts;
  final Function(CustomerAccount account) onRestore;

  const CustomerArchivedDialog({
    super.key,
    required this.archivedAccounts,
    required this.onRestore,
  });

  @override
  State<CustomerArchivedDialog> createState() =>
      _CustomerArchivedDialogState();
}

class _CustomerArchivedDialogState extends State<CustomerArchivedDialog> {

  // ================================================
  // HANDLE RESTORE
  // uses ConfirmDialog before restoring
  // ================================================
  Future<void> _handleRestore(CustomerAccount account) async {
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Restore this account?',
      message:
          '${account.fullName} will be moved back to active accounts '
          'and will be able to log in again.',
      confirmLabel: 'Restore',
      confirmColor: const Color(0xFF2563EB),
    );

    if (confirmed != true) return;

    widget.onRestore(account);
  }

  // ================================================
  // BUILD ROWS for CommonTable
  // each row = List<Widget>
  // ================================================
  List<List<Widget>> _buildRows() {
    List<List<Widget>> tableRows = [];

    for (int i = 0; i < widget.archivedAccounts.length; i = i + 1) {
      CustomerAccount account = widget.archivedAccounts[i];

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

        // column 3 — archive date
        Text(
          account.archivedDate ?? '-',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 4 — restore button
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(
            onPressed: () => _handleRestore(account),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
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
              'Restore',
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
          maxWidth: 600,
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
                        'Archived Accounts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage and review archived customer accounts.',
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
                child: widget.archivedAccounts.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No archived accounts found.',
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
                          'Archive Date',
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