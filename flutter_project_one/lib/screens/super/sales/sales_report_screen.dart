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
import '../../../widgets/common/dialog/app_toast.dart';
import '../../../services/super/sales/sales_report_service.dart';
import '../../../widgets/common/dialog/app_toast.dart';
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


enum ReportPeriod { today, yesterday, thisWeek, thisMonth, thisYear, custom }

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  List<DateTime> _availableMonths = [];

  // AUDIT REPLACE: one unified period system — replaces the old
  // separate Month/Year/Custom dropdown, the standalone "All Months"
  // table, and the old Growth-only Filter in one coherent flow.
  ReportPeriod _reportPeriod = ReportPeriod.thisMonth;
    DateTimeRange? _customRange;

  // What is selected inside the open filter panel. It only becomes the
  // applied report period when Apply is pressed.
  ReportPeriod _pendingPeriod = ReportPeriod.thisMonth;
  DateTimeRange? _pendingCustomRange;
  bool _showFilterPanel = false;

  bool _isLoadingPeriod = false;
  String? _periodError;
  double _periodProductSales = 0;
  double _periodCogs = 0;
  double _periodGrossProfit = 0;
  int _periodTotalOrders = 0;
  int _periodTotalQuantity = 0;
  List<DailySalesSummary> _periodDailyRows = [];
  List<MonthlyReport> _periodMonthlyRows = [];
  bool get _isYearGranularity => _reportPeriod == ReportPeriod.thisYear;


  (DateTime, DateTime) _resolvePeriodRange() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    switch (_reportPeriod) {
      case ReportPeriod.today:
        return (today, today);
      case ReportPeriod.yesterday:
        final DateTime y = today.subtract(const Duration(days: 1));
        return (y, y);
      case ReportPeriod.thisWeek:
        final DateTime weekStart = today.subtract(Duration(days: today.weekday - 1));
        return (weekStart, today);
      case ReportPeriod.thisMonth:
        return (DateTime(now.year, now.month, 1), today);
      case ReportPeriod.thisYear:
        return (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31));
      case ReportPeriod.custom:
        if (_customRange == null) return (today, today);
        return (_customRange!.start, _customRange!.end);
    }
  }

  Future<void> _loadReportPeriod() async {
    setState(() {
      _isLoadingPeriod = true;
      _periodError = null;
    });

    try {
      if (_isYearGranularity) {
        final int year = DateTime.now().year;
        final List<MonthlyReport> months =
            _allReports.where((r) => r.monthStart.year == year).toList()
              ..sort((a, b) => a.monthStart.compareTo(b.monthStart));
        if (!mounted) return;
        setState(() {
          _periodMonthlyRows = months;
          _periodProductSales = months.fold(0, (sum, m) => sum + m.totalSales);
          _periodCogs = months.fold(0, (sum, m) => sum + m.cogs);
          _periodGrossProfit = months.fold(0, (sum, m) => sum + m.grossProfit);
          _periodTotalOrders = months.fold(0, (sum, m) => sum + m.totalOrders);
          _periodTotalQuantity = months.fold(0, (sum, m) => sum + m.totalQuantitySold);
          _isLoadingPeriod = false;
        });
        return;
      }

      final (DateTime start, DateTime end) = _resolvePeriodRange();
      final CustomRangeSummary summary = await _reportService.getCustomRangeSummary(start, end);
      final List<DailySalesSummary> daily = await _reportService.getDailyBreakdownForRange(start, end);
      if (!mounted) return;
      setState(() {
        _periodProductSales = summary.totalSales;
        _periodCogs = summary.cogs;
        _periodGrossProfit = summary.grossProfit;
        _periodTotalOrders = summary.totalOrders;
        _periodTotalQuantity = summary.totalQuantitySold;
        _periodDailyRows = daily;
        _isLoadingPeriod = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _periodError = 'Failed to load this period.';
        _isLoadingPeriod = false;
      });
    }
  }


  final SalesReportService _reportService = SalesReportService();
  final TextEditingController _searchController = TextEditingController();

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
      _loadReportPeriod();
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


  Widget _buildUnifiedReportSection() {
    const Map<ReportPeriod, String> labels = {
      ReportPeriod.today: 'Today',
      ReportPeriod.yesterday: 'Yesterday',
      ReportPeriod.thisWeek: 'This Week',
      ReportPeriod.thisMonth: 'This Month',
      ReportPeriod.thisYear: 'This Year',
      ReportPeriod.custom: 'Custom Range',
    };

    final (DateTime start, DateTime end) = _resolvePeriodRange();
    final bool singleDay = start.year == end.year && start.month == end.month && start.day == end.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
                  _isYearGranularity ? '${DateTime.now().year} Summary' : labels[_reportPeriod]!,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 4),
        Text(
          singleDay
              ? _formatShortDate(start)
              : '${_formatShortDate(start)} – ${_formatShortDate(end)}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),

        if (_isLoadingPeriod)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_periodError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(_periodError!, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          )
        else
          LayoutBuilder(builder: (context, constraints) {
            final bool isNarrow = constraints.maxWidth < 720;
            final List<Widget> cards = [
              _buildMetricCard(
                icon: Icons.payments_outlined,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
                title: 'Product Sales',
                valueText: _formatCurrency(_periodProductSales),
              ),
              _buildMetricCard(
                icon: Icons.receipt_long_outlined,
                iconBg: const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF2563EB),
                title: 'Total Orders',
                valueText: _periodTotalOrders.toString(),
              ),
              _buildMetricCard(
                icon: Icons.inventory_2_outlined,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                title: 'Total Quantity Sold',
                valueText: _periodTotalQuantity.toString(),
              ),
                           _buildMetricCard(
                icon: Icons.shopping_bag_outlined,
                iconBg: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFDC2626),
                title: 'COGS',
                valueText: _formatCurrency(_periodCogs),
              ),
              _buildMetricCard(
                icon: Icons.trending_up,
                iconBg: const Color(0xFFEDE9FE),
                iconColor: const Color(0xFF7C3AED),
                title: 'Gross Profit',
                valueText: _formatCurrency(_periodGrossProfit),
              ),
            ];
            return isNarrow
                ? Column(children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList())
                : Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c))).toList());
          }),

        const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CommonSearchBar(
              controller: _searchController,
              hintText: 'Search report...',
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(width: 8),
                        FilterButton(
              isOpen: _showFilterPanel,
              onTap: () => setState(() {
                // Opening starts from what is currently applied, so anything
                // selected earlier but never applied is thrown away.
                if (!_showFilterPanel) {
                  _pendingPeriod = _reportPeriod;
                  _pendingCustomRange = _customRange;
                }
                _showFilterPanel = !_showFilterPanel;
              }),
              // The panel shows the PENDING choice. The heading, cards,
              // table and export keep showing the applied one.
              selectedValues: {'Period': _pendingPeriod.name},
              onValueChanged: (String section, String? value) async {
                if (value == 'custom') {
                  final DateTimeRange? picked = await _showCompactDateRangeDialog(
                    initialRange: _pendingCustomRange ?? _customRange,
                  );
                  if (picked != null) {
                    setState(() {
                      _pendingPeriod = ReportPeriod.custom;
                      _pendingCustomRange = picked;
                    });
                  }
                } else {
                  final ReportPeriod selected = ReportPeriod.values.firstWhere(
                    (p) => p.name == value,
                    orElse: () => ReportPeriod.thisMonth,
                  );
                  setState(() => _pendingPeriod = selected);
                }
              },
              onClear: () {
                // The shared filter panel closes itself on Clear (same as on
                // every other screen), so Clear means: back to the default
                // period, This Month, applied right away.
                setState(() {
                  _reportPeriod = ReportPeriod.thisMonth;
                  _customRange = null;
                  _pendingPeriod = ReportPeriod.thisMonth;
                  _pendingCustomRange = null;
                  _showFilterPanel = false;
                });
                _loadReportPeriod();
              },
              onApply: () {
                setState(() {
                  _reportPeriod = _pendingPeriod;
                  _customRange = _pendingCustomRange;
                  _showFilterPanel = false;
                });
                _loadReportPeriod();
              },
              sections: [
                FilterSection(
                  title: 'Period',
                  options: ReportPeriod.values
                      .map((p) => FilterOption(label: labels[p]!, value: p.name))
                      .toList(),
                ),
              ],
            ),
            const Spacer(),
            if (!_isYearGranularity && !_isLoadingPeriod)
                           ElevatedButton.icon(
                onPressed: () async {
                  final List<DayTransaction> transactions =
                      await _reportService.getRangeTransactions(start, end);
                  if (!mounted) return;
                  _showTransactionDrillDown(
                    title: singleDay ? _formatShortDate(start) : '${_formatShortDate(start)} – ${_formatShortDate(end)}',
                    subtitle: 'Transactions behind this period\'s Sales Report figures',
                    transactions: transactions,
                    showDatePerRow: !singleDay,
                  );
                },
                             icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('View All Transactions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
            ExportButton(
              onExport: _exportToCsv,
              onFormatSelected: (format) {
                if (format == 'excel') { _exportToExcel(); } else { _exportToCsv(); }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (!_isLoadingPeriod && _periodError == null)
          _isYearGranularity
              ? (_periodMonthlyRows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No sales data available yet.', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))))
                                    : CommonTable(
                      headers: const ['Month', 'Product Sales', 'COGS', 'Gross Profit', 'Best Seller', 'Growth %', ''],
                      rows: _periodMonthlyRows.map((m) {
                        return <Widget>[
                          Text(m.month, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                          _buildAmountText(_formatCurrency(m.totalSales)),
                          _buildAmountText(_formatCurrency(m.cogs), color: const Color(0xFFDC2626)),
                          _buildAmountText(_formatCurrency(m.grossProfit), color: const Color(0xFF16A34A)),
                          Text(m.bestSeller, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                          _buildGrowthBadge(m.growthPercent),
                                                   _buildTopProductsButton(
                            () => _showMonthOrDayDetails(period: m.monthStart, isMonth: true),
                          ),
                        ];
                      }).toList(),
                    ))
              : (_periodDailyRows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No sales data available for this period.', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))))
                                  : CommonTable(
                      headers: const ['Date', 'Product Sales', 'Orders', 'Quantity Sold', 'COGS', 'Gross Profit', ''],
                      rows: _periodDailyRows.map((d) {
                        return <Widget>[
                          InkWell(
                            onTap: () => _showDayDrillDown(d.date),
                            child: Text(
                              _formatShortDate(d.date),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB), decoration: TextDecoration.underline),
                            ),
                          ),
                          _buildAmountText(_formatCurrency(d.totalSales)),
                          Text(d.totalOrders.toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                                             Text(d.totalQuantitySold.toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                          _buildAmountText(_formatCurrency(d.totalSales - d.grossProfit), color: const Color(0xFFDC2626)),
                          _buildAmountText(_formatCurrency(d.grossProfit), color: const Color(0xFF16A34A)),
                                                    _buildTopProductsButton(
                            () => _showMonthOrDayDetails(period: d.date, isMonth: false),
                          ),
                        ];
                      }).toList(),
                    )),
      ],
    );
  }
// ================================================
  // EXPORT
  // ================================================
  // The export mirrors exactly what the report table shows: same period,
  // same grouping (monthly rows for This Year, daily rows for every other
  // period), same figures. COGS = sales - gross profit, the same
  // relationship the table uses.
  List<String> get _exportHeaders => _isYearGranularity
      ? const ['Month', 'Product Sales', 'COGS', 'Gross Profit', 'Best Seller', 'Growth %']
      : const ['Date', 'Product Sales', 'Orders', 'Quantity Sold', 'COGS', 'Gross Profit'];

  List<List<dynamic>> _buildExportRows() {
    if (_isYearGranularity) {
      return _periodMonthlyRows.map((m) {
        return [
          m.month,
          m.totalSales,
          m.cogs,
          m.grossProfit,
          m.bestSeller,
          m.growthPercent ?? 'New',
        ];
      }).toList();
    }
    return _periodDailyRows.map((d) {
      return [
        _formatShortDate(d.date),
        d.totalSales,
        d.totalOrders,
        d.totalQuantitySold,
        d.totalSales - d.grossProfit,
        d.grossProfit,
      ];
    }).toList();
  }

  // The file name carries the exact period, e.g.
  // sales_report_2026-09-24_to_2026-09-27
  String get _exportFileName {
    final (DateTime start, DateTime end) = _resolvePeriodRange();
    String ymd(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return 'sales_report_${ymd(start)}_to_${ymd(end)}';
  }

  void _showNothingToExport() {
      AppToast.info(
      context,
      'There is no data to export for the selected period.',
      title: 'Nothing to export',
    );
  }

  void _exportToCsv() {
    final List<List<dynamic>> rows = _buildExportRows();
    if (rows.isEmpty) {
      _showNothingToExport();
      return;
    }
    CsvExportHelper.exportToCsv(
      filename: _exportFileName,
      headers: _exportHeaders,
      rows: rows,
    );
  }

  void _exportToExcel() {
    final List<List<dynamic>> rows = _buildExportRows();
    if (rows.isEmpty) {
      _showNothingToExport();
      return;
    }
    ExcelExportHelper.exportToExcel(
      filename: _exportFileName,
      headers: _exportHeaders,
      rows: rows,
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


  String _formatShortDate(DateTime d) =>
      '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';

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
              backgroundColor: Colors.white,
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
    _showTransactionDrillDown(
      title: _formatShortDate(day),
      subtitle: 'Transactions behind this day\'s Sales Report figures',
      transactions: transactions,
      showDatePerRow: false,
    );
  }

  // AUDIT ADD: shared, polished read-only drill-down, used by both
  // the Month view's per-day click and Custom Range's "View
  // Transactions" button — one dialog implementation, not two.
  void _showTransactionDrillDown({
    required String title,
    required String subtitle,
    required List<DayTransaction> transactions,
    required bool showDatePerRow,
  }) {
    showDialog(
      context: context,
      builder: (context) {
               return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 640,
            constraints: const BoxConstraints(maxHeight: 640),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 16),
                Flexible(
                  child: transactions.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No transactions in this period.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        )
                      : SingleChildScrollView(
                          child: CommonTable(
                            headers: const ['Order ID', 'Date & Time', 'Total', 'Payment Method', 'Type', 'Status'],
                            rows: transactions.map((t) {
                              return <Widget>[
                                Text('#${t.orderId}', style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                                // Full date+time shown for multi-day ranges, so
                                // transactions from different days stay clearly
                                // distinguishable; day-only drill-down keeps
                                // showing just the time, since the date is
                                // already the dialog's own title.
                                Text(
                                  showDatePerRow ? _formatDateTime(t.dateTime) : _formatTimeOnly(t.dateTime),
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                                ),
                                _buildAmountText(_formatCurrency(t.totalAmount)),
                                Text(t.paymentMethod, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                                Text(t.orderType, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                                Text(t.orderStatus, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                              ];
                            }).toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                                child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimeOnly(DateTime d) {
    final int hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final String minute = d.minute.toString().padLeft(2, '0');
    final String amPm = d.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $amPm';
  }

  String _formatDateTime(DateTime d) => '${_formatShortDate(d)}, ${_formatTimeOnly(d)}';
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

    Future<void> _showMonthOrDayDetails({required DateTime period, required bool isMonth}) async {
    final MonthSalesDetail detail = isMonth
        ? await _reportService.getMonthSalesDetail(period)
        : await _reportService.getDaySalesDetail(period);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 640),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMonth ? _formatMonthLabel(period) : _formatShortDate(period),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildSmallStat('Product Sales', _formatCurrency(detail.totalSales))),
                    Expanded(child: _buildSmallStat('Orders', detail.totalOrders.toString())),
                    Expanded(child: _buildSmallStat('Qty Sold', detail.totalQuantitySold.toString())),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 16),
                const Text('Top 5 Products · ranked by units sold', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const SizedBox(height: 12),
                Flexible(
                  child: detail.products.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No products sold in this period.', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: detail.products.take(5).map((p) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: p.imageUrl != null
                                          ? Image.network(p.imageUrl!, width: 36, height: 36, fit: BoxFit.cover)
                                          : Container(width: 36, height: 36, color: const Color(0xFFF3F4F6)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(p.productName, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                                    ),
                                    Text('${p.quantitySold} sold', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                    const SizedBox(width: 12),
                                    _buildAmountText(_formatCurrency(p.salesAmount)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                             child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // The per-row "Top Products" button, styled like the "View" button in
  // the other management tables (outlined, neutral gray).
  Widget _buildTopProductsButton(VoidCallback onPressed) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF374151),
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: const Text('Top Products', style: TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildSmallStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
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
              _buildUnifiedReportSection(),
            ],
          ),
        ),
      ),
    );
  }
}