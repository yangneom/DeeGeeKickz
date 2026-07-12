import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/customer_account.dart';
import '../../../widgets/common/tables/common_table.dart';
import '../../../widgets/common/buttons/search_bar.dart';
import '../../../widgets/common/buttons/filter_button.dart';
import '../../../widgets/common/buttons/filter_panel.dart';
import '../../../widgets/super/admin_management/customer_edit_dialog.dart';
import '../../../widgets/super/admin_management/customer_disabled_dialog.dart';
import '../../../providers/super/customer_account_provider.dart';

// ================================================
// CUSTOMER MANAGEMENT SCREEN
//
// Super admin can:
//   - View all customer accounts (fetched from Supabase)
//   - Search and filter by status
//   - View customer details (view-only)
//   - Disable a customer (with reason)
//   - View disabled accounts + Activate
// ================================================
class CustomerManagementScreen extends ConsumerStatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  ConsumerState<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState
    extends ConsumerState<CustomerManagementScreen> {

  final TextEditingController _searchController = TextEditingController();
  bool _showFilterPanel = false;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(customerAccountsProvider.notifier).loadAccounts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ================================================
  // FILTER ACTIVE CUSTOMERS FOR MAIN TABLE
  // (search + status, always excludes disabled)
  // ================================================
  List<CustomerAccount> _filteredActiveCustomers(
    List<CustomerAccount> allCustomers,
  ) {
    final searchQuery = _searchController.text.toLowerCase();

    return allCustomers.where((customer) {
      if (customer.isDisabled) return false;

      if (searchQuery.isNotEmpty) {
        final nameMatch = customer.fullName.toLowerCase().contains(searchQuery);
        final emailMatch = customer.email.toLowerCase().contains(searchQuery);
        if (!nameMatch && !emailMatch) return false;
      }

      if (_selectedStatus != null && customer.status != _selectedStatus) {
        return false;
      }

      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _searchController.clear();
      _showFilterPanel = false;
    });
  }

  // ================================================
  // HANDLE DISABLE
  // ================================================
  Future<void> _handleDisable(CustomerAccount customer, String reason) async {
    await ref
        .read(customerAccountsProvider.notifier)
        .disableAccount(customer.id, reason: reason);
  }

  // ================================================
  // HANDLE ACTIVATE
  // ================================================
  Future<void> _handleActivate(CustomerAccount customer) async {
    await ref
        .read(customerAccountsProvider.notifier)
        .enableAccount(customer.id);
  }

  // ================================================
  // BUILD STATUS BADGE
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

    if (status == 'Disabled') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFDC2626);
      borderColor = const Color(0xFFFCA5A5);
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
  // BUILD 3-DOT MENU ACTION — View & Disable only
  // ================================================
  Widget _buildActionMenu(CustomerAccount customer) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF6B7280)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        elevation: 4,
        onSelected: (String value) {
          if (value == 'view') {
            showCustomerEditDialog(
              context: context,
              account: customer,
              onDisable: (String reason) => _handleDisable(customer, reason),
            );
          }
        },
        itemBuilder: (BuildContext ctx) {
          return [
            PopupMenuItem<String>(
              value: 'view',
              child: Row(
                children: const [
                  Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF374151)),
                  SizedBox(width: 8),
                  Text('View', style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
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
  // ================================================
  List<List<Widget>> _buildRows(List<CustomerAccount> customers) {
    List<List<Widget>> tableRows = [];

    for (final customer in customers) {
      tableRows.add([
        Text(customer.fullName, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
        Text(
          customer.email,
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
          overflow: TextOverflow.ellipsis,
        ),
        _buildStatusBadge(customer.status),
        Text(customer.lastLogin, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
        Text(customer.registeredOn, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
        _buildActionMenu(customer),
      ]);
    }

    return tableRows;
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    final allCustomers = ref.watch(customerAccountsProvider);
    final activeCustomers = _filteredActiveCustomers(allCustomers);
    final disabledCustomers =
        allCustomers.where((c) => c.isDisabled).toList();

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
                    'Customer Account Management',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage customer accounts and permissions.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search customers...',
                    onChanged: (String value) => setState(() {}),
                  ),

                  const SizedBox(width: 8),

                  FilterButton(
                    isOpen: _showFilterPanel,
                    onTap: () => setState(() => _showFilterPanel = !_showFilterPanel),
                    selectedValue: _selectedStatus,
                    onValueChanged: (String? value) => setState(() => _selectedStatus = value),
                    onClear: _clearFilters,
                    onApply: () => setState(() => _showFilterPanel = false),
                    sections: [
                      FilterSection(
                        title: 'Status',
                        options: [
                          FilterOption(label: 'Active', value: 'Active'),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // disabled account button
                  ElevatedButton(
                    onPressed: () {
                      showCustomerDisabledDialog(
                        context: context,
                        disabledAccounts: disabledCustomers,
                        onActivate: _handleActivate,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Disabled Account',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

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
                    rows: _buildRows(activeCustomers),
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