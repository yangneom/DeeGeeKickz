import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/common/common_table.dart';
import '../../../widgets/common/export_button.dart';
import '../../../widgets/super/activity_log/activity_log_filter_panel.dart';

// ================================================
// ACTIVITY LOG SCREEN
//
// Super Admin view of all system activity
// Follows feedback_screen.dart pattern
// Filter panel is separated into its own widget
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

  // ================================================
  // FAKE DATA — replace with Supabase later
  // ================================================
  final List<Map<String, dynamic>> _allLogs = [
    {
      'name': 'Angel Tuazon',
      'role': 'Cashier',
      'action': 'Updated Inventory count for Nike Air Force One',
      'module': 'Inventory',
      'dateTime': DateTime(2026, 3, 3, 9, 30),
    },
    {
      'name': 'Jay Galang',
      'role': 'Admin',
      'action': 'Added new product Nike Jordan',
      'module': 'Inventory',
      'dateTime': DateTime(2026, 3, 3, 10, 15),
    },
    {
      'name': 'Maria Santos',
      'role': 'Admin',
      'action': 'Processed refund for Order #1023',
      'module': 'Orders',
      'dateTime': DateTime(2026, 3, 4, 11, 0),
    },
    {
      'name': 'Carlo Reyes',
      'role': 'Cashier',
      'action': 'Completed sale of Adidas Ultraboost',
      'module': 'Sales',
      'dateTime': DateTime(2026, 3, 4, 13, 45),
    },
    {
      'name': 'Super Admin',
      'role': 'Super Admin',
      'action': 'Disabled admin account of Juan dela Cruz',
      'module': 'Admin Management',
      'dateTime': DateTime(2026, 3, 5, 14, 30),
    },
    {
      'name': 'Anna Lim',
      'role': 'Admin',
      'action': 'Updated promotion for Summer Sale',
      'module': 'Promotions',
      'dateTime': DateTime(2026, 3, 5, 15, 10),
    },
  ];

  List<Map<String, dynamic>> _filteredLogs = [];

  // ================================================
  // INIT STATE
  // ================================================
  @override
  void initState() {
    super.initState();
    _filteredLogs = _allLogs;
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

  // ================================================
  // APPLY FILTERS
  // ================================================
  void _applyFilters() {
    List<Map<String, dynamic>> results = [];

    for (int i = 0; i < _allLogs.length; i = i + 1) {
      Map<String, dynamic> item = _allLogs[i];
      DateTime itemDate = item['dateTime'] as DateTime;

      bool matchesRole = true;
      if (_selectedRole != null) {
        matchesRole = item['role'] == _selectedRole;
      }
      if (matchesRole == false) continue;

      bool matchesModule = true;
      if (_selectedModule != null) {
        matchesModule = item['module'] == _selectedModule;
      }
      if (matchesModule == false) continue;

      bool matchesStartDate = true;
      if (_selectedStartDate != null) {
        matchesStartDate = itemDate.isAfter(
          _selectedStartDate!.subtract(const Duration(days: 1)),
        );
      }
      if (matchesStartDate == false) continue;

      bool matchesEndDate = true;
      if (_selectedEndDate != null) {
        matchesEndDate = itemDate.isBefore(
          _selectedEndDate!.add(const Duration(days: 1)),
        );
      }
      if (matchesEndDate == false) continue;

      results.add(item);
    }

    setState(() {
      _filteredLogs = results;
      _showFilterPanel = false;
    });
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
      _filteredLogs = _allLogs;
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
  // same pattern as feedback_screen _buildRows()
  // ================================================
  List<List<Widget>> _buildRows() {
    List<List<Widget>> tableRows = [];

    for (int i = 0; i < _filteredLogs.length; i = i + 1) {
      Map<String, dynamic> item = _filteredLogs[i];

      List<Widget> oneRow = [

        // column 1 — name
        Text(
          item['name'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 2 — role
        Text(
          item['role'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 3 — action
        Text(
          item['action'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
          overflow: TextOverflow.ellipsis,
        ),

        // column 4 — affected module
        Text(
          item['module'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 5 — date & time
        Text(
          _formatDateTime(item['dateTime'] as DateTime),
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),
      ];

      tableRows.add(oneRow);
    }

    return tableRows;
  }

  // ================================================
  // BUILD
  // same pattern as feedback_screen build()
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
                  ExportButton(
                    onExport: () => print('Export clicked'),
                    onDropdown: () => print('Dropdown clicked'),
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

                      // filter panel — separated widget ✅
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
                          onApply: _applyFilters,
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