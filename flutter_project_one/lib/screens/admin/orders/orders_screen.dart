import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order.dart';
import '../../../widgets/common/tables/common_table.dart';
import '../../../widgets/common/buttons/search_bar.dart';
import '../../../widgets/common/buttons/filter_button.dart';
import '../../../widgets/common/buttons/filter_panel.dart';
import '../../../widgets/admin/orders/order_details_dialog.dart';
import '../../../services/admin/order/order_management_service.dart';
import '../../../widgets/common/buttons/export_button.dart';
import '../../../core/utils/csv_export_helper.dart';
import '../../../core/utils/excel_export_helper.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {

  // ================================================
  // SERVICE
  // ================================================
  final OrderManagementService _orderService = OrderManagementService();

  // ================================================
  // CONTROLLERS AND STATE
  // ================================================

  // controls the search text field
  final TextEditingController _searchController = TextEditingController();

  // controls if filter panel is visible
  bool _showFilterPanel = false;

  // currently selected filter values
  String? _selectedPaymentStatus;
  String? _selectedOrderStatus;

  // ================================================
  // DATA STATE
  // ================================================
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;
  String? _errorMessage;

  // ================================================
  // INIT STATE
  // ================================================
  @override
  void initState() {
    super.initState();
    _loadOrders();
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
  // LOAD ORDERS FROM SUPABASE
  // ================================================
  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<Order> orders = await _orderService.loadOrders();
      setState(() {
        _allOrders = orders;
        _filteredOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load orders. Please try again.';
        _isLoading = false;
      });
      print('Error loading orders: $e');
    }
  }

  // ================================================
  // APPLY FILTERS
  // ================================================
  void _applyFilters() {

    String searchQuery = _searchController.text.toLowerCase();

    List<Order> results = [];

    for (int i = 0; i < _allOrders.length; i = i + 1) {

      Order order = _allOrders[i];

      // search filter
      bool matchesSearch = true;
      if (searchQuery.isNotEmpty) {
        bool nameMatch = order.customerName.toLowerCase().contains(searchQuery);
        bool methodMatch = order.paymentMethod.toLowerCase().contains(searchQuery);
        bool statusMatch = order.orderStatus.toLowerCase().contains(searchQuery);
        matchesSearch = nameMatch || methodMatch || statusMatch;
      }
      if (matchesSearch == false) continue;

      // payment status filter
      bool matchesPaymentStatus = true;
      if (_selectedPaymentStatus != null) {
        matchesPaymentStatus = order.paymentStatus == _selectedPaymentStatus;
      }
      if (matchesPaymentStatus == false) continue;

      // order status filter
      bool matchesOrderStatus = true;
      if (_selectedOrderStatus != null) {
        matchesOrderStatus = order.orderStatus == _selectedOrderStatus;
      }
      if (matchesOrderStatus == false) continue;

      results.add(order);
    }

    setState(() {
      _filteredOrders = results;
    });
  }

  // ================================================
  // CLEAR FILTERS
  // ================================================
  void _clearFilters() {
    setState(() {
      _selectedPaymentStatus = null;
      _selectedOrderStatus = null;
      _searchController.clear();
      _filteredOrders = _allOrders;
      _showFilterPanel = false;
    });
  }

  // ================================================
  // BUILD PAYMENT STATUS BADGE
  // ================================================
  Widget _buildPaymentBadge(String status) {

    Color backgroundColor = Colors.grey.shade100;
    Color textColor = Colors.grey;
    Color borderColor = Colors.grey.shade300;

    if (status == 'Paid') {
      backgroundColor = const Color(0xFFD1FAE5);
      textColor = const Color(0xFF065F46);
      borderColor = const Color(0xFF6EE7B7);
    }

    if (status == 'Pending') {
      backgroundColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFF92400E);
      borderColor = const Color(0xFFFCD34D);
    }

    if (status == 'Failed') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFF991B1B);
      borderColor = const Color(0xFFFCA5A5);
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
  // BUILD ORDER STATUS BADGE
  // ================================================
  Widget _buildOrderStatusBadge(String status) {

    Color backgroundColor = Colors.grey.shade100;
    Color textColor = Colors.grey;
    Color borderColor = Colors.grey.shade300;

    if (status == 'Pending') {
      backgroundColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFF92400E);
      borderColor = const Color(0xFFFCD34D);
    }

    if (status == 'Confirmed') {
      backgroundColor = const Color(0xFFEFF6FF);
      textColor = const Color(0xFF1D4ED8);
      borderColor = const Color(0xFFBFDBFE);
    }

    if (status == 'Preparing') {
      backgroundColor = const Color(0xFFF5F3FF);
      textColor = const Color(0xFF6D28D9);
      borderColor = const Color(0xFFDDD6FE);
    }

    if (status == 'Shipped') {
      backgroundColor = const Color(0xFFECFEFF);
      textColor = const Color(0xFF0E7490);
      borderColor = const Color(0xFFA5F3FC);
    }

    if (status == 'Completed') {
      backgroundColor = const Color(0xFFD1FAE5);
      textColor = const Color(0xFF065F46);
      borderColor = const Color(0xFF6EE7B7);
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
  // BUILD TABLE ROWS
  // ================================================
  static const List<String> _exportHeaders = [
    'Order ID',
    'Customer',
    'Total Amount',
    'Payment Method',
    'Payment Status',
    'Order Status',
    'Date & Time',
  ];

  List<List<dynamic>> _buildExportRows() {
    return _filteredOrders.map((order) {
      return [
        order.orderId,
        order.customerName,
        order.totalAmount,
        order.paymentMethod,
        order.paymentStatus,
        order.orderStatus,
        order.dateTime,
      ];
    }).toList();
  }

  void _exportToCsv() {
    final String today = DateTime.now().toIso8601String().split('T').first;
    CsvExportHelper.exportToCsv(
      filename: 'orders_$today',
      headers: _exportHeaders,
      rows: _buildExportRows(),
    );
  }

  void _exportToExcel() {
    final String today = DateTime.now().toIso8601String().split('T').first;
    ExcelExportHelper.exportToExcel(
      filename: 'orders_$today',
      headers: _exportHeaders,
      rows: _buildExportRows(),
      sheetName: 'Orders',
    );
  }

  Widget _buildCustomerCell(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.customerName,
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
        if (order.isCustomerSuspended) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '⚠ Suspended customer',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ],
    );
  }

  List<List<Widget>> _buildRows() {

    List<List<Widget>> tableRows = [];

    for (int i = 0; i < _filteredOrders.length; i = i + 1) {

      Order order = _filteredOrders[i];

      List<Widget> oneRow = [

        // column 1 — customer (name + suspended flag if applicable)
        _buildCustomerCell(order),

        // column 2 — total amount
        Text(
          '₱${order.totalAmount.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 2 — payment method
        Text(
          order.paymentMethod,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 3 — payment status badge
        _buildPaymentBadge(order.paymentStatus),

        // column 4 — order status badge
        _buildOrderStatusBadge(order.orderStatus),

        // column 5 — date and time
        Text(
          order.dateTime,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 6 — view button
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () {
              showOrderDetailsDialog(
                  context,
                  order,
                  (String newStatus, String newPaymentStatus) {
                    setState(() {
                      for (int j = 0; j < _allOrders.length; j = j + 1) {
                        if (_allOrders[j].orderId == order.orderId) {
                          _allOrders[j] = Order(
                            orderId: _allOrders[j].orderId,
                            customerName: _allOrders[j].customerName,
                            contact: _allOrders[j].contact,
                            landmark: _allOrders[j].landmark,
                            address: _allOrders[j].address,
                            totalAmount: _allOrders[j].totalAmount,
                            paymentMethod: _allOrders[j].paymentMethod,
                            paymentStatus: newPaymentStatus,
                            orderStatus: newStatus,
                            dateTime: _allOrders[j].dateTime,
                            items: _allOrders[j].items,
                          );
                          break;
                        }
                      }
                      _applyFilters();
                    });
                  },
                );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF374151),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'View',
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
              // TOP ROW — TITLE
              // ================================================
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Approval',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Review and manage customer orders.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
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

                  // search bar — reusable common widget
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search orders...',
                    onChanged: (String value) {
                      _applyFilters();
                    },
                  ),

                  const SizedBox(width: 8),

                  // filter button — reusable common widget
                  // filter button — reusable common widget
                  FilterButton(
                    isOpen: _showFilterPanel,
                    onTap: () {
                      setState(() {
                        _showFilterPanel = !_showFilterPanel;
                      });
                    },
                    selectedValues: {
                      'Order Status': _selectedOrderStatus,
                      'Payment Status': _selectedPaymentStatus,
                    },
                    onValueChanged: (String section, String? value) {
                      setState(() {
                        if (section == 'Order Status') _selectedOrderStatus = value;
                        if (section == 'Payment Status') _selectedPaymentStatus = value;
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
                        title: 'Order Status',
                        options: [
                          FilterOption(label: 'Pending', value: 'Pending'),
                          FilterOption(label: 'Confirmed', value: 'Confirmed'),
                          FilterOption(label: 'Preparing', value: 'Preparing'),
                          FilterOption(label: 'Shipped', value: 'Shipped'),
                          FilterOption(label: 'Completed', value: 'Completed'),
                        ],
                      ),
                      FilterSection(
                        title: 'Payment Status',
                        options: [
                          FilterOption(label: 'Paid', value: 'Paid'),
                          FilterOption(label: 'Pending', value: 'Pending'),
                          FilterOption(label: 'Failed', value: 'Failed'),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // export button
                  ExportButton(
                    onExport: _exportToCsv,
                    onFormatSelected: (format) {
                      if (format == 'excel') {
                        _exportToExcel();
                      } else {
                        _exportToCsv();
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ================================================
              // ORDERS TABLE — loading / error / data states
              // ================================================
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadOrders,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                                                       child: CommonTable(
                              headers: const [
                                'Customer',
                                'Total Amount',
                                'Payment Method',
                                'Payment Status',
                                'Order Status',
                                'Date & Time',
                                'Action',
                              ],
                              columnFlex: const [2, 1, 1, 1, 1, 2, 1],
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