import 'package:flutter/material.dart';
import '../../common/tables/common_table.dart';
import '../../common/dialog/confirm_dialog.dart';
import '../../../models/admin_account.dart';

// ================================================
// CHANGES this round:
//   - Enable no longer closes the whole dialog — it now removes
//     just that one row and stays open, matching
//     customer_disabled_dialog.dart. Previously re-enabling one
//     account closed the entire list, forcing the admin to reopen
//     this dialog again for every additional account they wanted
//     to re-enable.
//   - Removed the redundant X close icon in the header — Cancel/
//     Close in the footer already does the same thing.
// ================================================

class AdminDisabledDialog extends StatefulWidget {
  final List<AdminAccount> disabledAccounts;
  final Function(AdminAccount) onEnable;

  const AdminDisabledDialog({
    super.key,
    required this.disabledAccounts,
    required this.onEnable,
  });

  @override
  State<AdminDisabledDialog> createState() => _AdminDisabledDialogState();
}

class _AdminDisabledDialogState extends State<AdminDisabledDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Local mutable copy — lets us remove a row immediately on Enable
  // without needing the parent screen to refetch and rebuild this
  // dialog from scratch.
  late List<AdminAccount> _accounts;

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
  List<AdminAccount> get _filtered {
    if (_searchQuery.isEmpty) return _accounts;
    return _accounts.where((a) {
      final name = '${a.firstName} ${a.lastName}'.toLowerCase();
      final email = a.email.toLowerCase();
      final role = a.role.toLowerCase();
      return name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          role.contains(_searchQuery);
    }).toList();
  }

  Future<void> _handleEnable(AdminAccount account) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Enable this account?',
      message:
          'This account will be re-enabled and the user '
          'will be able to log in again.',
      confirmLabel: 'Enable',
      confirmColor: const Color(0xFF16A34A),
    );

    if (confirmed != true) return;

    widget.onEnable(account);

    if (!mounted) return;
    setState(() {
      _accounts.removeWhere((a) => a.id == account.id);
    });
  }

  List<List<Widget>> _buildRows() {
    return _filtered.map((account) {
      return [
        Text(
          '${account.firstName} ${account.lastName}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
        Text(
          account.email,
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          account.role,
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
        const Text(
          '-',
          style: TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(
            onPressed: () => _handleEnable(account),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1100,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── HEADER ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
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
                    'Manage and review disabled admin accounts.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
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
                  hintText: 'Search by name, email, or role...',
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
                              'Role',
                              'Disabled Date',
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
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
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
                    child: const Text('Cancel', style: TextStyle(fontSize: 13)),
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