import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/common/tables/common_table.dart';
import '../../../widgets/common/buttons/search_bar.dart';
import '../../../widgets/common/buttons/filter_button.dart';
import '../../../widgets/common/buttons/filter_panel.dart';
import '../../../widgets/common/buttons/export_button.dart';
import '../../../widgets/admin/dashboard/stats_card.dart';
import '../../../services/super/sales/sales_report_service.dart';
import '../../../core/utils/csv_export_helper.dart';
import '../../../core/utils/excel_export_helper.dart';
import '../../../widgets/super/sales/full_product_sales_report_dialog.dart';
import '../../../services/super/sales/sales_report_service.dart';
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

enum SalesReportPeriodType { month, year, custom }

  List<DateTime> _availableMonths = [];

  // AUDIT ADD: Phase 2 — period-type selector (Month/Year/Custom)
  SalesReportPeriodType _periodType = SalesReportPeriodType.month;
  int? _selectedYear;
  DateTimeRange? _selectedCustomRange;
  
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

  // AUDIT ADD: Phase 3 — Year view aggregated summary + the subset
  // of _allReports belonging to the selected year.
    List<MonthlyReport> _yearMonths = [];

  // AUDIT ADD: Phase 4 — daily breakdown table within the Month view.
  List<DailySalesSummary> _dailyBreakdown = [];
  bool _isLoadingYear = false;

  // AUDIT ADD: Phase 5 — Custom range summary (day-level granularity,
  // not covered by MonthlyReport/_allReports, so this needs its own
  // service call).
  CustomRangeSummary? _customRangeSummary;
  bool _isLoadingCustomRange = false;
  String? _customRangeError;

  bool _isLoading = true;
  String? _errorMessage;

  // ── Selected-month detail (Total Qty Sold, Top 5, View Details) ──
  // Independent loading/error state from the table above — a failure
  // here shouldn't block the existing table from showing, and vice
  // versa.
    DateTime? _selectedMonth;
  MonthSalesDetail? _monthDetail;
  bool _isLoadingMonthDetail = false;
  String? _monthDetailError;

  // Full picker scope — every month from the earliest order ever
  // placed through the current month, regardless of whether that
  // month has any qualifying sales. Loaded independently of
  // _allReports, which only reflects months WITH sales.
  List<DateTime> _availableMonths = [];

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatMonthLabel(DateTime dt) =>
      '${_monthNames[dt.month - 1]} ${dt.year}';

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadAvailableMonths();
  }

  Future<void> _loadAvailableMonths() async {
    final List<DateTime> months = await _reportService.getAvailableMonths();
    if (!mounted) return;
    setState(() => _availableMonths = months);

    // Default to the most recent month in the FULL scope — not just
    // the most recent month with sales — so a business owner opening
    // the report always starts on "now," even if this month has
    // nothing sold yet.
    if (_selectedMonth == null && months.isNotEmpty) {
      _onMonthChanged(months.first);
    }
  }
    @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onMonthChanged(DateTime month) async {
    setState(() {
      _selectedMonth = month;
      _isLoadingMonthDetail = true;
      _monthDetailError = null;
    });

      try {
      final MonthSalesDetail detail =
          await _reportService.getMonthSalesDetail(month);
      final List<DailySalesSummary> daily =
          await _reportService.getDailyBreakdown(month);
      if (!mounted) return;
      setState(() {
        _monthDetail = detail;
        _dailyBreakdown = daily;
        _isLoadingMonthDetail = false;
      });
    } catch (e) {
      print('SalesReportScreen._onMonthChanged error: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingMonthDetail = false;
        _monthDetailError = 'Failed to load data for this month.';
      });
    }
  }

    // AUDIT ADD: Phase 3 — filters the already-loaded _allReports by
  // year. No new query needed; _loadReports() already fetched every
  // qualifying month once.
  void _onYearChanged(int year) {
    setState(() {
      _isLoadingYear = true;
      _yearMonths = _allReports.where((r) => r.monthStart.year == year).toList()
        ..sort((a, b) => a.monthStart.compareTo(b.monthStart));
      _isLoadingYear = false;
    });
  }

  // AUDIT ADD: Phase 5 — custom range needs day-level data that
  // MonthlyReport doesn't carry, so this calls a dedicated service
  // method rather than reusing _allReports.
  Future<void> _onCustomRangeChanged(DateTimeRange range) async {
    setState(() {
      _isLoadingCustomRange = true;
      _customRangeError = null;
    });
    try {
      final CustomRangeSummary summary =
          await _reportService.getCustomRangeSummary(range.start, range.end);
      if (!mounted) return;
      setState(() {
        _customRangeSummary = summary;
        _isLoadingCustomRange = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _customRangeError = 'Failed to load this date range.';
        _isLoadingCustomRange = false;
      });
    }
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
    'Product Sales',
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

    Widget _buildPeriodSelector() {
    String label;
    switch (_periodType) {
      case SalesReportPeriodType.month:
        label = _selectedMonth != null ? _formatMonthLabel(_selectedMonth!) : 'Select month';
        break;
      case SalesReportPeriodType.year:
        label = _selectedYear != null ? '$_selectedYear' : 'Select year';
        break;
      case SalesReportPeriodType.custom:
        label = _selectedCustomRange != null
            ? '${_formatShortDate(_selectedCustomRange!.start)} – ${_formatShortDate(_selectedCustomRange!.end)}'
            : 'Select range';
        break;
    }

    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'month', child: Text('Month')),
        const PopupMenuItem(value: 'year', child: Text('Year')),
        const PopupMenuItem(value: 'custom', child: Text('Custom Range')),
      ],
      onSelected: (value) async {
        if (value == 'month') {
          setState(() => _periodType = SalesReportPeriodType.month);
        } else if (value == 'year') {
          final int initialYear = _selectedYear ?? DateTime.now().year;
          setState(() {
            _periodType = SalesReportPeriodType.year;
            _selectedYear = initialYear;
          });
          _onYearChanged(initialYear);
        } else if (value == 'custom') {
          final DateTimeRange? picked = await _showCompactDateRangeDialog(
            initialRange: _selectedCustomRange,
          );
          if (picked != null) {
            setState(() {
              _periodType = SalesReportPeriodType.custom;
              _selectedCustomRange = picked;
            });
            _onCustomRangeChanged(picked);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }

  String _formatShortDate(DateTime d) =>
      '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';

        // AUDIT ADD: replaces Flutter's built-in showDateRangePicker, which
  // is always full-screen by design — this is a small, compact dialog
  // matching the existing app's visual style instead.
  Future<DateTimeRange?> _showCompactDateRangeDialog({DateTimeRange? initialRange}) async {
    DateTime? start = initialRange?.start;
    DateTime? end = initialRange?.end;

    return showDialog<DateTimeRange>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickStart() async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: start ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setDialogState(() => start = picked);
            }

            Future<void> pickEnd() async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: end ?? start ?? DateTime.now(),
                firstDate: start ?? DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setDialogState(() => end = picked);
            }

            Widget dateField(String label, DateTime? value, VoidCallback onTap) {
              return InkWell(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          value != null ? _formatShortDate(value) : label,
                          style: TextStyle(
                            fontSize: 13,
                            color: value != null ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF6B7280)),
                    ],
                  ),
                ),
              );
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Custom Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('Start Date', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    const SizedBox(height: 4),
                    dateField('Select start date', start, pickStart),
                    const SizedBox(height: 12),
                    const Text('End Date', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    const SizedBox(height: 4),
                    dateField('Select end date', end, pickEnd),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: (start != null && end != null && !end!.isBefore(start!))
                              ? () => Navigator.of(context).pop(DateTimeRange(start: start!, end: end!))
                              : null,
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ================================================
  // YEAR VIEW — Phase 3
  // ================================================
  Widget _buildYearView() {
    final double totalSales = _yearMonths.fold(0, (sum, m) => sum + m.totalSales);
    final double totalCogs = _yearMonths.fold(0, (sum, m) => sum + m.cogs);
    final double totalGrossProfit = _yearMonths.fold(0, (sum, m) => sum + m.grossProfit);
    final int totalOrders = _yearMonths.fold(0, (sum, m) => sum + m.totalOrders);
    final int totalQuantity = _yearMonths.fold(0, (sum, m) => sum + m.totalQuantitySold);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_selectedYear ?? DateTime.now().year} Summary',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              _buildPeriodSelector(),
            ],
          ),
          const SizedBox(height: 20),

          if (_isLoadingYear)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_yearMonths.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No sales recorded for this year.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ),
            )
          else ...[
            LayoutBuilder(builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 720;
              final List<Widget> cards = [
                _buildMetricCard(
                  icon: Icons.payments_outlined,
                  iconBg: const Color(0xFFDCFCE7),
                  iconColor: const Color(0xFF16A34A),
                  title: 'Product Sales',
                  valueText: _formatCurrency(totalSales),
                ),
                _buildMetricCard(
                  icon: Icons.receipt_long_outlined,
                  iconBg: const Color(0xFFDBEAFE),
                  iconColor: const Color(0xFF2563EB),
                  title: 'Total Orders',
                  valueText: totalOrders.toString(),
                ),
                _buildMetricCard(
                  icon: Icons.inventory_2_outlined,
                  iconBg: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFD97706),
                  title: 'Total Quantity Sold',
                  valueText: totalQuantity.toString(),
                ),
                _buildMetricCard(
                  icon: Icons.trending_up,
                  iconBg: const Color(0xFFEDE9FE),
                  iconColor: const Color(0xFF7C3AED),
                  title: 'Gross Profit',
                  valueText: _formatCurrency(totalGrossProfit),
                ),
              ];
              return isNarrow
                  ? Column(children: cards.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12), child: c)).toList())
                  : Row(children: cards.map((c) => Expanded(
                      child: Padding(padding: const EdgeInsets.only(right: 12), child: c))).toList());
            }),
            const SizedBox(height: 24),
            CommonTable(
              headers: const [
                'Month', 'Product Sales', 'COGS', 'Gross Profit', 'Best Seller', 'Growth %',
              ],
              rows: _yearMonths.map((m) {
                return <Widget>[
                  Text(
                    m.month,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                  ),
                  _buildAmountText(_formatCurrency(m.totalSales)),
                  _buildAmountText(
                    _formatCurrency(m.cogs),
                    color: const Color(0xFFDC2626),
                  ),
                  _buildAmountText(
                    _formatCurrency(m.grossProfit),
                    color: const Color(0xFF16A34A),
                  ),
                  Text(
                    m.bestSeller,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                  ),
                  _buildGrowthBadge(m.growthPercent),
                ];
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ================================================
  // CUSTOM RANGE VIEW — Phase 5
  // ================================================
  Widget _buildCustomRangeView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Custom Range Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              _buildPeriodSelector(),
            ],
          ),
          const SizedBox(height: 20),

          if (_isLoadingCustomRange)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_customRangeError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(_customRangeError!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            )
          else if (_customRangeSummary == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Select a date range to view its summary.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            )
          else
            LayoutBuilder(builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 720;
              final CustomRangeSummary s = _customRangeSummary!;
              final List<Widget> cards = [
                _buildMetricCard(
                  icon: Icons.payments_outlined,
                  iconBg: const Color(0xFFDCFCE7),
                  iconColor: const Color(0xFF16A34A),
                  title: 'Product Sales',
                  valueText: _formatCurrency(s.totalSales),
                ),
                _buildMetricCard(
                  icon: Icons.receipt_long_outlined,
                  iconBg: const Color(0xFFDBEAFE),
                  iconColor: const Color(0xFF2563EB),
                  title: 'Total Orders',
                  valueText: s.totalOrders.toString(),
                ),
                _buildMetricCard(
                  icon: Icons.inventory_2_outlined,
                  iconBg: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFD97706),
                  title: 'Total Quantity Sold',
                  valueText: s.totalQuantitySold.toString(),
                ),
                _buildMetricCard(
                  icon: Icons.trending_up,
                  iconBg: const Color(0xFFEDE9FE),
                  iconColor: const Color(0xFF7C3AED),
                  title: 'Gross Profit',
                  valueText: _formatCurrency(s.grossProfit),
                ),
              ];
              return isNarrow
                  ? Column(children: cards.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12), child: c)).toList())
                  : Row(children: cards.map((c) => Expanded(
                      child: Padding(padding: const EdgeInsets.only(right: 12), child: c))).toList());
            }),
        ],
      ),
    );
  }

  // ================================================
  // BUILD
  // ================================================
    // ================================================
  // MONTH DETAIL SECTION — period selector, key metrics,
  // Top 5, view details
  // ================================================
  Widget _buildMonthDetailSection() {
    // AUDIT ADD: Phase 3/5 — dispatch to the Year or Custom Range
    // view when selected. The existing month-view Container/Column
    // below is completely untouched when _periodType is month.
    if (_periodType == SalesReportPeriodType.year) {
      return _buildYearView();
    }
    if (_periodType == SalesReportPeriodType.custom) {
      return _buildCustomRangeView();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Period selector ──
          Row(
            children: [
              const Text(
                'Monthly Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              _buildPeriodSelector(),
            ],
          ),
          const SizedBox(height: 20),

          if (_isLoadingMonthDetail)            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_monthDetailError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(_monthDetailError!,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280))),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _selectedMonth != null
                        ? _onMonthChanged(_selectedMonth!)
                        : null,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                  else if (_monthDetail == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No sales data available yet.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            )
          else ...[
            _buildMonthMetrics(_monthDetail!),
            const SizedBox(height: 24),
            _buildTopProductsSection(_monthDetail!),
            if (_dailyBreakdown.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Sales Breakdown — ${_formatMonthLabel(_selectedMonth!)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
                           CommonTable(
                headers: const [
                  'Date', 'Product Sales', 'Orders', 'Quantity Sold', 'Gross Profit',
                ],
                rows: _dailyBreakdown.map((d) {
                  return <Widget>[
                    InkWell(
                      onTap: () => _showDayDrillDown(d.date),
                      child: Text(
                        _formatShortDate(d.date),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2563EB),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    _buildAmountText(_formatCurrency(d.totalSales)),
                    Text(
                      d.totalOrders.toString(),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                    ),
                    Text(
                      d.totalQuantitySold.toString(),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                    ),
                    _buildAmountText(
                      _formatCurrency(d.grossProfit),
                      color: const Color(0xFF16A34A),
                    ),
                  ];
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMonthMetrics(MonthSalesDetail detail) {
    return LayoutBuilder(builder: (context, constraints) {
      final bool isNarrow = constraints.maxWidth < 720;
      final List<Widget> cards = [
                _buildMetricCard(
          icon: Icons.payments_outlined,
          iconBg: const Color(0xFFDCFCE7),
          iconColor: const Color(0xFF16A34A),
          title: 'Product Sales',
          valueText: _formatCurrency(detail.totalSales),
        ),
        _buildMetricCard(
          icon: Icons.receipt_long_outlined,
          iconBg: const Color(0xFFDBEAFE),
          iconColor: const Color(0xFF2563EB),
          title: 'Total Orders',
          valueText: detail.totalOrders.toString(),
        ),
        _buildMetricCard(
          icon: Icons.inventory_2_outlined,
          iconBg: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          title: 'Total Quantity Sold',
          valueText: detail.totalQuantitySold.toString(),
        ),
      ];

      if (isNarrow) {
        return Column(
          children: cards
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: c,
                  ))
              .toList(),
        );
      }

      // IntrinsicHeight forces every card in the Row to match the
      // tallest one — with all three now built from the same local
      // widget and no "View details" link, they're naturally equal
      // height anyway, but this keeps them locked together even if
      // a title ever wraps to two lines on a narrower desktop width.
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards
              .map((c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: c,
                    ),
                  ))
              .toList(),
        ),
      );
    });
  }

    Future<void> _showDayDrillDown(DateTime day) async {
    final List<DayTransaction> transactions =
        await _reportService.getDayTransactions(day);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatShortDate(day),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: transactions.isEmpty
                      ? const Text('No transactions this day.')
                      : CommonTable(
                          headers: const ['Order ID', 'Date & Time', 'Total', 'Payment Method', 'Type', 'Status'],
                          rows: transactions.map((t) {
                            return <Widget>[
                              Text('#${t.orderId}'),
                              Text(_formatShortDate(t.dateTime)),
                              _buildAmountText(_formatCurrency(t.totalAmount)),
                              Text(t.paymentMethod),
                              Text(t.orderType),
                              Text(t.orderStatus),
                            ];
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String valueText,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            valueText,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsSection(MonthSalesDetail detail) {
    final List<ProductSalesEntry> top5 = detail.products.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top 5 Best-Selling Products',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        if (top5.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'No products were sold this month.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          )
        else
          ...top5.asMap().entries.map((entry) {
            final int index = entry.key;
            final ProductSalesEntry p = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              p.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_outlined,
                                  size: 18,
                                  color: Color(0xFF9CA3AF)),
                            ),
                          )
                        : const Icon(Icons.image_outlined,
                            size: 18, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.productName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111827)),
                    ),
                  ),
                  Text(
                    '${p.quantitySold} items sold',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 90,
                    child: Text(
                      _formatCurrency(p.salesAmount),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827)),
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: detail.products.isEmpty || _selectedMonth == null
                ? null
                : () => showFullProductSalesReport(
                      context: context,
                      monthLabel: _formatMonthLabel(_selectedMonth!),
                      products: detail.products,
                    ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF374151),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
                        child: const Text('View All Product Sales',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
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
        child: SingleChildScrollView(
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

              // ── Selected-month deep-dive: period → key metrics →
              // Top 5 → view details. The existing all-months table
              // below is untouched — this section filters nothing on
              // it, it's a separate, focused view. ──
              _buildMonthDetailSection(),

              const SizedBox(height: 32),
              const Text(
                'All Months',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 16),

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

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
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
                  ),
                )
              else if (_filteredReports.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'No sales data available yet.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                )
              else
                                CommonTable(
                  headers: const [
                    'Month',
                    'Product Sales',
                    'COGS',
                    'Gross Profit',
                    'Best Seller',
                    'Growth %',
                  ],
                  rows: _buildRows(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}