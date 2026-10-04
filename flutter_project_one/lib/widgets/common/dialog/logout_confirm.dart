import 'package:flutter/material.dart';
import 'confirm_dialog.dart';

/// Asks the user to confirm before logging out.
///
/// Shared by the Cashier, Admin and Super Admin sidebars so the dialog
/// looks and behaves identically for all three roles. Returns true only
/// if the user explicitly pressed "Log out" — cancelling, or tapping
/// outside the dialog, returns false.
///
/// Reuses the app's existing showConfirmDialog, so the styling matches
/// the other confirmation dialogs (archive, discard changes, ...).
Future<bool> confirmLogout(BuildContext context) async {
  final bool? confirmed = await showConfirmDialog(
    context: context,
    title: 'Log out?',
    message: 'Are you sure you want to log out of your account?',
    confirmLabel: 'Log out',
    confirmColor: const Color(0xFFDC2626),
  );
  return confirmed == true;
}