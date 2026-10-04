import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/common/tables/common_table.dart';
import '../../../widgets/common/buttons/search_bar.dart';
import '../../../widgets/common/buttons/filter_button.dart';
import '../../../widgets/common/buttons/filter_panel.dart';
import '../../../widgets/common/dialog/confirm_dialog.dart';
import '../../../widgets/super/admin_management/admin_edit_dialog.dart';
import '../../../widgets/super/admin_management/admin_disabled_dialog.dart';
import '../../../widgets/super/admin_management/admin_add_dialog.dart';
import '../../../providers/admin_provider/admin_account_provider.dart';
import '../../../models/admin_account.dart';

class AdminManagementScreen extends ConsumerStatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  ConsumerState<AdminManagementScreen> createState() =>
      _AdminManagementScreenState();
}

class _AdminManagementScreenState
    extends ConsumerState<AdminManagementScreen> {

  final TextEditingController _searchController = TextEditingController();
  bool _showFilterPanel = false;
  String? _selectedRole;
  String? _selectedStatus;

  // Staged selections — chip taps only touch these until Apply commits
  // them into _selectedRole/_selectedStatus (which _filteredAccounts
  // actually reads).
  String? _pendingRole;
  String? _pendingStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(adminAccountsProvider.notifier).loadAccounts();
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty || raw == '-') return '-';
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final DateTime local = parsed.toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    int hour12 = local.hour % 12;
    if (hour12 == 0) hour12 = 12;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year}, $hour12:$minute $period';
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _applyFilters() {
    setState(() {});
  }

  List<AdminAccount> _filteredAccounts(List<AdminAccount> accounts) {
    final String query = _searchController.text.toLowerCase();

    return accounts.where((account) {
      if (query.isNotEmpty) {
        final bool nameMatch = '${account.firstName} ${account.lastName}'
            .toLowerCase()
            .contains(query);
        final bool emailMatch = account.email.toLowerCase().contains(query);
        if (!nameMatch && !emailMatch) return false;
      }

      if (_selectedRole != null && account.role != _selectedRole) {
        return false;
      }

      if (_selectedStatus != null) {
        final String status = account.isDisabled ? 'Inactive' : 'Active';
        if (status != _selectedStatus) return false;
      }

      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedRole = null;
      _selectedStatus = null;
      _pendingRole = null;
      _pendingStatus = null;
      _searchController.clear();
      _showFilterPanel = false;
    });
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor = Colors.grey.shade100;
    Color textColor = Colors.grey;
    Color borderColor = Colors.grey.shade300;

    if (status == 'Active') {
      backgroundColor = const Color(0xFFD1FAE5);
      textColor = const Color(0xFF065F46);
      borderColor = const Color(0xFF6EE7B7);
    }

    if (status == 'Inactive') {
      backgroundColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFF92400E);
      borderColor = const Color(0xFFFCD34D);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          status,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor),
        ),
      ),
    );
  }

  // ================================================
  // HANDLE DISABLE — now confirm-gated, matching the same
  // "are you sure?" pattern used for Order Approval's status
  // buttons. A one-tap red "Disable" with no confirmation was a
  // real safety gap for a staff account.
  // ================================================
  Future<void> _handleDisable(AdminAccount account) async {
    final bool? confirmed = await showConfirmDialog(
      context:      context,
      title:        'Disable this account?',
      message:      '${account.firstName} ${account.lastName} will lose access immediately. You can re-enable them later from Disabled Accounts.',
      confirmLabel: 'Disable',
      confirmColor: const Color(0xFFDC2626),
    );
    if (confirmed != true) return;

    try {
      // Notifier's disableAccount() already calls loadAccounts()
      // internally — the extra explicit call here was a redundant
      // second network round-trip, removed.
      await ref.read(adminAccountsProvider.notifier).disableAccount(account.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${account.firstName} ${account.lastName} disabled successfully.'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ================================================
  // HANDLE RESET MFA — Super Admin only (enforced server-side by
  // the reset-mfa Edge Function itself), confirm-gated since this
  // is a high-trust action that immediately locks the target out of
  // whatever device they were using until they re-enroll.
  // ================================================
  Future<void> _handleResetMfa(AdminAccount account) async {
    final bool? confirmed = await showConfirmDialog(
      context:      context,
      title:        'Reset 2FA for this account?',
      message:      '${account.firstName} ${account.lastName} will need to set up '
          'two-factor authentication again on their next login. Only do this if '
          'they\'ve genuinely lost access to their authenticator device.',
      confirmLabel: 'Reset 2FA',
      confirmColor: const Color(0xFFDC2626),
    );
    if (confirmed != true) return;

    try {
      await ref.read(adminAccountsProvider.notifier).resetMfa(account.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('2FA reset for ${account.firstName} ${account.lastName}.'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleEnable(AdminAccount account) async {
    try {
      // enableAccount() already refreshes the list internally.
      await ref.read(adminAccountsProvider.notifier).enableAccount(account.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${account.firstName} ${account.lastName} enabled successfully.'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<List<Widget>> _buildRows(List<AdminAccount> accounts) {
    List<List<Widget>> tableRows = [];

    for (final account in accounts) {
      List<Widget> oneRow = [
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
        Text(
          _formatDateTime(account.lastLogin),
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
        Text(
          _formatDateTime(account.registeredOn),
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280), size: 20),
            tooltip: 'Actions',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (String value) {
              if (value == 'edit') {
                showAdminEditDialog(
                  context,
                  account,
                  (AdminAccount updatedAccount) async {
                    await ref.read(adminAccountsProvider.notifier).updateAccount(updatedAccount);
                  },
                );
              } else if (value == 'reset_mfa') {
                _handleResetMfa(account);
              } else if (value == 'disable') {
                _handleDisable(account);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit & View', style: TextStyle(fontSize: 13)),
              ),
            if (account.role == 'Admin' || account.role == 'Super Admin' || account.role == 'Cashier')
                const PopupMenuItem(
                  value: 'reset_mfa',                  child: Text('Reset 2FA', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                ),
              const PopupMenuItem(
                value: 'disable',
                child: Text('Disable', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
              ),
            ],
          ),
        ),
      ];

      tableRows.add(oneRow);
    }

    return tableRows;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(adminAccountsProvider);
        final visibleAccounts = accounts
        .where((a) => a.role == 'Admin' || a.role == 'Cashier')
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: GestureDetector(
        onTap: () {
          if (_showFilterPanel == true) {
            setState(() => _showFilterPanel = false);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Account Management',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage admin accounts and permissions.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── STAT CARDS — matching Customer Management's standard ──
              Row(
                children: [
                  Expanded(child: _buildStatCard('Total Accounts', visibleAccounts.length, const Color(0xFF2563EB))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Active', visibleAccounts.where((a) => !a.isDisabled).length, const Color(0xFF16A34A))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Disabled', visibleAccounts.where((a) => a.isDisabled).length, const Color(0xFFDC2626))),
                ],
              ),

              const SizedBox(height: 24),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search accounts...',
                    onChanged: (String value) => _applyFilters(),
                  ),

                  const SizedBox(width: 8),

                  FilterButton(
                    isOpen: _showFilterPanel,
                    onTap: () {
                      setState(() {
                        _pendingRole = _selectedRole;
                        _pendingStatus = _selectedStatus;
                        _showFilterPanel = !_showFilterPanel;
                      });
                    },
                    selectedValues: {
                      'Role': _pendingRole,
                      'Status': _pendingStatus,
                    },
                    onValueChanged: (String section, String? value) {
                      setState(() {
                        if (section == 'Role') _pendingRole = value;
                        if (section == 'Status') _pendingStatus = value;
                      });
                    },
                    onClear: _clearFilters,
                    onApply: () {
                      setState(() {
                        _selectedRole = _pendingRole;
                        _selectedStatus = _pendingStatus;
                        _showFilterPanel = false;
                      });
                      _applyFilters();
                    },
                    sections: [
                      FilterSection(
                        title: 'Role',
                        options: [
                          FilterOption(label: 'Admin', value: 'Admin'),
                          FilterOption(label: 'Cashier', value: 'Cashier'),
                        ],
                      ),
                      FilterSection(
                        title: 'Status',
                        options: [
                          FilterOption(label: 'Active', value: 'Active'),
                          FilterOption(label: 'Inactive', value: 'Inactive'),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  ElevatedButton(
                    onPressed: () {
                      showAdminAddDialog(
                        context,
                        ({
                          required String firstName,
                          required String lastName,
                          required String email,
                          required String role,
                        }) async {
                          final provider = ref.read(adminAccountsProvider.notifier);
                          await provider.createAccount(
                            firstName: firstName,
                            lastName: lastName,
                            email: email,
                            role: role,
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Add Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),

                  const SizedBox(width: 8),

                  ElevatedButton(
                    onPressed: () async {
                      await ref.read(adminAccountsProvider.notifier).loadAccounts();
                      if (!mounted) return;

                      final disabledAccounts = ref
                          .read(adminAccountsProvider)
                          .where((a) => a.isDisabled)
                          .toList();

                      showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AdminDisabledDialog(
                            disabledAccounts: disabledAccounts,
                            onEnable: _handleEnable,
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CA3AF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Disabled Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : SingleChildScrollView(
                        child: CommonTable(
                          headers: const [
                            'Name',
                            'Email',
                            'Role',
                            'Last Login',
                            'Registered On',
                            'Action',
                          ],
                          columnFlex: const [2, 3, 1, 2, 2, 2],
                          rows: _buildRows(
                            _filteredAccounts(
                              visibleAccounts.where((a) => !a.isDisabled).toList(),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}