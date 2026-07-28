import 'package:flutter/material.dart';
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


class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {

  final SalesManagementService _salesService = SalesManagementService();
  final TextEditingController _searchController = TextEditingController();

  bool _showFilterPanel = false;
  String? _selectedStatus;
  String _selectedType = 'All'; // All / online / In-Store

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
    super.dispose();
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
      print('Error loading sales: $e');
    }
  }

  void _onTypeChanged(String type) {
    setState(() => _selectedType = type);
    _loadSales();
  }

    void _applyFilters() {
    String searchQuery = _searchController.text.toLowerCase();
    List<SaleRecord> results = [];

    for (final sale in _allSales) {
      // Search filter
      if (searchQuery.isNotEmpty) {
        final bool matchesSearch =
            sale.orderId.toLowerCase().contains(searchQuery) ||
            sale.paymentMethod.toLowerCase().contains(searchQuery);
        if (!matchesSearch) continue;
      }

      results.add(sale);
    }

    setState(() => _filteredSales = results);
  }

  void _clearFilters() {
  setState(() {
    _selectedType = 'All';
    _searchController.clear();
    _filteredSales = _allSales;
    _showFilterPanel = false;
  });
  _loadSales();
}

  Widget _buildStatusBadge(String status) {
    Color backgroundColor = Colors.grey.shade100;
    Color textColor = Colors.grey;

    if (status == 'Completed') {
      backgroundColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF16A34A);
    }
    if (status == 'Shipped') {
      backgroundColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFD97706);
    }
    if (status == 'Cancelled') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFDC2626);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(20)),
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
          child: OutlinedButton(
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
          if (_showFilterPanel) setState(() => _showFilterPanel = false);
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

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search sales...',
                    onChanged: (value) => _applyFilters(),
                  ),
                  const SizedBox(width: 8),
                  FilterButton(
                    isOpen: _showFilterPanel,
                    onTap: () => setState(() => _showFilterPanel = !_showFilterPanel),
                    selectedValues: {
                      'Type': _selectedType == 'All' ? null : _selectedType,
                    },
                    onValueChanged: (String section, String? value) {
                      setState(() => _selectedType = value ?? 'All');
                    },
                    onClear: _clearFilters,
                    onApply: () {
                      _loadSales();
                      setState(() => _showFilterPanel = false);
                    },
                    sections: [
                        FilterSection(
                          title: 'Type',
                          options: [
                            FilterOption(label: 'Online', value: 'online'),
                            FilterOption(label: 'In-Store', value: 'In-Store'),
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
}