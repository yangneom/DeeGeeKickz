import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/common/tables/common_table.dart';
import '../../../widgets/common/buttons/search_bar.dart';
import '../../../widgets/common/buttons/filter_button.dart';
import '../../../widgets/common/buttons/export_button.dart';
import '../../../widgets/common/buttons/filter_panel.dart';
import '../../../widgets/admin/sales/transaction_details_dialog.dart';
import '../../../services/admin/sales/sales_management_service.dart';
import '../../../core/utils/csv_export_helper.dart';
import '../../../core/utils/excel_export_helper.dart';
import 'package:url_launcher/url_launcher.dart';



class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

enum AdminDateFilter { all, today, yesterday, thisWeek, thisMonth, thisYear, custom }

class _SalesScreenState extends ConsumerState<SalesScreen> {

  final SalesManagementService _salesService = SalesManagementService();
  final TextEditingController _searchController = TextEditingController();

  // ── FILTER POPUP ──
  // Mirrors whether the popup is open (drives the Filter button's
  // highlight). Only _setFilterOpen() may change it, so it can never
  // disagree with the overlay below.
  //
  // The popup is drawn in the app's OVERLAY layer (above the page and
  // the sales table) and anchored under the Filter button. Before, it
  // was a Positioned child of a Stack inside the page: it was painted
  // underneath the table, couldn't be clicked where it overflowed the
  // Stack, and `right: 0` put it under the Export button instead of
  // under Filter. Export keeps its own, completely separate menu.
  bool _showFilterPanel = false;
  final OverlayPortalController _filterOverlay = OverlayPortalController();
  final LayerLink _filterLink = LayerLink();
  final FocusNode _filterFocus = FocusNode(debugLabel: 'sales-filter-popup');

  String? _selectedStatus;
  String _selectedType = 'All'; // All / online / In-Store

  // AUDIT ADD: Phase 6 — date filter
  AdminDateFilter _dateFilter = AdminDateFilter.all;
  DateTimeRange? _customDateRange;

  List<SaleRecord> _allSales = [];
  List<SaleRecord> _filteredSales = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterFocus.dispose();
    super.dispose();
  }

  // Opens/closes the filter popup. Every open and close goes through here
  // (Filter button, outside click, Escape, Clear, Apply) so state and
  // overlay stay in sync. Only touches the filter, never the Export menu.
  void _setFilterOpen(bool open) {
    if (open == _showFilterPanel) return;
    setState(() => _showFilterPanel = open);
    if (open) {
      _filterOverlay.show();
      // Focus the popup so the Escape key reaches it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showFilterPanel) _filterFocus.requestFocus();
      });
    } else {
      _filterOverlay.hide();
    }
  }

    String _formatShortDate(DateTime d) {
    const List<String> monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${monthNames[d.month - 1]} ${d.day}, ${d.year}';
  }

  // The overlay content: a click-catcher behind the popup (outside click
  // closes it), the popup itself anchored under the Filter button, and an
  // Escape-key handler.
  Widget _buildFilterOverlay(BuildContext overlayContext) {
    return Positioned.fill(
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): () => _setFilterOpen(false),
        },
        child: Focus(
          focusNode: _filterFocus,
          child: Stack(
            children: [
              // Click anywhere outside the popup closes it.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _setFilterOpen(false),
                ),
              ),
              // The popup, placed just under the Filter button.
              Positioned.fill(
                child: CompositedTransformFollower(
                  link: _filterLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.bottomLeft,
                  followerAnchor: Alignment.topLeft,
                  offset: const Offset(0, 6),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      // Swallows taps on empty parts of the popup so they
                      // don't fall through to the click-catcher behind it.
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: _buildCombinedFilterPanel(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

    Widget _buildCombinedFilterPanel() {
    const Map<AdminDateFilter, String> dateLabels = {
      AdminDateFilter.all: 'All Time',
      AdminDateFilter.today: 'Today',
      AdminDateFilter.yesterday: 'Yesterday',
      AdminDateFilter.thisWeek: 'This Week',
      AdminDateFilter.thisMonth: 'This Month',
      AdminDateFilter.thisYear: 'This Year',
      AdminDateFilter.custom: 'Custom Range',
    };

    Widget chip(String label, bool isSelected, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF374151),
            ),
          ),
        ),
      );
    }

    Widget sectionLabel(String label) => Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
        );

    Widget dateField(String label, DateTime? date, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD1D5DB)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(
                date != null ? _formatShortDate(date) : label,
                style: TextStyle(
                  fontSize: 12,
                  color: date != null ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Placement is handled by _buildFilterOverlay (anchored under the
    // Filter button), so this returns just the popup card itself.
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: StatefulBuilder(
          builder: (context, setPanelState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Filter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                const SizedBox(height: 12),
                sectionLabel('Type'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    chip('All', _selectedType == 'All', () => setPanelState(() => _selectedType = 'All')),
                    chip('Online', _selectedType == 'online', () => setPanelState(() => _selectedType = 'online')),
                    chip('In-Store', _selectedType == 'In-Store', () => setPanelState(() => _selectedType = 'In-Store')),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 12),
                sectionLabel('Date'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: AdminDateFilter.values.map((f) {
                    return chip(dateLabels[f]!, _dateFilter == f, () async {
                      if (f == AdminDateFilter.custom) {
                        final DateTimeRange? picked = await _showCompactDateRangeDialog(initialRange: _customDateRange);
                        if (picked != null) {
                          setPanelState(() {
                            _dateFilter = AdminDateFilter.custom;
                            _customDateRange = picked;
                          });
                        }
                      } else {
                        setPanelState(() => _dateFilter = f);
                      }
                    });
                  }).toList(),
                ),
                if (_dateFilter == AdminDateFilter.custom && _customDateRange != null) ...[
                  const SizedBox(height: 8),
                  dateField('Start', _customDateRange!.start, () {}),
                  const SizedBox(height: 8),
                  dateField('End', _customDateRange!.end, () {}),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setPanelState(() {
                            _selectedType = 'All';
                            _dateFilter = AdminDateFilter.all;
                            _customDateRange = null;
                          });
                          _clearFilters();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Clear', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _setFilterOpen(false);
                          _loadSales();
                          _applyFilters();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Filter', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

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

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<SaleRecord> sales = await _salesService.loadSales(
      typeFilter: _selectedType == 'All' ? null : _selectedType,
       );
      setState(() {
        _allSales = sales;
        _filteredSales = sales;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load sales. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _onTypeChanged(String type) {
    setState(() => _selectedType = type);
    _loadSales();
  }

    void _applyFilters() {
    String searchQuery = _searchController.text.toLowerCase();
    List<SaleRecord> results = [];

    final DateTimeRange? dateRange = _resolveDateRange();

    for (final sale in _allSales) {
      // Search filter
      if (searchQuery.isNotEmpty) {
        final bool matchesSearch =
            sale.orderId.toLowerCase().contains(searchQuery) ||
            sale.paymentMethod.toLowerCase().contains(searchQuery);
        if (!matchesSearch) continue;
      }

      // AUDIT ADD: Phase 6 — date filter
      if (dateRange != null) {
        if (sale.rawDateTime.isBefore(dateRange.start) ||
            !sale.rawDateTime.isBefore(dateRange.end)) {
          continue;
        }
      }

      results.add(sale);
    }

    setState(() => _filteredSales = results);
  }

  // AUDIT ADD: Phase 6 — translates the selected named filter into a
  // concrete [start, end) range. Returns null for "All" (no filter).
  DateTimeRange? _resolveDateRange() {
    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);

    switch (_dateFilter) {
      case AdminDateFilter.all:
        return null;
      case AdminDateFilter.today:
        return DateTimeRange(start: todayStart, end: todayStart.add(const Duration(days: 1)));
      case AdminDateFilter.yesterday:
        final DateTime y = todayStart.subtract(const Duration(days: 1));
        return DateTimeRange(start: y, end: todayStart);
      case AdminDateFilter.thisWeek:
        final DateTime weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
        return DateTimeRange(start: weekStart, end: todayStart.add(const Duration(days: 1)));
      case AdminDateFilter.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month),
          end: todayStart.add(const Duration(days: 1)),
        );
      case AdminDateFilter.thisYear:
        return DateTimeRange(
          start: DateTime(now.year),
          end: todayStart.add(const Duration(days: 1)),
        );
      case AdminDateFilter.custom:
        if (_customDateRange == null) return null;
        return DateTimeRange(
          start: _customDateRange!.start,
          end: DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day)
              .add(const Duration(days: 1)),
        );
    }
  }

  void _clearFilters() {
  setState(() {
    _selectedType = 'All';
    _searchController.clear();
    _filteredSales = _allSales;
  });
  _setFilterOpen(false);
  _loadSales();
}

Widget _buildStatusBadge(String status) {
    Color backgroundColor = Colors.grey.shade100;
    Color textColor = Colors.grey;
    Color borderColor = Colors.grey.shade300;

    if (status == 'Completed') {
      backgroundColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF16A34A);
      borderColor = const Color(0xFF6EE7B7);
    }
    if (status == 'Confirmed') {
      backgroundColor = const Color(0xFFDBEAFE);
      textColor = const Color(0xFF1D4ED8);
      borderColor = const Color(0xFF93C5FD);
    }
    if (status == 'Preparing') {
      backgroundColor = const Color(0xFFF3F4F6);
      textColor = const Color(0xFF6B7280);
      borderColor = const Color(0xFFD1D5DB);
    }
    if (status == 'Shipped') {
      backgroundColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFD97706);
      borderColor = const Color(0xFFFCD34D);
    }
    if (status == 'Cancelled') {
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
        child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor)),
      ),
    );
  }

  Widget _buildTypeToggle() {
    Widget chip(String label, String value) {
      final bool isSelected = _selectedType == value;
      return GestureDetector(
        onTap: () => _onTypeChanged(value),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.white,
            border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF374151),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('All', 'All'),
        chip('Online', 'online'),
        chip('In-Store', 'In-Store'),
      ],
    );
  }
static const List<String> _exportHeaders = [
    'Order ID',
    'Date & Time',
    'Subtotal',
    'Shipping',
    'Discount',
    'Total',
    'Payment Method',
    'Type',
    'Status',
  ];

  List<List<dynamic>> _buildExportRows() {
    return _filteredSales.map((sale) {
      return [
        sale.orderId,
        sale.dateTime,
        sale.subtotal,
        sale.shipping,
        sale.discountAmount,
        sale.totalAmount,
        sale.paymentMethod,
        sale.orderType == 'In-Store' ? 'In-Store' : 'Online',
        sale.orderStatus,
      ];
    }).toList();
  }

  void _exportToCsv() {
    final String today = DateTime.now().toIso8601String().split('T').first;
    CsvExportHelper.exportToCsv(
      filename: 'sales_$today',
      headers: _exportHeaders,
      rows: _buildExportRows(),
    );
  }

  void _exportToExcel() {
    final String today = DateTime.now().toIso8601String().split('T').first;
    ExcelExportHelper.exportToExcel(
      filename: 'sales_$today',
      headers: _exportHeaders,
      rows: _buildExportRows(),
      sheetName: 'Sales',
    );
  }

  List<List<Widget>> _buildRows() {
    List<List<Widget>> tableRows = [];

    for (final sale in _filteredSales) {
      tableRows.add([
        Text('#${sale.orderId}', style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
        Text(sale.dateTime, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
        Text('₱${sale.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
        Text(sale.paymentMethod, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
        Text(sale.orderType == 'In-Store' ? 'In-Store' : 'Online', style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
        _buildStatusBadge(sale.orderStatus),
                Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => TransactionDetailsDialog(sale: sale),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('View', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: sale.receiptUrl != null && sale.receiptUrl!.isNotEmpty
                    ? 'Download receipt'
                    : 'Receipt not available yet',
                onPressed: sale.receiptUrl != null && sale.receiptUrl!.isNotEmpty
                    ? () async {
                        final Uri uri = Uri.parse(sale.receiptUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    : null,
                icon: const Icon(Icons.download_outlined, size: 18),
                color: const Color(0xFF2563EB),
                disabledColor: const Color(0xFFD1D5DB),
                style: IconButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ),
      ]);
    }

    return tableRows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: GestureDetector(
        onTap: () {
          if (_showFilterPanel) _setFilterOpen(false);
        },
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sales Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const SizedBox(height: 4),
              const Text('View and manage all sales transactions.', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
              const SizedBox(height: 16),

              // Toolbar. The Filter button and the Export button are fully
              // independent: each has its own state and its own menu.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search sales...',
                    onChanged: (value) => _applyFilters(),
                  ),
                  const SizedBox(width: 8),

                  // FILTER: the popup is anchored to THIS button and drawn
                  // in the overlay layer (above the table).
                  CompositedTransformTarget(
                    link: _filterLink,
                    child: OverlayPortal(
                      controller: _filterOverlay,
                      overlayChildBuilder: _buildFilterOverlay,
                      child: InkWell(
                        onTap: () => _setFilterOpen(!_showFilterPanel),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _showFilterPanel ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _showFilterPanel ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.filter_list,
                                size: 16,
                                color: _showFilterPanel ? const Color(0xFF2563EB) : const Color(0xFF374151),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Filter',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _showFilterPanel ? const Color(0xFF2563EB) : const Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // EXPORT: its own menu, untouched by the filter popup.
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
                                Text(_errorMessage!, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _loadSales, child: const Text('Retry')),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: CommonTable(
                              headers: const ['Order ID', 'Date & Time', 'Total', 'Payment Method', 'Type', 'Status', 'Action'],
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

    Widget _buildDateFilterSelector() {
    const Map<AdminDateFilter, String> labels = {
      AdminDateFilter.all: 'All Time',
      AdminDateFilter.today: 'Today',
      AdminDateFilter.yesterday: 'Yesterday',
      AdminDateFilter.thisWeek: 'This Week',
      AdminDateFilter.thisMonth: 'This Month',
      AdminDateFilter.thisYear: 'This Year',
      AdminDateFilter.custom: 'Custom Range',
    };

    return PopupMenuButton<AdminDateFilter>(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      itemBuilder: (context) => AdminDateFilter.values
          .map((f) => PopupMenuItem(value: f, child: Text(labels[f]!)))
          .toList(),
      onSelected: (filter) async {
        if (filter == AdminDateFilter.custom) {
          final DateTimeRange? picked = await _showCompactDateRangeDialog(
            initialRange: _customDateRange,
          );
          if (picked == null) return;
          setState(() {
            _dateFilter = AdminDateFilter.custom;
            _customDateRange = picked;
          });
        } else {
          setState(() => _dateFilter = filter);
        }
        _applyFilters();
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
            Text(labels[_dateFilter]!, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}