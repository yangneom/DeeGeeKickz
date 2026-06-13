import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/common/tables/common_table.dart';
import '../../../widgets/common/buttons/search_bar.dart';
import '../../../widgets/common/buttons/filter_button.dart';
import '../../../widgets/common/buttons/filter_panel.dart';
import '../../../widgets/common/buttons/export_button.dart';

// ================================================
// SALES REPORT SCREEN
//
// Super Admin view of monthly sales performance.
// Shows a breakdown per month with:
//   - Total Sales, COGS, Gross Profit
//   - Best Seller, Growth %
//
// Has search, filter by growth direction, and export.
// ================================================
class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {

  // ================================================
  // CONTROLLERS AND STATE
  // ================================================

  // controls the search text field
  final TextEditingController _searchController = TextEditingController();

  // controls if filter panel is visible
  bool _showFilterPanel = false;

  // currently selected filter value
  String? _selectedFilter;

  // ================================================
  // FAKE DATA — replace with Firebase later
  // ================================================
  final List<Map<String, dynamic>> _allReports = [
    {
      'month': 'Jan 2025',
      'totalSales': '\$5,000',
      'cogs': '\$4,000',
      'grossProfit': '\$5,000',
      'bestSeller': 'Nike Jordan',
      'growth': 7.0,
    },
    {
      'month': 'Feb 2025',
      'totalSales': '\$3,000',
      'cogs': '\$4,000',
      'grossProfit': '\$5,000',
      'bestSeller': 'Nike Jordan',
      'growth': -7.0,
    },
    {
      'month': 'Mar 2025',
      'totalSales': '\$6,200',
      'cogs': '\$3,800',
      'grossProfit': '\$2,400',
      'bestSeller': 'Adidas Ultraboost',
      'growth': 12.0,
    },
    {
      'month': 'Apr 2025',
      'totalSales': '\$4,800',
      'cogs': '\$3,500',
      'grossProfit': '\$1,300',
      'bestSeller': 'Puma RS-X',
      'growth': -3.0,
    },
    {
      'month': 'May 2025',
      'totalSales': '\$7,100',
      'cogs': '\$4,200',
      'grossProfit': '\$2,900',
      'bestSeller': 'Nike Air Max',
      'growth': 18.0,
    },
    {
      'month': 'Jun 2025',
      'totalSales': '\$5,500',
      'cogs': '\$3,600',
      'grossProfit': '\$1,900',
      'bestSeller': 'New Balance 574',
      'growth': 5.0,
    },
  ];

  // filtered list shown in the table
  List<Map<String, dynamic>> _filteredReports = [];

  // ================================================
  // INIT STATE
  // ================================================
  @override
  void initState() {
    super.initState();

    // show all reports at the start
    _filteredReports = _allReports;
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
  // filters by search text and growth direction
  // ================================================
  void _applyFilters() {

    String searchQuery = _searchController.text.toLowerCase();

    List<Map<String, dynamic>> results = [];

    for (int i = 0; i < _allReports.length; i = i + 1) {

      Map<String, dynamic> item = _allReports[i];

      // check search — matches month or best seller
      bool matchesSearch = true;

      if (searchQuery.isNotEmpty) {

        bool monthMatch = item['month']
            .toString()
            .toLowerCase()
            .contains(searchQuery);

        bool sellerMatch = item['bestSeller']
            .toString()
            .toLowerCase()
            .contains(searchQuery);

        matchesSearch = monthMatch || sellerMatch;
      }

      if (matchesSearch == false) {
        continue;
      }

      // check growth filter
      bool matchesFilter = true;

      if (_selectedFilter == 'Positive') {
        matchesFilter = (item['growth'] as double) >= 0;
      }

      if (_selectedFilter == 'Negative') {
        matchesFilter = (item['growth'] as double) < 0;
      }

      if (matchesFilter == false) {
        continue;
      }

      results.add(item);
    }

    setState(() {
      _filteredReports = results;
    });
  }

  // ================================================
  // CLEAR FILTERS
  // ================================================
  void _clearFilters() {
    setState(() {
      _selectedFilter = null;
      _searchController.clear();
      _filteredReports = _allReports;
      _showFilterPanel = false;
    });
  }

  // ================================================
  // BUILD GROWTH BADGE
  // green if positive, red if negative
  // ================================================
  Widget _buildGrowthBadge(double growth) {

    bool isPositive = growth >= 0;

    Color backgroundColor = isPositive
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEE2E2);

    Color textColor = isPositive
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    String growthText = isPositive
        ? '+${growth.toStringAsFixed(0)} %'
        : '${growth.toStringAsFixed(0)} %';

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
          growthText,
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
  // BUILD COLORED AMOUNT TEXT
  // COGS = red, Gross Profit = green, others = dark
  // ================================================
  Widget _buildAmountText(String amount, {Color? color}) {
    return Text(
      amount,
      style: TextStyle(
        fontSize: 13,
        color: color ?? const Color(0xFF111827),
      ),
    );
  }

  // ================================================
  // BUILD TABLE ROWS
  // converts report data into CommonTable rows
  // ================================================
  List<List<Widget>> _buildRows() {

    List<List<Widget>> tableRows = [];

    for (int i = 0; i < _filteredReports.length; i = i + 1) {

      Map<String, dynamic> item = _filteredReports[i];

      List<Widget> oneRow = [

        // column 1 — month
        Text(
          item['month'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 2 — total sales
        _buildAmountText(item['totalSales']),

        // column 3 — COGS in red
        _buildAmountText(
          item['cogs'],
          color: const Color(0xFFDC2626),
        ),

        // column 4 — gross profit in green
        _buildAmountText(
          item['grossProfit'],
          color: const Color(0xFF16A34A),
        ),

        // column 5 — best seller
        Text(
          item['bestSeller'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 6 — growth % badge
        _buildGrowthBadge(item['growth']),
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
              // TITLE
              // ================================================
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    'Sales Report',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),

                  SizedBox(height: 4),

                  Text(
                    'Financial overview and detailed monthly performance.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ================================================
              // SEARCH + FILTER + EXPORT ROW
              // ================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // search bar
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search report...',
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
                    selectedValue: _selectedFilter,
                    onValueChanged: (String? value) {
                      setState(() {
                        _selectedFilter = value;
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
                        title: 'Growth',
                        options: [
                          FilterOption(
                            label: 'Positive',
                            value: 'Positive',
                          ),
                          FilterOption(
                            label: 'Negative',
                            value: 'Negative',
                          ),
                        ],
                      ),
                    ],
                  ),

                  // spacer pushes export to the right
                  const Spacer(),

                  // export button
                  ExportButton(
                    onExport: () {
                      // TODO: implement export
                    },
                    onDropdown: () {
                      // TODO: implement export options
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ================================================
              // SALES REPORT TABLE
              // ================================================
              Expanded(
                child: SingleChildScrollView(
                  child: CommonTable(
                    headers: const [
                      'Month',
                      'Total Sales',
                      'COGS',
                      'Gross Profit',
                      'Best Seller',
                      'Growth %',
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