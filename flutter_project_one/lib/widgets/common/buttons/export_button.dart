import 'package:flutter/material.dart';

// ================================================
// EXPORT BUTTON — the export button with dropdown
// arrow used in all pages
// ================================================
class ExportButton extends StatelessWidget {

  // things this widget needs from parent screen
  final VoidCallback onExport;    // when user clicks export
  final VoidCallback onDropdown;  // when user clicks dropdown arrow

  const ExportButton({
    super.key,
    required this.onExport,
    required this.onDropdown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
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

          // dropdown arrow button
          IconButton(
            onPressed: onDropdown,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: Color(0xFF6B7280),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}