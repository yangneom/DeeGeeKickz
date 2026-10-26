import 'package:flutter/material.dart';
import '../../../core/utils/password_reminder_snooze.dart';

// ================================================
// PASSWORD REMINDER DIALOG
//
// The "Time to update your password" reminder, written ONCE and used by the
// Admin, Super Admin and Cashier top bars. It is the Admin version's look,
// exactly: white card, 12px corners, titled header with a divider, a short
// body, a "Later" outline button and a blue "Change Now" button.
//
// What it does NOT do:
//   - decide WHEN to show (each top bar still calls isPasswordChangeDue()
//     itself, unchanged);
//   - decide what "Change Now" opens. The top bar passes that in as
//     [onChangeNow], so every role keeps its own existing behaviour.
//
// "Later", and tapping outside the dialog, close it AND snooze the reminder
// for 24 hours (PasswordReminderSnooze). That never touches the password
// timestamp: it does not mark the password as changed.
// "Change Now" does not snooze: if the person opens the form and walks away,
// the reminder is still there next time.
// ================================================
Future<void> showPasswordReminderDialog({
  required BuildContext context,
  required VoidCallback onChangeNow,
}) async {
  bool changeNow = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      // Material 3 otherwise tints dialog surfaces from the theme colour
      // scheme (the pinkish look the Super Admin version had to fix).
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time to update your password',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'For account security',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'It\'s been 30 days or more since your last password change. '
                    'Please update it to keep your account secure.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Later', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            changeNow = true;
                            Navigator.pop(dialogContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Change Now', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  if (changeNow) {
    onChangeNow();
  } else {
    // "Later" or a tap outside the dialog.
    await PasswordReminderSnooze.snoozeForCurrentUser();
  }
}