import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================
// PASSWORD REMINDER SNOOZE  ("Later")
//
// "Later" hides the 30-day reminder for [period] on THIS device, for THIS
// account. It is deliberately separate from the password timestamp:
//   - it never marks the password as changed;
//   - it only affects whether the reminder shows, nothing else;
//   - if storage is unavailable it fails OPEN (the reminder simply shows),
//     so a storage problem can never hide the reminder permanently.
//
// Being a local convenience, it is not a security control. The reminder is a
// nudge; the real record of the last change lives in the database.
// ================================================
class PasswordReminderSnooze {
  PasswordReminderSnooze._();

  /// How long "Later" hides the reminder.
  static const Duration period = Duration(hours: 24);

  static const String _prefix = 'password_reminder_snooze_v1:';

  // Replaceable so the timing can be tested without waiting a day.
  static DateTime Function() now = DateTime.now;

  static String _key(String userId) => '$_prefix$userId';

  static Future<bool> isSnoozed(String userId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? untilMs = prefs.getInt(_key(userId));
      if (untilMs == null) return false;
      return now().millisecondsSinceEpoch < untilMs;
    } catch (_) {
      return false;
    }
  }

  static Future<void> snooze(String userId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _key(userId),
        now().add(period).millisecondsSinceEpoch,
      );
    } catch (_) {
      // Nothing to do: the reminder will just show again next time.
    }
  }

  /// Snoozes for whoever is signed in right now.
  static Future<void> snoozeForCurrentUser() async {
    final String? userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await snooze(userId);
  }

  static Future<void> clear(String userId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (_) {}
  }
}