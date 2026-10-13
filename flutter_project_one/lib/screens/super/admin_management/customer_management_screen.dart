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
import '../../../widgets/common/dialog/app_toast.dart';

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

    // Staged — same reasoning as Admin Management: build() reads
  // _selectedStatus directly, so a chip tap alone would refilter
  // instantly without this.
  String? _pendingStatus;

  bool _isLoading = true;

   @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(customerAccountsProvider.notifier).loadAccounts();
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      _pendingStatus = null;
      _searchController.clear();
      _showFilterPanel = false;
    });
  }

 

  // ================================================
  // HANDLE ACTIVATE
  // ================================================
  // Called only from the Suspended / Banned dialog, which shows the success
  // or failure toast and removes the row only if this succeeds. Errors must
  // propagate, so they are not caught here.
  Future<void> _handleActivate(CustomerAccount customer) async {
    await ref
        .read(customerAccountsProvider.notifier)
        .enableAccount(customer.id);
  }
  Widget _buildPresenceCell(CustomerAccount customer) {
    if (customer.isOnline) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: const Text('Online',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF16A34A))),
        ),
      );
    }
     return Text(_formatDateTime(customer.lastLogin), style: const TextStyle(fontSize: 13, color: Color(0xFF111827)));
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

   Widget _buildActionMenu(CustomerAccount customer) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        onPressed: () => showCustomerEditDialog(context: context, account: customer),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF374151),
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: const Text('View', style: TextStyle(fontSize: 12)),
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
       _buildPresenceCell(customer),
        Text(_formatDateTime(customer.registeredOn), style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
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
                children: [
                  Expanded(child: _buildStatCard('Total Customers', allCustomers.length, const Color(0xFF2563EB))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Active', allCustomers.where((c) => !c.isDisabled).length, const Color(0xFF16A34A))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Currently Warned', allCustomers.where((c) => c.banTier == 1).length, const Color(0xFFF59E0B))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Suspended / Banned', allCustomers.where((c) => c.isDisabled).length, const Color(0xFFDC2626))),
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
                    onTap: () => setState(() {
                      _pendingStatus = _selectedStatus;
                      _showFilterPanel = !_showFilterPanel;
                    }),
                    selectedValues: {
                      'Status': _pendingStatus,
                    },
                    onValueChanged: (String section, String? value) =>
                        setState(() => _pendingStatus = value),
                    onClear: _clearFilters,
                    onApply: () => setState(() {
                      _selectedStatus = _pendingStatus;
                      _showFilterPanel = false;
                    }),
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
                    OutlinedButton(
                    onPressed: () {
                      showCustomerDisabledDialog(
                        context: context,
                        disabledAccounts: disabledCustomers,
                        onActivate: _handleActivate,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Suspended / Banned Accounts (${disabledCustomers.length})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
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
                            'Last Login',
                            'Registered On',
                            'Action',
                          ],
                         columnFlex: const [2, 3, 2, 2, 1],
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