import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/common/tables/common_table.dart';
import '../../../widgets/common/buttons/search_bar.dart';
import '../../../widgets/common/buttons/filter_button.dart';
import '../../../widgets/common/buttons/export_button.dart';
import '../../../widgets/common/buttons/filter_panel.dart';
import '../../../widgets/admin/sales/transaction_details_dialog.dart';

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

  // controls if filter panel is visible
  bool _showFilterPanel = false;

  // currently selected filter value
  String? _selectedStatus;

  // ================================================
  // FAKE DATA — just for testing
  // later this will come from Firebase
  // ================================================
  final List<Map<String, String>> _allSales = [
    {
      'reference': '123456',
      'date': 'Feb 13, 2026 - 2:45 PM',
      'total': '5,500',
      'payment': 'Cash Payment',
      'status': 'Shipped',
    },
    {
      'reference': '123457',
      'date': 'Feb 13, 2026 - 3:00 PM',
      'total': '5,500',
      'payment': 'Online Payment',
      'status': 'Preparing',
    },
    {
      'reference': '123458',
      'date': 'Feb 14, 2026 - 10:00 AM',
      'total': '3,200',
      'payment': 'Cash Payment',
      'status': 'Pending',
    },
    {
      'reference': '123459',
      'date': 'Feb 14, 2026 - 11:00 AM',
      'total': '1,800',
      'payment': 'Online Payment',
      'status': 'Confirmed',
    },
    {
      'reference': '123460',
      'date': 'Feb 15, 2026 - 9:00 AM',
      'total': '4,200',
      'payment': 'Cash Payment',
      'status': 'Cancelled',
    },
  ];

  // filtered list shown in table
  List<Map<String, String>> _filteredSales = [];

  // ================================================
  // INIT STATE — runs when screen first loads
  // sets filtered list to all sales by default
  // ================================================
  @override
  void initState() {
    super.initState();

    // show all sales at the start
    _filteredSales = _allSales;
  }

  // ================================================
  // DISPOSE — clean up controller when screen closes
  // ================================================
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ================================================
  // APPLY FILTERS
  // filters the sales list based on
  // search text and selected status
  // ================================================
  void _applyFilters() {

    // get search text and make it lowercase
    String searchQuery = _searchController.text.toLowerCase();

    // this will hold our filtered results
    List<Map<String, String>> results = [];

    // loop through all sales
    for (int i = 0; i < _allSales.length; i = i + 1) {

      // get current sale
      Map<String, String> sale = _allSales[i];

      // check if sale matches search query
      bool matchesSearch = true;

      if (searchQuery.isNotEmpty) {

        // check if reference number contains search text
        bool referenceMatch = sale['reference']!
            .toLowerCase()
            .contains(searchQuery);

        // check if payment method contains search text
        bool paymentMatch = sale['payment']!
            .toLowerCase()
            .contains(searchQuery);

        // matches if either reference or payment matches
        matchesSearch = referenceMatch || paymentMatch;
      }

      // if search does not match skip this sale
      if (matchesSearch == false) {
        continue;
      }

      // check if sale matches selected status
      bool matchesStatus = true;

      if (_selectedStatus != null) {
        matchesStatus = sale['status'] == _selectedStatus;
      }

      // if status does not match skip this sale
      if (matchesStatus == false) {
        continue;
      }

      // if both match add to results
      results.add(sale);
    }

    // update the filtered list
    setState(() {
      _filteredSales = results;
    });
  }

  // ================================================
  // CLEAR FILTERS — resets everything
  // ================================================
  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _searchController.clear();
      _filteredSales = _allSales;
      _showFilterPanel = false;
    });
  }

  // ================================================
  // BUILD STATUS BADGE
  // shows a colored badge based on status
  // ================================================
  Widget _buildStatusBadge(String status) {

    // default colors
    Color backgroundColor = Colors.grey.shade100;
    Color textColor = Colors.grey;

    if (status == 'Shipped') {
      backgroundColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFD97706);
    }

    if (status == 'Preparing') {
      backgroundColor = const Color(0xFFEFF6FF);
      textColor = const Color(0xFF2563EB);
    }

    if (status == 'Pending') {
      backgroundColor = const Color(0xFFFEF9C3);
      textColor = const Color(0xFFCA8A04);
    }

    if (status == 'Confirmed') {
      backgroundColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF16A34A);
    }

    if (status == 'Cancelled') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFDC2626);
    }

    // wrap in Align so badge stays small
    // without Align it stretches to full column width
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
  // converts filtered sales into table rows
  // ================================================
  List<List<Widget>> _buildRows() {

    // this will hold all our rows
    List<List<Widget>> tableRows = [];

    // loop through each filtered sale
    for (int i = 0; i < _filteredSales.length; i = i + 1) {

      // get the current sale
      Map<String, String> sale = _filteredSales[i];

      // build one row
      List<Widget> oneRow = [

        // column 1 — reference number
        Text(
          sale['reference']!,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 2 — date and time
        Text(
          sale['date']!,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 3 — total
        Text(
          sale['total']!,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 4 — payment method
        Text(
          sale['payment']!,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 5 — status badge
        // Align keeps badge its natural size
        // without Align it stretches to full width
        _buildStatusBadge(sale['status']!),

        // column 6 — view button
        // Align keeps button its natural size
        // without Align it stretches to full width
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () {
              // showDialog displays a popup over the screen
              // context tells Flutter where to show it
              // builder returns the widget to show
              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  // pass the sale data into the dialog
                  return TransactionDetailsDialog(sale: sale);
                },
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF374151),
              side: const BorderSide(
                color: Color(0xFFD1D5DB),
              ),
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

      // add this row to our list
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
              // TOP ROW — TITLE ONLY
              // ================================================
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // main title
                  Text(
                    'Sales Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),

                  SizedBox(height: 4),

                  // subtitle
                  Text(
                    'View and manage all sales transactions.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ================================================
              // SECOND ROW — SEARCH + FILTER + EXPORT
              // export is now here beside filter!
              // ================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // search bar — using common widget!
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search sales...',
                    onChanged: (String value) {
                      // filter every time user types
                      _applyFilters();
                    },
                  ),

                  const SizedBox(width: 8),

                  // filter button — using common widget!
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

                    // sales filter sections
                    sections: [
                      FilterSection(
                        title: 'Status',
                        options: [
                          FilterOption(
                            label: 'Shipped',
                            value: 'Shipped',
                          ),
                          FilterOption(
                            label: 'Preparing',
                            value: 'Preparing',
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
                            label: 'Cancelled',
                            value: 'Cancelled',
                          ),
                        ],
                      ),
                    ],
                  ),

                  // spacer pushes export to the right
                  const Spacer(),

                  // export button — now in second row!
                  ExportButton(
                    onExport: () {
                      print('Export clicked');
                    },
                    onDropdown: () {
                      print('Dropdown clicked');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ================================================
              // SALES TABLE
              // ================================================
              Expanded(
                child: SingleChildScrollView(
                  child: CommonTable(
                    headers: const [
                      'Reference Number',
                      'Date & Time',
                      'Total',
                      'Payment Method',
                      'Status',
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