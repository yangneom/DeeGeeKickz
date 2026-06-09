import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/common/common_table.dart';
import '../../../widgets/common/search_bar.dart';
import '../../../widgets/common/filter_button.dart';
import '../../../widgets/common/filter_panel.dart';
import '../../../widgets/super/admin_management/admin_edit_dialog.dart';
import '../../../widgets/super/admin_management/admin_archived_dialog.dart';
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

  // ================================================
  // CONTROLLERS AND STATE
  // ================================================
  final TextEditingController _searchController = TextEditingController();
  bool _showFilterPanel = false;
  String? _selectedRole;
  String? _selectedStatus;

  // ================================================
  // INIT STATE
  // ================================================
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(adminAccountsProvider.notifier).loadAccounts();
    });
  }

  // ================================================
  // DISPOSE
  // ================================================
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ================================================
  // APPLY FILTERS
  // ================================================
  void _applyFilters() {}

  // ================================================
  // CLEAR FILTERS
  // ================================================
  void _clearFilters() {
    setState(() {
      _selectedRole = null;
      _selectedStatus = null;
      _searchController.clear();
      _showFilterPanel = false;
    });
  }

  // ================================================
  // BUILD STATUS BADGE
  // same pattern as feedback_screen
  // ================================================
  Widget _buildStatusBadge(String status) {

    print('ADMIN MANAGEMENT SCREEN BUILDING');

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
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // ================================================
  // HANDLE ARCHIVE
  // ================================================
  Future<void> _handleArchive(
        AdminAccount account,
      ) async {

        print('====================');
        print('ARCHIVE BUTTON CLICKED');
        print('EMAIL = ${account.email}');
        print('USER ID = ${account.id}');
        print('====================');

        await ref
            .read(adminAccountsProvider.notifier)
            .archiveAccount(account.id);

        if (mounted) {
          await ref
              .read(adminAccountsProvider.notifier)
              .loadAccounts();
        }
      }

  // ================================================
  // HANDLE RESTORE
  // ================================================
  Future<void> _handleRestore(
    AdminAccount account,
  ) async {
    await ref
        .read(adminAccountsProvider.notifier)
        .restoreAccount(account.id);

    if (mounted) {
      ref.read(adminAccountsProvider.notifier)
         .loadAccounts();
    }
  }

  // ================================================
  // BUILD TABLE ROWS
  // ================================================
      List<List<Widget>> _buildRows(
      List<AdminAccount> accounts,
    ) {

      print('========== BUILD ROWS ==========');

      for (final account in accounts) {
        print(
          'NAME=${account.firstName} ${account.lastName} | '
          'EMAIL=${account.email} | '
          'ROLE=${account.role} | '
          'ARCHIVED=${account.isArchived}',
        );
      }

      print('===============================');

      List<List<Widget>> tableRows = [];

      for (final account in accounts) {

        print(
          'BUILDING ROW -> '
          'ID=${account.id} | '
          '${account.firstName} '
          '${account.lastName} | '
          '${account.email} | '
          '${account.role}',
        );

      List<Widget> oneRow = [

        // column 1 — full name
        Text(
          '${account.firstName} ${account.lastName}',
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

        // column 3 — role
        Text(
          account.role,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 4 — status badge
        _buildStatusBadge(
          account.isArchived ? 'Inactive' : 'Active',
        ),

        // column 5 — last login (placeholder until field exists)
        const Text(
          '-',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 6 — action buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [

            // edit & view button
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () {
                showAdminEditDialog(
                  context,
                  account,
                  (AdminAccount updatedAccount) async {
                    await ref
                        .read(adminAccountsProvider.notifier)
                        .updateAccount(updatedAccount);
                  },
                );
              },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Edit & View',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // archive button
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: () async {
                  print('RED BUTTON PRESSED');
                  await _handleArchive(account);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Archive',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ];

      tableRows.add(oneRow);
    }

    return tableRows;
  }

  // ================================================
  // BUILD
  // same pattern as feedback_screen build()
  // ================================================
  @override
  Widget build(BuildContext context) {

    final accounts = ref.watch(adminAccountsProvider);

    print('========== UI RECEIVED ACCOUNTS ==========');

    for (final account in accounts) {
      print(
        '${account.email} | '
        '${account.role} | '
        'archived=${account.isArchived}',
      );
    }

    print('=========================================');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: GestureDetector(

        // close filter panel when tapping outside
        onTap: () {
          if (_showFilterPanel == true) {
            setState(() {
              _showFilterPanel = false;
            });
          }
        },

        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── TITLE ──
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Account Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage admin accounts and permissions.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── SEARCH + FILTER + ADD + ARCHIVED ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // search bar
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search accounts...',
                    onChanged: (String value) {
                      _applyFilters();
                    },
                  ),

                  const SizedBox(width: 8),

                  // filter button
                  FilterButton(
                    isOpen: _showFilterPanel,
                    onTap: () {
                      setState(() {
                        _showFilterPanel = !_showFilterPanel;
                      });
                    },
                    selectedValue: _selectedRole,
                    onValueChanged: (String? value) {
                      setState(() {
                        _selectedRole = value;
                      });
                    },
                    onClear: _clearFilters,
                    onApply: () {
                      _applyFilters();
                      setState(() {
                        _showFilterPanel = false;
                      });
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

                  // add account button
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
                        final provider =
                            ref.read(adminAccountsProvider.notifier);

                        await provider.createAccount(
                          firstName: firstName,
                          lastName: lastName,
                          email: email,
                          password: 'TempPassword123!',
                          role: role,
                        );
                      },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Add Account',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // archived button
                  ElevatedButton(
                    onPressed: () async {
                      await ref
                          .read(adminAccountsProvider.notifier)
                          .loadAccounts();

                      if (!mounted) return;

                      // Read AFTER the await, so state is fresh
                      final archivedAccounts = ref
                          .read(adminAccountsProvider)
                          .where((a) => a.isArchived)
                          .toList();

                      showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AdminArchivedDialog(
                            archivedAccounts: archivedAccounts,
                            onRestore: _handleRestore,
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CA3AF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Archived',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── TABLE ──
              Expanded(
                child: SingleChildScrollView(
                  child: CommonTable(
                    headers: const [
                      'Name',
                      'Email',
                      'Role',
                      'Status',
                      'Last Login',
                      'Action',
                    ],
                    rows: _buildRows(
                      accounts
                          .where((a) =>
                              !a.isArchived &&
                              (a.role == 'Admin' ||
                              a.role == 'Cashier' ||
                              a.role == 'Super Admin'))
                          .toList(),
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