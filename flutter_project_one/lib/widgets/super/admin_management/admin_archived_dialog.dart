import 'package:flutter/material.dart';
import '../../../widgets/common/common_table.dart';
import '../../../widgets/common/confirm_dialog.dart';

// ================================================
// ADMIN ARCHIVED DIALOG
//
// Shows archived admin accounts with restore option
// ================================================

class AdminArchivedDialog extends StatefulWidget {
  final List<Map<String, dynamic>> archivedAccounts;
  final Function(Map<String, dynamic>) onRestore;

  const AdminArchivedDialog({
    super.key,
    required this.archivedAccounts,
    required this.onRestore,
  });

  @override
  State<AdminArchivedDialog> createState() => _AdminArchivedDialogState();
}

class _AdminArchivedDialogState extends State<AdminArchivedDialog> {

  // ================================================
  // HANDLE RESTORE
  // ================================================
  Future<void> _handleRestore(Map<String, dynamic> account) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Restore this account?',
      message:
          'This account will be restored and the user '
          'will be able to log in again.',
      confirmLabel: 'Restore',
      confirmColor: const Color(0xFF16A34A),
    );

    if (confirmed == true) {
      widget.onRestore(account);
      if (mounted) Navigator.pop(context);
    }
  }

  // ================================================
  // BUILD ROWS
  // same pattern as feedback_screen _buildRows()
  // ================================================
  List<List<Widget>> _buildRows() {
    List<List<Widget>> tableRows = [];

    for (int i = 0; i < widget.archivedAccounts.length; i = i + 1) {
      Map<String, dynamic> account = widget.archivedAccounts[i];

      List<Widget> oneRow = [

        // name
        Text(
          '${account['firstName']} ${account['lastName']}',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // email
        Text(
          account['email'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
          overflow: TextOverflow.ellipsis,
        ),

        // role
        Text(
          account['role'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // archive date
        Text(
          account['archiveDate'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // restore button
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(
            onPressed: () => _handleRestore(account),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
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
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 40,
        vertical: 24,
      ),
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
                        'Archived Accounts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage and review archived admin accounts.',
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
                          'Role',
                          'Archive Date',
                          'Action',
                        ],
                        rows: _buildRows(),
                      ),
              ),
            ),

            // ── FOOTER ──
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