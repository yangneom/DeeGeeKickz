import 'package:flutter/material.dart';

// ================================================
// ACTIVITY LOG FILTER PANEL
//
// Custom filter panel for Activity Log screen
// Cannot use common FilterButton because this
// needs TWO independent selected values:
//   - Role (Cashier, Admin, Super Admin)
//   - Affected Module (Inventory, Orders, etc.)
//   - Date Range (start + end date)
// ================================================
class ActivityLogFilterPanel extends StatelessWidget {

  // currently selected values
  final String? selectedRole;
  final String? selectedModule;
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;

  // callbacks
  final Function(String?) onRoleChanged;
  final Function(String?) onModuleChanged;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onClear;
  final VoidCallback onApply;

  const ActivityLogFilterPanel({
    super.key,
    required this.selectedRole,
    required this.selectedModule,
    required this.selectedStartDate,
    required this.selectedEndDate,
    required this.onRoleChanged,
    required this.onModuleChanged,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onClear,
    required this.onApply,
  });

  // ================================================
  // BUILD FILTER CHIP
  // same style as our existing buttons
  // ================================================
  Widget _buildFilterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEFF6FF)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  // ================================================
  // BUILD DATE FIELD
  // ================================================
  Widget _buildDateField(
    String label,
    DateTime? date,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 8),
            Text(
              date != null
                  ? '${date.month.toString().padLeft(2, '0')}-'
                    '${date.day.toString().padLeft(2, '0')}-'
                    '${date.year}'
                  : label,
              style: TextStyle(
                fontSize: 12,
                color: date != null
                    ? const Color(0xFF111827)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // BUILD SECTION LABEL
  // matches FilterPanel widget style
  // ================================================
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFF374151),
      ),
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 46,
      right: 0,
      child: Material(
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
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── HEADER ──
              const Text(
                'Filter',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),

              const SizedBox(height: 12),

              // ── ROLE ──
              _buildSectionLabel('Role'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'Cashier',
                  'Admin',
                  'Super Admin',
                ].map((role) {
                  return _buildFilterChip(
                    role,
                    selectedRole == role,
                    () => onRoleChanged(
                      selectedRole == role ? null : role,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 12),

              // ── AFFECTED MODULE ──
              _buildSectionLabel('Affected Module'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'Inventory',
                  'Orders',
                  'Sales',
                  'Promotions',
                  'Admin Management',
                ].map((module) {
                  return _buildFilterChip(
                    module,
                    selectedModule == module,
                    () => onModuleChanged(
                      selectedModule == module ? null : module,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 12),

              // ── DATE RANGE ──
              _buildSectionLabel('Date Range'),
              const SizedBox(height: 8),
              _buildDateField(
                'Start date',
                selectedStartDate,
                onPickStartDate,
              ),
              const SizedBox(height: 8),
              _buildDateField(
                'End date',
                selectedEndDate,
                onPickEndDate,
              ),

              const SizedBox(height: 14),

              // ── CLEAR + APPLY ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onClear,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(
                          color: Color(0xFFD1D5DB),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'Filter',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}