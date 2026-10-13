import 'package:flutter/material.dart';

// ================================================
// EXPORT BUTTON — the export button with dropdown
// arrow used in all pages
//
// Behavior is unchanged:
//   - clicking "Export" itself  -> onExport (quick CSV export)
//   - dropdown pick             -> onFormatSelected('csv' | 'excel')
//
// Visual fix: the dropdown menu had no explicit color, so Material 3
// filled it with a tint derived from the app theme (the pink look).
// It now uses a white surface with no tint, a subtle border and
// shadow, and the same corner radius as the rest of the UI.
// ================================================
class ExportButton extends StatelessWidget {

  // things this widget needs from parent screen
  final VoidCallback onExport;               // clicking "Export" itself = quick CSV export
  final void Function(String format) onFormatSelected; // dropdown pick: 'csv' or 'excel'

  const ExportButton({
    super.key,
    required this.onExport,
    required this.onFormatSelected,
  });

  // one menu row: file-type icon + label
  PopupMenuItem<String> _menuItem({
    required String value,
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [

          // export text button
          TextButton(
            onPressed: onExport,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF374151),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            child: const Text(
              'Export',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // divider line between export and arrow
          Container(
            width: 1,
            height: 20,
            color: const Color(0xFFD1D5DB),
          ),

          // dropdown arrow — shows the format choice menu
          PopupMenuButton<String>(
            onSelected: onFormatSelected,
            tooltip: 'Export format',
            // opens BELOW the control instead of on top of it
            position: PopupMenuPosition.under,
            offset: const Offset(0, 6),
            // white surface, no theme tint, subtle border + shadow
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.black.withOpacity(0.12),
            elevation: 6,
            constraints: const BoxConstraints(minWidth: 200),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: Color(0xFF6B7280),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemBuilder: (context) => [
              _menuItem(
                value: 'csv',
                icon: Icons.description_outlined,
                label: 'Export as CSV',
              ),
              _menuItem(
                value: 'excel',
                icon: Icons.table_chart_outlined,
                label: 'Export as Excel (.xlsx)',
              ),
            ],
          ),
        ],
      ),
    );
  }
}