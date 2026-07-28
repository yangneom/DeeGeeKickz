import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/common/tables/common_table.dart';
import '../../../widgets/common/buttons/export_button.dart';
import '../../../widgets/super/activity_log/activity_log_filter_panel.dart';
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

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(activityLogsProvider.notifier).loadLogs();
    });
  }

  // ================================================
  // FORMAT DATE TIME
  // ================================================
  String _formatDateTime(DateTime dt) {
    String month = dt.month.toString().padLeft(2, '0');
    String day = dt.day.toString().padLeft(2, '0');
    String year = dt.year.toString();
    String hour = dt.hour.toString().padLeft(2, '0');
    String minute = dt.minute.toString().padLeft(2, '0');
    return '$month-$day-$year  $hour:$minute';
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
  // BUILD TABLE ROWS
  // ================================================
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
        // column 1 — name
        Text(
          item['admin_name']?.toString() ?? '-',
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),

        // column 2 — role
        Text(
          item['role']?.toString() ?? '-',
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),

        // column 3 — action
        Text(
          item['action']?.toString() ?? '-',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          overflow: TextOverflow.ellipsis,
        ),

        // column 4 — affected module
        Text(
          item['affected_module']?.toString() ?? '-',
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),

        // column 5 — date & time
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [

                  // export button
                  // export button — clicking "Export" itself is the
                  // quick-default CSV path; the dropdown arrow offers
                  // an explicit CSV/Excel choice via ExportButton's
                  // built-in PopupMenuButton.
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

                  const SizedBox(width: 8),

                  // filter button + panel
                  Stack(
                    clipBehavior: Clip.none,
                    children: [

                      // filter icon button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showFilterPanel = !_showFilterPanel;
                          });
                        },
                        child: Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: _showFilterPanel
                                ? const Color(0xFFEFF6FF)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _showFilterPanel
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFD1D5DB),
                            ),
                          ),
                          child: Icon(
                            Icons.filter_list,
                            size: 18,
                            color: _showFilterPanel
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),

                      // filter panel — separated widget
                      if (_showFilterPanel)
                        ActivityLogFilterPanel(
                          selectedRole: _selectedRole,
                          selectedModule: _selectedModule,
                          selectedStartDate: _selectedStartDate,
                          selectedEndDate: _selectedEndDate,
                          onRoleChanged: (value) {
                            setState(() => _selectedRole = value);
                          },
                          onModuleChanged: (value) {
                            setState(() => _selectedModule = value);
                          },
                          onPickStartDate: () => _pickDate(isStart: true),
                          onPickEndDate: () => _pickDate(isStart: false),
                          onClear: _clearFilters,
                          onApply: () {
                            setState(() => _showFilterPanel = false);
                          },
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── TABLE ──
              Expanded(
                child: SingleChildScrollView(
                  child: CommonTable(
                    headers: const [
                      'Name',
                      'Role',
                      'Action',
                      'Affected Module',
                      'Date & Time',
                    ],
                    rows: _buildRows(filteredLogs),
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