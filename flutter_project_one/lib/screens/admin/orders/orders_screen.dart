import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order.dart';
import '../../../widgets/common/tables/common_table.dart';
import '../../../widgets/common/buttons/search_bar.dart';
import '../../../widgets/common/buttons/filter_button.dart';
import '../../../widgets/common/buttons/filter_panel.dart';
import '../../../widgets/admin/orders/order_details_dialog.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {

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
  // FAKE DATA — just for testing
  // later this will come from Supabase
  // ================================================
  late List<Order> _allOrders;
  late List<Order> _filteredOrders;

  // ================================================
  // INIT STATE
  // ================================================
  @override
  void initState() {
    super.initState();

    // deep copy so status updates reflect in table
    _allOrders = fakeOrders.map((Order o) => Order(
      orderId: o.orderId,
      customerName: o.customerName,
      contact: o.contact,
      landmark: o.landmark,
      address: o.address,
      totalAmount: o.totalAmount,
      paymentMethod: o.paymentMethod,
      paymentStatus: o.paymentStatus,
      orderStatus: o.orderStatus,
      dateTime: o.dateTime,
      items: o.items,
    )).toList();

    _filteredOrders = _allOrders;
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
  // same pattern as feedback_screen _buildStatusBadge
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
  // same pattern as feedback_screen _buildRows()
  // ================================================
  List<List<Widget>> _buildRows() {

    List<List<Widget>> tableRows = [];

    for (int i = 0; i < _filteredOrders.length; i = i + 1) {

      Order order = _filteredOrders[i];

      List<Widget> oneRow = [

        // column 1 — total amount
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
        // same pattern as feedback_screen
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () {
              showOrderDetailsDialog(
                context,
                order,
                (String newStatus) {

                  // update status in list when dialog saves
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
                          paymentStatus: _allOrders[j].paymentStatus,
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
                  FilterButton(
                    isOpen: _showFilterPanel,
                    onTap: () {
                      setState(() {
                        _showFilterPanel = !_showFilterPanel;
                      });
                    },
                    selectedValue: _selectedOrderStatus,
                    onValueChanged: (String? value) {
                      setState(() {
                        _selectedOrderStatus = value;
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
                ],
              ),

              const SizedBox(height: 16),

              // ================================================
              // ORDERS TABLE — reusable CommonTable
              // same pattern as feedback_screen
              // ================================================
              Expanded(
                child: SingleChildScrollView(
                  child: CommonTable(
                    headers: const [
                      'Total Amount',
                      'Payment Method',
                      'Payment Status',
                      'Order Status',
                      'Date & Time',
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