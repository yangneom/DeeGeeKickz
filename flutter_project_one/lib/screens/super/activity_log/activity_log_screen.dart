import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/common/tables/common_table.dart';
import '../../../widgets/common/buttons/export_button.dart';
import '../../../widgets/common/buttons/filter_button.dart';
import '../../../widgets/common/buttons/filter_panel.dart';
import '../../../providers/super/activity_log_provider.dart';
import '../../../core/utils/csv_export_helper.dart';
import '../../../core/utils/excel_export_helper.dart';

// ================================================
// ACTIVITY LOG SCREEN
//
// Super Admin view of all system activity.
// Now backed by real Supabase data via
// activityLogsProvider (see ActivityLogService).
// ================================================
class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {

  // ================================================
  // STATE
  // ================================================
  bool _showFilterPanel = false;
  String? _selectedRole;
  String? _selectedModule;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isLoading = true;

  // Staged — same pattern as Admin Management: FilterButton/FilterPanel
  // only commit to _selectedRole/_selectedModule when "Apply" is tapped,
  // not on every chip tap.
  String? _pendingRole;
  String? _pendingModule;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(activityLogsProvider.notifier).loadLogs();
      if (mounted) setState(() => _isLoading = false);
    });
  }

  // ================================================
  // FORMAT DATE TIME
  // ================================================
  String _formatDateTime(DateTime dt) {
    final DateTime local = dt.toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    int hour12 = local.hour % 12;
    if (hour12 == 0) hour12 = 12;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year}, $hour12:$minute $period';
  }
  // parse the created_at value (Supabase returns an ISO string)
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  // ================================================
  // APPLY FILTERS (client-side, over already-loaded logs)
  // ================================================
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> allLogs) {
    return allLogs.where((item) {
      final itemDate = _parseDateTime(item['created_at']);

      if (_selectedRole != null && item['role'] != _selectedRole) {
        return false;
      }

      if (_selectedModule != null && item['affected_module'] != _selectedModule) {
        return false;
      }

      if (_selectedStartDate != null && itemDate != null) {
        if (itemDate.isBefore(
          _selectedStartDate!.subtract(const Duration(days: 1)),
        )) {
          return false;
        }
      }

      if (_selectedEndDate != null && itemDate != null) {
        if (itemDate.isAfter(
          _selectedEndDate!.add(const Duration(days: 1)),
        )) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ================================================
  // CLEAR FILTERS
  // ================================================
  void _clearFilters() {
    setState(() {
      _selectedRole = null;
      _selectedModule = null;
      _pendingRole = null;
      _pendingModule = null;
      _selectedStartDate = null;
      _selectedEndDate = null;
      _showFilterPanel = false;
    });
  }

  // ================================================
  // PICK DATE
  // ================================================
  Future<void> _pickDate({required bool isStart}) async {
    DateTime initial = isStart
        ? (_selectedStartDate ?? DateTime.now())
        : (_selectedEndDate ?? DateTime.now());

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedStartDate = picked;
        } else {
          _selectedEndDate = picked;
        }
      });
    }
  }

  // ================================================
  // EXPORT TO CSV
  // Exports exactly what's currently visible — i.e. respects
  // whatever filters are active, not the full unfiltered log.
  // ================================================
  static const List<String> _exportHeaders = [
    'Name',
    'Role',
    'Action',
    'Affected Module',
    'Date & Time',
  ];

  List<List<dynamic>> _buildExportRows(List<Map<String, dynamic>> logs) {
    return logs.map((item) {
      final DateTime? dateTime = _parseDateTime(item['created_at']);
      return [
        item['admin_name']?.toString() ?? '-',
        item['role']?.toString() ?? '-',
        item['action']?.toString() ?? '-',
        item['affected_module']?.toString() ?? '-',
        dateTime != null ? _formatDateTime(dateTime) : '-',
      ];
    }).toList();
  }

  void _exportToCsv(List<Map<String, dynamic>> logs) {
    final String today =
        DateTime.now().toIso8601String().split('T').first; // YYYY-MM-DD

    CsvExportHelper.exportToCsv(
      filename: 'activity_log_$today',
      headers: _exportHeaders,
      rows: _buildExportRows(logs),
    );
  }

  void _exportToExcel(List<Map<String, dynamic>> logs) {
    final String today =
        DateTime.now().toIso8601String().split('T').first; // YYYY-MM-DD

    ExcelExportHelper.exportToExcel(
      filename: 'activity_log_$today',
      headers: _exportHeaders,
      rows: _buildExportRows(logs),
      sheetName: 'Activity Log',
    );
  }

  // ================================================
  // BUILD TABLE ROWS
  // ================================================
  List<List<Widget>> _buildRows(List<Map<String, dynamic>> logs) {
    List<List<Widget>> tableRows = [];

    for (final item in logs) {
      final dateTime = _parseDateTime(item['created_at']);

      tableRows.add([
        Text(
          item['admin_name']?.toString() ?? '-',
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
        Text(
          item['role']?.toString() ?? '-',
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
               Text(
          item['action']?.toString() ?? '-',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          // No ellipsis — wraps to a second line instead of cutting
          // off, now that this column has more relative room anyway.
        ),
        Text(
          item['affected_module']?.toString() ?? '-',
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
        Text(
          dateTime != null ? _formatDateTime(dateTime) : '-',
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
      ]);
    }

    return tableRows;
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    final allLogs = ref.watch(activityLogsProvider);
    final filteredLogs = _applyFilters(allLogs);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── TITLE ──
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity Log',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Track and review all actions and changes made within the system.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── FILTER + EXPORT ROW ──
            // No Stack needed here — FilterButton positions its own
            // panel via OverlayPortal, anchored directly under itself.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                Row(
                  children: [
                    FilterButton(
                      isOpen: _showFilterPanel,
                      onTap: () {
                        setState(() {
                          _pendingRole = _selectedRole;
                          _pendingModule = _selectedModule;
                          _showFilterPanel = !_showFilterPanel;
                        });
                      },
                      selectedValues: {
                        'Role': _pendingRole,
                        'Affected Module': _pendingModule,
                      },
                      onValueChanged: (section, value) {
                        setState(() {
                          if (section == 'Role') _pendingRole = value;
                          if (section == 'Affected Module') _pendingModule = value;
                        });
                      },
                      onClear: _clearFilters,
                      onApply: () {
                        setState(() {
                          _selectedRole = _pendingRole;
                          _selectedModule = _pendingModule;
                          _showFilterPanel = false;
                        });
                      },
                      sections: [
                        FilterSection(
                          title: 'Role',
                          options: [
                            FilterOption(label: 'Cashier', value: 'Cashier'),
                            FilterOption(label: 'Admin', value: 'Admin'),
                            FilterOption(label: 'Super Admin', value: 'Super Admin'),
                          ],
                        ),
                        FilterSection(
                          title: 'Affected Module',
                          options: [
                            FilterOption(label: 'Admin Management', value: 'Admin Management'),
                            FilterOption(label: 'Customer Management', value: 'Customer Management'),
                            FilterOption(label: 'Inventory', value: 'Inventory'),
                            FilterOption(label: 'Orders', value: 'Orders'),
                            FilterOption(label: 'Promotions', value: 'Promotions'),
                            FilterOption(label: 'Sales', value: 'Sales'),
                            FilterOption(label: 'Feedback Moderation', value: 'Feedback Moderation'),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(width: 8),

                    OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: true),
                      icon: const Icon(Icons.calendar_today_outlined, size: 14),
                      label: Text(
                        _selectedStartDate != null
                            ? '${_selectedStartDate!.month}/${_selectedStartDate!.day}/${_selectedStartDate!.year}'
                            : 'Start date',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),

                    const SizedBox(width: 8),

                    OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: false),
                      icon: const Icon(Icons.calendar_today_outlined, size: 14),
                      label: Text(
                        _selectedEndDate != null
                            ? '${_selectedEndDate!.month}/${_selectedEndDate!.day}/${_selectedEndDate!.year}'
                            : 'End date',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),

                ExportButton(
                  onExport: () => _exportToCsv(filteredLogs),
                  onFormatSelected: (format) {
                    if (format == 'excel') {
                      _exportToExcel(filteredLogs);
                    } else {
                      _exportToCsv(filteredLogs);
                    }
                  },
                ),

              ],
            ),

            const SizedBox(height: 16),

            // ── TABLE ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : SingleChildScrollView(
                                            child: CommonTable(
                        headers: const [
                          'Name',
                          'Role',
                          'Action',
                          'Affected Module',
                          'Date & Time',
                        ],
                        columnFlex: const [2, 1, 4, 2, 2],
                        rows: _buildRows(filteredLogs),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}