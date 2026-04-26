import 'package:flutter/material.dart';

// ================================================
// REUSABLE CONFIRMATION DIALOG
//
// Use this anywhere you need an "Are you sure?"
// prompt before performing a destructive or
// important action (archive, restore, delete, etc.)
//
// HOW TO USE:
//
//   final confirmed = await showConfirmDialog(
//     context: context,
//     title: 'Restore this product in the inventory?',
//     message: 'This product will be moved back to active '
//               'inventory and will be available for transactions.',
//     confirmLabel: 'Restore Product',
//     confirmColor: Color(0xFF2563EB), // blue
//   );
//
//   if (confirmed == true) {
//     // do the action
//   }
//
// PARAMETERS:
//   title        — bold heading question
//   message      — supporting explanation text
//   confirmLabel — text on the confirm button (default: 'Confirm')
//   confirmColor — color of the confirm button (default: blue)
//   cancelLabel  — text on the cancel button  (default: 'Cancel')
// ================================================

Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  Color confirmColor = const Color(0xFF2563EB),
  String cancelLabel = 'Cancel',
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
        cancelLabel: cancelLabel,
      );
    },
  );
}

// ================================================
// CONFIRM DIALOG WIDGET
// ================================================
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final String cancelLabel;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.cancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 420,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ---- TITLE ----
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),

            const SizedBox(height: 10),

            // ---- MESSAGE ----
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            // ---- BUTTONS ----
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [

                // Cancel button
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    cancelLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Confirm button
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    confirmLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}