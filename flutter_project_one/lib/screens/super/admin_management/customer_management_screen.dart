import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/customer_account.dart';
import '../../../widgets/common/common_table.dart';
import '../../../widgets/common/search_bar.dart';
import '../../../widgets/common/filter_button.dart';
import '../../../widgets/common/filter_panel.dart';
import '../../../widgets/common/confirm_dialog.dart';
import '../../../widgets/super/admin_management/customer_edit_dialog.dart';
import '../../../widgets/super/admin_management/customer_disable_dialog.dart';
import '../../../widgets/super/admin_management/customer_disabled_dialog.dart';
import '../../../widgets/super/admin_management/customer_archived_dialog.dart';

// ================================================
// CUSTOMER MANAGEMENT SCREEN
//
// Super admin can:
//   - View all customer accounts
//   - Search and filter by status
//   - Edit & View customer details
//   - Disable a customer (with reason)
//   - Archive a customer
//   - View disabled accounts + Activate
//   - View archived accounts + Restore
//
// Follows feedback_screen.dart pattern exactly
// ================================================
class CustomerManagementScreen extends ConsumerStatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  ConsumerState<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState
    extends ConsumerState<CustomerManagementScreen> {

  // ================================================
  // CONTROLLERS AND STATE
  // ================================================
  final TextEditingController _searchController = TextEditingController();
  bool _showFilterPanel = false;
  String? _selectedStatus;

  // ================================================
  // DATA — replace with Supabase later
  // ================================================

  // active customers list
  final List<CustomerAccount> _allCustomers = [
    CustomerAccount(
      id: 'cust_001',
      firstName: 'Angel',
      lastName: 'Tuazon',
      email: 'TuazonAngel363@gmail.com',
      phone: '0991606274',
      address: 'Camarin Caloocan City',
      landmark: 'Alday Store',
      status: 'Active',
      lastLogin: '03-03-2026  09:30 am',
      registeredOn: '03-03-2026',
    ),
    CustomerAccount(
      id: 'cust_002',
      firstName: 'Jay',
      lastName: 'Galang',
      email: 'jaygalang@gmail.com',
      phone: '09171234567',
      address: 'Quezon City',
      landmark: 'Near SM North',
      status: 'Suspended',
      lastLogin: '02-28-2026  02:15 pm',
      registeredOn: '01-15-2026',
    ),
    CustomerAccount(
      id: 'cust_003',
      firstName: 'Maria',
      lastName: 'Santos',
      email: 'mariasantos@gmail.com',
      phone: '09281112222',
      address: 'Makati City',
      landmark: 'Ayala Mall',
      status: 'Inactive',
      lastLogin: '02-01-2026  10:00 am',
      registeredOn: '12-10-2025',
    ),
  ];

  // disabled customers list
  final List<CustomerAccount> _disabledCustomers = [
    CustomerAccount(
      id: 'cust_disabled_001',
      firstName: 'Angel',
      lastName: 'Tuazon',
      email: 'Angel363@gmail.com',
      phone: '0991606274',
      address: 'Camarin Caloocan City',
      landmark: 'Alday Store',
      status: 'Disabled',
      lastLogin: '03-03-2026  09:30 am',
      registeredOn: '03-03-2026',
      isDisabled: true,
      disabledDate: '2005/03/11',
      disableReason: 'violence',
    ),
  ];

  // archived customers list
  final List<CustomerAccount> _archivedCustomers = [
    CustomerAccount(
      id: 'cust_archived_001',
      firstName: 'Angel',
      lastName: 'Tuazon',
      email: 'Angel363@gmail.com',
      phone: '0991606274',
      address: 'Camarin Caloocan City',
      landmark: 'Alday Store',
      status: 'Archived',
      lastLogin: '03-03-2026  09:30 am',
      registeredOn: '03-03-2026',
      isArchived: true,
      archivedDate: '03-03-2026  09:30 am',
    ),
  ];

  // filtered list shown in table
  List<CustomerAccount> _filteredCustomers = [];

  // ================================================
  // INIT STATE
  // ================================================
  @override
  void initState() {
    super.initState();
    _filteredCustomers = _allCustomers;
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
  // follows feedback_screen.dart pattern
  // ================================================
  void _applyFilters() {
    String searchQuery = _searchController.text.toLowerCase();
    List<CustomerAccount> results = [];

    for (int i = 0; i < _allCustomers.length; i = i + 1) {
      CustomerAccount customer = _allCustomers[i];

      // skip archived or disabled
      if (customer.isArchived == true) continue;
      if (customer.isDisabled == true) continue;

      // search filter
      bool matchesSearch = true;
      if (searchQuery.isNotEmpty) {
        bool nameMatch = customer.fullName
            .toLowerCase()
            .contains(searchQuery);
        bool emailMatch = customer.email
            .toLowerCase()
            .contains(searchQuery);
        matchesSearch = nameMatch || emailMatch;
      }
      if (matchesSearch == false) continue;

      // status filter
      bool matchesStatus = true;
      if (_selectedStatus != null) {
        matchesStatus = customer.status == _selectedStatus;
      }
      if (matchesStatus == false) continue;

      results.add(customer);
    }

    setState(() {
      _filteredCustomers = results;
    });
  }

  // ================================================
  // CLEAR FILTERS
  // ================================================
  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _searchController.clear();
      _filteredCustomers = _allCustomers
          .where((c) => c.isArchived == false && c.isDisabled == false)
          .toList();
      _showFilterPanel = false;
    });
  }

  // ================================================
  // HANDLE DISABLE
  // opens disable dialog → gets reason → disables
  // ================================================
  void _handleDisable(CustomerAccount customer) {
    showCustomerDisableDialog(
      context: context,
      account: customer,
      onDisable: (String reason) {
        setState(() {

          // add to disabled list
          _disabledCustomers.add(CustomerAccount(
            id: customer.id,
            firstName: customer.firstName,
            lastName: customer.lastName,
            email: customer.email,
            phone: customer.phone,
            address: customer.address,
            landmark: customer.landmark,
            status: 'Disabled',
            lastLogin: customer.lastLogin,
            registeredOn: customer.registeredOn,
            isDisabled: true,
            disabledDate: DateTime.now().toString().substring(0, 10),
            disableReason: reason,
          ));

          // remove from active list
          _allCustomers.removeWhere((c) => c.id == customer.id);

          _applyFilters();
        });
      },
    );
  }

  // ================================================
  // HANDLE ARCHIVE
  // uses ConfirmDialog before archiving
  // ================================================
  Future<void> _handleArchive(CustomerAccount customer) async {
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Archive this account?',
      message:
          '${customer.fullName} will be archived and will no longer '
          'be able to log in.',
      confirmLabel: 'Archive',
      confirmColor: const Color(0xFFEF4444),
    );

    if (confirmed != true) return;

    setState(() {

      // add to archived list
      _archivedCustomers.add(CustomerAccount(
        id: customer.id,
        firstName: customer.firstName,
        lastName: customer.lastName,
        email: customer.email,
        phone: customer.phone,
        address: customer.address,
        landmark: customer.landmark,
        status: 'Archived',
        lastLogin: customer.lastLogin,
        registeredOn: customer.registeredOn,
        isArchived: true,
        archivedDate: DateTime.now().toString().substring(0, 10),
      ));

      // remove from active list
      _allCustomers.removeWhere((c) => c.id == customer.id);

      _applyFilters();
    });
  }

  // ================================================
  // HANDLE ACTIVATE (from disabled dialog)
  // ================================================
  void _handleActivate(CustomerAccount disabledAccount) {
    setState(() {

      // add back to active list
      _allCustomers.add(CustomerAccount(
        id: disabledAccount.id,
        firstName: disabledAccount.firstName,
        lastName: disabledAccount.lastName,
        email: disabledAccount.email,
        phone: disabledAccount.phone,
        address: disabledAccount.address,
        landmark: disabledAccount.landmark,
        status: 'Active',
        lastLogin: disabledAccount.lastLogin,
        registeredOn: disabledAccount.registeredOn,
      ));

      // remove from disabled list
      _disabledCustomers.removeWhere((c) => c.id == disabledAccount.id);

      _applyFilters();
    });
  }

  // ================================================
  // HANDLE RESTORE (from archived dialog)
  // ================================================
  void _handleRestore(CustomerAccount archivedAccount) {
    setState(() {

      // add back to active list
      _allCustomers.add(CustomerAccount(
        id: archivedAccount.id,
        firstName: archivedAccount.firstName,
        lastName: archivedAccount.lastName,
        email: archivedAccount.email,
        phone: archivedAccount.phone,
        address: archivedAccount.address,
        landmark: archivedAccount.landmark,
        status: 'Active',
        lastLogin: archivedAccount.lastLogin,
        registeredOn: archivedAccount.registeredOn,
      ));

      // remove from archived list
      _archivedCustomers.removeWhere((c) => c.id == archivedAccount.id);

      _applyFilters();
    });
  }

  // ================================================
  // BUILD STATUS BADGE
  // Active = green, Suspended = red, Inactive = yellow
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

    if (status == 'Suspended') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFDC2626);
      borderColor = const Color(0xFFFCA5A5);
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
  // BUILD 3-DOT MENU ACTION
  // Edit & View / Disable / Archive
  // ================================================
  Widget _buildActionMenu(CustomerAccount customer) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_vert,
          size: 20,
          color: Color(0xFF6B7280),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        elevation: 4,
        onSelected: (String value) {
          if (value == 'edit') {
            showCustomerEditDialog(
              context: context,
              account: customer,
              onSave: (CustomerAccount updated) {
                setState(() {
                  for (int i = 0; i < _allCustomers.length; i = i + 1) {
                    if (_allCustomers[i].id == updated.id) {
                      _allCustomers[i] = updated;
                      break;
                    }
                  }
                  _applyFilters();
                });
              },
            );
          }
          if (value == 'disable') {
            _handleDisable(customer);
          }
          if (value == 'archive') {
            _handleArchive(customer);
          }
        },
        itemBuilder: (BuildContext ctx) {
          return [

            // edit & view
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: const [
                  Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: Color(0xFF374151),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Edit & View',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),

            // disable
            PopupMenuItem<String>(
              value: 'disable',
              child: Row(
                children: const [
                  Icon(
                    Icons.person_off_outlined,
                    size: 15,
                    color: Color(0xFF374151),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Disable',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),

            // archive
            PopupMenuItem<String>(
              value: 'archive',
              child: Row(
                children: const [
                  Icon(
                    Icons.archive_outlined,
                    size: 15,
                    color: Color(0xFF374151),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Archive',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );
  }

  // ================================================
  // BUILD TABLE ROWS
  // follows feedback_screen.dart _buildRows() pattern
  // ================================================
  List<List<Widget>> _buildRows() {
    List<List<Widget>> tableRows = [];

    for (int i = 0; i < _filteredCustomers.length; i = i + 1) {
      CustomerAccount customer = _filteredCustomers[i];

      List<Widget> oneRow = [

        // column 1 — full name
        Text(
          customer.fullName,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 2 — email
        Text(
          customer.email,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
          overflow: TextOverflow.ellipsis,
        ),

        // column 3 — status badge
        _buildStatusBadge(customer.status),

        // column 4 — last login
        Text(
          customer.lastLogin,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 5 — registered on
        Text(
          customer.registeredOn,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 6 — 3-dot action menu
        _buildActionMenu(customer),
      ];

      tableRows.add(oneRow);
    }

    return tableRows;
  }

  // ================================================
  // BUILD
  // follows feedback_screen.dart build() pattern
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

              // ── TOP ROW — TITLE + BUTTONS ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // title + subtitle
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Account Management',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage customer accounts and permissions.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // search bar
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search',
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
                    selectedValue: _selectedStatus,
                    onValueChanged: (String? value) {
                      setState(() {
                        _selectedStatus = value;
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
                        title: 'Status',
                        options: [
                          FilterOption(label: 'Active', value: 'Active'),
                          FilterOption(
                            label: 'Suspended',
                            value: 'Suspended',
                          ),
                          FilterOption(label: 'Inactive', value: 'Inactive'),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(width: 8),

                  // disabled account button
                  ElevatedButton(
                    onPressed: () {
                      showCustomerDisabledDialog(
                        context: context,
                        disabledAccounts: _disabledCustomers,
                        onActivate: _handleActivate,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
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
                      'Disabled Account',
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
                      showCustomerArchivedDialog(
                        context: context,
                        archivedAccounts: _archivedCustomers,
                        onRestore: _handleRestore,
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

              const SizedBox(height: 24),

              // ── TABLE ──
              Expanded(
                child: SingleChildScrollView(
                  child: CommonTable(
                    headers: const [
                      'Name',
                      'Email',
                      'Status',
                      'Last Login',
                      'Registered On',
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