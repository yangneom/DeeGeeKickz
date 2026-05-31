import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/common/common_table.dart';
import '../../../widgets/common/search_bar.dart';
import '../../../widgets/common/filter_button.dart';
import '../../../widgets/common/filter_panel.dart';
import '../../../widgets/common/confirm_dialog.dart';
import '../../../widgets/super/admin_management/admin_edit_dialog.dart';
import '../../../widgets/super/admin_management/admin_archived_dialog.dart';

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
  // FAKE DATA — replace with Supabase later
  // ================================================
  final List<Map<String, dynamic>> _allAccounts = [
    {
      'id': 'acc_001',
      'firstName': 'Angel',
      'lastName': 'Tuazon',
      'email': 'TuazonAngel363@gmail.com',
      'phone': '0991606274',
      'role': 'Cashier',
      'status': 'Active',
      'lastLogin': '03-03-2026  09:30 am',
      'isArchived': false,
    },
    {
      'id': 'acc_002',
      'firstName': 'Jay',
      'lastName': 'Galang',
      'email': 'jaygalang@gmail.com',
      'phone': '09171234567',
      'role': 'Admin',
      'status': 'Inactive',
      'lastLogin': '02-28-2026  02:15 pm',
      'isArchived': false,
    },
    {
      'id': 'acc_003',
      'firstName': 'Maria',
      'lastName': 'Santos',
      'email': 'mariasantos@gmail.com',
      'phone': '09281112222',
      'role': 'Admin',
      'status': 'Active',
      'lastLogin': '03-01-2026  10:00 am',
      'isArchived': false,
    },
  ];

  // archived accounts
  final List<Map<String, dynamic>> _archivedAccounts = [
    {
      'id': 'acc_archived_001',
      'firstName': 'Angel',
      'lastName': 'Tuazon',
      'email': 'Angel363@gmail.com',
      'role': 'Cashier',
      'archiveDate': '03-03-2026  09:30 am',
    },
  ];

  // filtered list shown in table
  List<Map<String, dynamic>> _filteredAccounts = [];

  // ================================================
  // INIT STATE
  // ================================================
  @override
  void initState() {
    super.initState();
    _filteredAccounts = _allAccounts;
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
  // same pattern as feedback_screen.dart
  // ================================================
  void _applyFilters() {
    String searchQuery = _searchController.text.toLowerCase();
    List<Map<String, dynamic>> results = [];

    for (int i = 0; i < _allAccounts.length; i = i + 1) {
      Map<String, dynamic> item = _allAccounts[i];

      // skip archived accounts
      if (item['isArchived'] == true) continue;

      // search filter
      bool matchesSearch = true;
      if (searchQuery.isNotEmpty) {
        bool nameMatch =
            '${item['firstName']} ${item['lastName']}'
                .toLowerCase()
                .contains(searchQuery);
        bool emailMatch =
            item['email'].toString().toLowerCase().contains(searchQuery);
        matchesSearch = nameMatch || emailMatch;
      }
      if (matchesSearch == false) continue;

      // role filter
      bool matchesRole = true;
      if (_selectedRole != null) {
        matchesRole = item['role'] == _selectedRole;
      }
      if (matchesRole == false) continue;

      // status filter
      bool matchesStatus = true;
      if (_selectedStatus != null) {
        matchesStatus = item['status'] == _selectedStatus;
      }
      if (matchesStatus == false) continue;

      results.add(item);
    }

    setState(() {
      _filteredAccounts = results;
    });
  }

  // ================================================
  // CLEAR FILTERS
  // ================================================
  void _clearFilters() {
    setState(() {
      _selectedRole = null;
      _selectedStatus = null;
      _searchController.clear();
      _filteredAccounts = _allAccounts
          .where((a) => a['isArchived'] == false)
          .toList();
      _showFilterPanel = false;
    });
  }

  // ================================================
  // BUILD STATUS BADGE
  // same pattern as feedback_screen
  // ================================================
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
  Future<void> _handleArchive(Map<String, dynamic> account) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Archive this account?',
      message:
          'This account will be archived and the user '
          'will no longer be able to log in.',
      confirmLabel: 'Archive',
      confirmColor: const Color(0xFFEF4444),
    );

    if (confirmed == true) {
      setState(() {

        // move to archived
        _archivedAccounts.add({
          'id': account['id'],
          'firstName': account['firstName'],
          'lastName': account['lastName'],
          'email': account['email'],
          'role': account['role'],
          'archiveDate': '03-03-2026  09:30 am',
        });

        // remove from active
        for (int i = 0; i < _allAccounts.length; i = i + 1) {
          if (_allAccounts[i]['id'] == account['id']) {
            _allAccounts[i]['isArchived'] = true;
            break;
          }
        }

        _applyFilters();
      });
    }
  }

  // ================================================
  // HANDLE RESTORE
  // ================================================
  void _handleRestore(Map<String, dynamic> archivedAccount) {
    setState(() {

      // restore in active list
      for (int i = 0; i < _allAccounts.length; i = i + 1) {
        if (_allAccounts[i]['id'] == archivedAccount['id']) {
          _allAccounts[i]['isArchived'] = false;
          break;
        }
      }

      // remove from archived list
      _archivedAccounts.removeWhere(
        (a) => a['id'] == archivedAccount['id'],
      );

      _applyFilters();
    });
  }

  // ================================================
  // BUILD TABLE ROWS
  // same pattern as feedback_screen _buildRows()
  // ================================================
  List<List<Widget>> _buildRows() {
    List<List<Widget>> tableRows = [];

    for (int i = 0; i < _filteredAccounts.length; i = i + 1) {
      Map<String, dynamic> account = _filteredAccounts[i];

      List<Widget> oneRow = [

        // column 1 — full name
        Text(
          '${account['firstName']} ${account['lastName']}',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 2 — email
        Text(
          account['email'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
          overflow: TextOverflow.ellipsis,
        ),

        // column 3 — role
        Text(
          account['role'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 4 — status badge
        _buildStatusBadge(account['status']),

        // column 5 — last login
        Text(
          account['lastLogin'],
          style: const TextStyle(
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
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AdminEditDialog(
                        account: account,
                        onSave: (Map<String, dynamic> updatedAccount) {
                          setState(() {
                            for (int j = 0;
                                j < _allAccounts.length;
                                j = j + 1) {
                              if (_allAccounts[j]['id'] == account['id']) {
                                _allAccounts[j] = {
                                  ..._allAccounts[j],
                                  ...updatedAccount,
                                };
                                break;
                              }
                            }
                            _applyFilters();
                          });
                        },
                      );
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
                onPressed: () => _handleArchive(account),
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
                      // TODO: show add account dialog
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
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AdminArchivedDialog(
                            archivedAccounts: _archivedAccounts,
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
                    rows: _buildRows(),
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