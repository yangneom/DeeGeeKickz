import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/common/tables/common_table.dart';
import '../../../widgets/common/buttons/search_bar.dart';
import '../../../widgets/common/buttons/filter_button.dart';
import '../../../widgets/common/buttons/filter_panel.dart';
import '../../../widgets/common/buttons/export_button.dart';
import '../../../services/super/sales/sales_report_service.dart';
import '../../../core/utils/csv_export_helper.dart';
import '../../../core/utils/excel_export_helper.dart';

// ================================================
// SALES REPORT SCREEN
//
// Super Admin view of monthly sales performance.
// Now backed by real Supabase data via SalesReportService:
//   - Total Sales, COGS, Gross Profit (from cost_price_snapshot)
//   - Best Seller (highest quantity sold that month)
//   - Growth % (vs previous month)
//
// Has search, filter by growth direction, and export.
// ================================================
class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {

  final SalesReportService _reportService = SalesReportService();
  final TextEditingController _searchController = TextEditingController();

  bool _showFilterPanel = false;
  String? _selectedFilter;

  List<MonthlyReport> _allReports = [];
  List<MonthlyReport> _filteredReports = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ================================================
  // LOAD REAL DATA
  // ================================================
  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<MonthlyReport> reports =
          await _reportService.getMonthlyReports();

      setState(() {
        _allReports = reports;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load sales report. Please try again.';
        _isLoading = false;
      });
      print('SalesReportScreen._loadReports error: $e');
    }
  }

  // ================================================
  // APPLY FILTERS
  // filters by search text and growth direction
  // ================================================
  void _applyFilters() {
    final String searchQuery = _searchController.text.toLowerCase();
    final List<MonthlyReport> results = [];

    for (final report in _allReports) {
      bool matchesSearch = true;

      if (searchQuery.isNotEmpty) {
        final bool monthMatch =
            report.month.toLowerCase().contains(searchQuery);
        final bool sellerMatch =
            report.bestSeller.toLowerCase().contains(searchQuery);
        matchesSearch = monthMatch || sellerMatch;
      }

      if (!matchesSearch) continue;

      bool matchesFilter = true;
      if (_selectedFilter == 'Positive') {
        matchesFilter = report.growthPercent != null && report.growthPercent! >= 0;
      }
      if (_selectedFilter == 'Negative') {
        matchesFilter = report.growthPercent != null && report.growthPercent! < 0;
      }

      if (!matchesFilter) continue;

      results.add(report);
    }

    setState(() => _filteredReports = results);
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
  // FORMAT CURRENCY
  // ================================================
  String _formatCurrency(double amount) {
    final int rounded = amount.round();
    final String digits = rounded.toString();
    String result = '';
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) result = ',$result';
      result = digits[i] + result;
      count++;
    }
    return '₱$result';
  }

  // ================================================
  // BUILD GROWTH BADGE
  // ================================================
  Widget _buildGrowthBadge(double? growth) {
    if (growth == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'New',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    final bool isPositive = growth >= 0;

    final Color backgroundColor =
        isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final Color textColor =
        isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final String growthText = isPositive
        ? '+${growth.toStringAsFixed(0)} %'
        : '${growth.toStringAsFixed(0)} %';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  Widget _buildAmountText(String amount, {Color? color}) {
    return Text(
      amount,
      style: TextStyle(fontSize: 13, color: color ?? const Color(0xFF111827)),
    );
  }

// ================================================
  // EXPORT
  // ================================================
  static const List<String> _exportHeaders = [
    'Month',
    'Total Sales',
    'COGS',
    'Gross Profit',
    'Best Seller',
    'Growth %',
  ];

  List<List<dynamic>> _buildExportRows() {
    return _filteredReports.map((report) {
      return [
        report.month,
        report.totalSales,
        report.cogs,
        report.grossProfit,
        report.bestSeller,
        report.growthPercent ?? 'New',
      ];
    }).toList();
  }

  void _exportToCsv() {
    final String today = DateTime.now().toIso8601String().split('T').first;
    CsvExportHelper.exportToCsv(
      filename: 'sales_report_$today',
      headers: _exportHeaders,
      rows: _buildExportRows(),
    );
  }

  void _exportToExcel() {
    final String today = DateTime.now().toIso8601String().split('T').first;
    ExcelExportHelper.exportToExcel(
      filename: 'sales_report_$today',
      headers: _exportHeaders,
      rows: _buildExportRows(),
      sheetName: 'Sales Report',
    );
  }

  // ================================================
  // BUILD TABLE ROWS
  // ================================================
  List<List<Widget>> _buildRows() {
    final List<List<Widget>> tableRows = [];

    for (final report in _filteredReports) {
      tableRows.add([
        Text(
          report.month,
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
        _buildAmountText(_formatCurrency(report.totalSales)),
        _buildAmountText(
          _formatCurrency(report.cogs),
          color: const Color(0xFFDC2626),
        ),
        _buildAmountText(
          _formatCurrency(report.grossProfit),
          color: const Color(0xFF16A34A),
        ),
        Text(
          report.bestSeller,
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
        _buildGrowthBadge(report.growthPercent),
      ]);
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
        onTap: () {
          if (_showFilterPanel) setState(() => _showFilterPanel = false);
        },
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Text(
                'Sales Report',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Financial overview and detailed monthly performance.',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),

              const SizedBox(height: 24),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search report...',
                    onChanged: (value) => _applyFilters(),
                  ),
                  const SizedBox(width: 8),
                  FilterButton(
                    isOpen: _showFilterPanel,
                    onTap: () =>
                        setState(() => _showFilterPanel = !_showFilterPanel),
                    selectedValues: {
                      'Growth': _selectedFilter,
                    },
                    onValueChanged: (String section, String? value) {
                      if (section == 'Growth') setState(() => _selectedFilter = value);
                    },
                    onClear: _clearFilters,
                    onApply: () {
                      _applyFilters();
                      setState(() => _showFilterPanel = false);
                    },
                    sections: [
                      FilterSection(
                        title: 'Growth',
                        options: [
                          FilterOption(label: 'Positive', value: 'Positive'),
                          FilterOption(label: 'Negative', value: 'Negative'),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
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
                                  onPressed: _loadReports,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _filteredReports.isEmpty
                            ? const Center(
                                child: Text(
                                  'No sales data available yet.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
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