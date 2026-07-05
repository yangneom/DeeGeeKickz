import 'package:flutter/material.dart';

// ================================================
// TABLE PILL BUTTON
//
// Small solid rounded-rectangle button with a white
// icon + label, matching the existing "Archive"
// button style used elsewhere in the admin tables.
//
// Reused by BannersTable and DiscountsTable for their
// Edit / Delete row actions (previously plain text+icon).
// ================================================
class TablePillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const TablePillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  // ── Convenience constructors ──

  const TablePillButton.edit({
    super.key,
    required this.onPressed,
  })  : label = 'Edit',
        icon = Icons.edit_outlined,
        color = const Color(0xFF2563EB);

  const TablePillButton.delete({
    super.key,
    required this.onPressed,
  })  : label = 'Delete',
        icon = Icons.delete_outline,
        color = const Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}