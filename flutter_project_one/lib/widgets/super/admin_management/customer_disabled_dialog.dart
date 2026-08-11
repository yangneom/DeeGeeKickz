import 'package:flutter/material.dart';
import '../../../models/customer_account.dart';
import '../../common/tables/common_table.dart';
import '../../common/dialog/confirm_dialog.dart';

// ================================================
// CUSTOMER DISABLED DIALOG
//
// Shows when super admin clicks "Disabled Account"
// Lists all disabled customers with Enable button
// Uses CommonTable — same as all other screens
//
// CHANGES this round (matching admin_disabled_dialog.dart):
//   - "Activate" renamed to "Enable" — both dialogs do the exact
//     same thing (re-enable a disabled account), so they should
//     say the same word instead of two different labels for one action.
//   - Added a search bar, matching the admin dialog's layout/spacing.
//   - On Enable, the row is now removed from the list immediately
//     and the dialog STAYS OPEN — previously nothing removed the row
//     at all, so a re-enabled account kept sitting in the list
//     looking unchanged even though the action succeeded. Staying
//     open also means an admin re-enabling several accounts in a row
//     doesn't have to reopen this dialog each time.
//   - Removed the redundant X close icon in the header — Cancel in
//     the footer already does the same thing, no need for two.
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Local mutable copy — lets us remove a row immediately on Enable
  // without needing the parent screen to refetch and rebuild this
  // dialog from scratch.
  late List<CustomerAccount> _accounts;

  @override
  void initState() {
    super.initState();
    _accounts = List.of(widget.disabledAccounts);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filter accounts by search query ──────────
  List<CustomerAccount> get _filtered {
    if (_searchQuery.isEmpty) return _accounts;
    return _accounts.where((a) {
      final name = a.fullName.toLowerCase();
      final email = a.email.toLowerCase();
      final reason = (a.disableReason ?? '').toLowerCase();
      return name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          reason.contains(_searchQuery);
    }).toList();
  }

  // ================================================
  // HANDLE ENABLE
  // Confirms, fires the callback, then removes just this row —
  // the dialog itself stays open.
  // ================================================
  Future<void> _handleActivate(CustomerAccount account) async {
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Enable this account?',
      message:
          '${account.fullName} will regain access to their account '
          'and will be able to log in again.',
      confirmLabel: 'Enable',
      confirmColor: const Color(0xFF16A34A),
    );

    if (confirmed != true) return;

    widget.onActivate(account);

    if (!mounted) return;
    setState(() {
      _accounts.removeWhere((a) => a.id == account.id);
    });
  }

  // ================================================
  // BUILD ROWS for CommonTable
  // each row = List<Widget>
  // ================================================
  List<List<Widget>> _buildRows() {
    return _filtered.map((account) {
      return [
        Text(
          account.fullName,
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
        Text(
          account.email,
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          account.disableReason ?? '-',
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          account.disabledDate ?? '-',
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(
            onPressed: () => _handleActivate(account),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Enable', style: TextStyle(fontSize: 12)),
          ),
        ),
      ];
    }).toList();
  }

  // ================================================
  // BUILD
  // fixed header + search + scrollable CommonTable + fixed footer
  // ================================================
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1100,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── FIXED HEADER ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
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
              child: const Column(
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
            ),

            // ── SEARCH BAR ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or reason...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: Color(0xFF9CA3AF),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),

            // ── SCROLLABLE CONTENT ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _accounts.isEmpty
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
                    : filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                'No results for "$_searchQuery".',
                                style: const TextStyle(
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