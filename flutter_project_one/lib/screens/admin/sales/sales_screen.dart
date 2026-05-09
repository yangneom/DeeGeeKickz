import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/sales_order.dart';
import '../../../widgets/admin/sales/sales_table.dart';
import '../../../widgets/common/search_bar.dart';
import '../../../widgets/common/filter_button.dart';
import '../../../widgets/common/filter_panel.dart';
import '../../../widgets/common/export_button.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {

  // ================================================
  // CONTROLLERS AND STATE
  // ================================================

  // controls the search text field
  final TextEditingController _searchController = TextEditingController();

  // list of orders shown in the table
  List<SalesOrder> _filteredOrders = fakeSalesOrders;

  // controls if filter panel is visible
  bool _showFilterPanel = false;

  // currently selected filter value
  String? _selectedStatus;

  // ================================================
  // DISPOSE — clean up controller when screen closes
  // ================================================
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ================================================
  // GET STATUS LABEL — converts enum to display text
  // ================================================
  String _getStatusLabel(SalesOrderStatus status) {
    if (status == SalesOrderStatus.cancelled) {
      return 'Cancelled';
    } else if (status == SalesOrderStatus.pending) {
      return 'Pending';
    } else if (status == SalesOrderStatus.confirmed) {
      return 'Confirmed';
    } else if (status == SalesOrderStatus.preparing) {
      return 'Preparing';
    } else if (status == SalesOrderStatus.shipped) {
      return 'Shipped';
    } else {
      return '';
    }
  }

  // ================================================
  // APPLY FILTERS — filters orders by search + status
  // ================================================
  void _applyFilters() {
    setState(() {

      _filteredOrders = fakeSalesOrders.where((SalesOrder order) {

        // check if search query matches the reference number
        bool matchesSearch = order.referenceNumber
            .toLowerCase()
            .contains(_searchController.text.toLowerCase());

        // check if the status filter matches
        bool matchesStatus = true;
        if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
          matchesStatus = _getStatusLabel(order.status) == _selectedStatus;
        }

        return matchesSearch && matchesStatus;

      }).toList();
    });
  }

  // ================================================
  // CLEAR FILTERS — resets everything back to default
  // ================================================
  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _searchController.clear();
      _filteredOrders = fakeSalesOrders;
      _showFilterPanel = false;
    });
  }

  // ================================================
  // BUILD
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

              // ================================================
              // TOP ROW — TITLE + EXPORT
              // ================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // title and subtitle
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales Management',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Track and manage your sales orders.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // export button — using common widget!
                  ExportButton(
                    onExport: () {
                      // export logic here later
                    },
                    onDropdown: () {
                      // dropdown logic here later
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ================================================
              // SECOND ROW — SEARCH + FILTER
              // ================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // search bar — using common widget!
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search orders...',
                    onChanged: (String value) {
                      // filter every time user types
                      _applyFilters();
                    },
                  ),

                  const SizedBox(width: 8),

                  // filter button + panel — using common widget!
                  FilterButton(
                    isOpen: _showFilterPanel,

                    // toggle open and close
                    onTap: () {
                      setState(() {
                        _showFilterPanel = !_showFilterPanel;
                      });
                    },

                    // pass current selected value
                    selectedValue: _selectedStatus,

                    // when user picks an option
                    onValueChanged: (String? value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    },

                    // when user clicks clear
                    onClear: _clearFilters,

                    // when user clicks apply
                    onApply: () {
                      _applyFilters();
                      setState(() {
                        _showFilterPanel = false;
                      });
                    },

                    // sales filter sections — status only
                    sections: [
                      FilterSection(
                        title: 'Status',
                        options: [
                          FilterOption(
                            label: 'Cancelled',
                            value: 'Cancelled',
                          ),
                          FilterOption(
                            label: 'Pending',
                            value: 'Pending',
                          ),
                          FilterOption(
                            label: 'Confirmed',
                            value: 'Confirmed',
                          ),
                          FilterOption(
                            label: 'Preparing',
                            value: 'Preparing',
                          ),
                          FilterOption(
                            label: 'Shipped',
                            value: 'Shipped',
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),
                ],
              ),

              const SizedBox(height: 16),

              // ================================================
              // SALES TABLE
              // ================================================
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SalesTable(
                    orders: _filteredOrders,
                    onView: (SalesOrder order) {
                      // TODO: open order detail dialog later
                    },
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