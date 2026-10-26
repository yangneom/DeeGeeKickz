// lib/services/auth/login_attempt_guard.dart

import 'package:shared_preferences/shared_preferences.dart';

// ================================================
// LOGIN ATTEMPT GUARD  —  CLIENT-SIDE ONLY
//
// *** THIS IS NOT A SECURITY CONTROL. ***
// It runs inside the app, on the customer's own device. Anyone who clears
// their browser storage, uses another browser, or calls Supabase's login
// address directly is not slowed down by it at all.
//
// WHAT IT IS FOR: honest users. After 5 consecutive wrong passwords for an
// email address, it stops sending login requests for 15 minutes and tells the
// person why, instead of letting them keep hammering the login box. It also
// makes the app behave the way the five-attempt rule is described.
//
// WHAT ACTUALLY PROTECTS THE ACCOUNT (server-enforced, by Supabase):
//   - Supabase's own per-IP limit on sign-in requests (Authentication ->
//     Rate Limits in the dashboard)
//   - CAPTCHA, if it is switched on there
//   - MFA (a 6-digit code) for Admin, Cashier and Super Admin
//
// HOW IT COUNTS:
//   - Only CREDENTIAL failures count ("Invalid login credentials"). Network
//     errors, rate-limit answers, unconfirmed emails and suspended accounts
//     are not wrong passwords, so they never count.
//   - The count is kept per email address as typed (case and spaces ignored),
//     whether or not an account exists, so the behaviour is identical for a
//     real and an unknown address: it reveals nothing about who is registered.
//   - "Consecutive": a successful login resets the count to zero.
//   - After the 15 minutes the count starts again from zero.
//   - It is kept in shared_preferences, so a page reload does not clear it.
//   - If storage is unavailable it fails OPEN: it never blocks a login
//     because of its own problem.
//
// WHAT IT DOES NOT TOUCH: sessions that already exist, token refresh, and MFA
// code checks. It is only consulted by AuthService.login().
// ================================================
class LoginAttemptGuard {
  LoginAttemptGuard._();

  static const int maxAttempts = 5;
  static const Duration cooldown = Duration(minutes: 15);

  static const String _prefix = 'login_guard_v1:';

  // Replaceable so the timing can be tested without waiting 15 minutes.
  static DateTime Function() clock = DateTime.now;

  static final Map<String, _AttemptState> _memory = <String, _AttemptState>{};

  static String _key(String email) => email.trim().toLowerCase();

  static Future<_AttemptState> _load(String key) async {
    final _AttemptState? cached = _memory[key];
    if (cached != null) return cached;

    int failures = 0;
    DateTime? lockedUntil;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('$_prefix$key');
      if (raw != null) {
        final List<String> parts = raw.split('|');
        failures = int.tryParse(parts[0]) ?? 0;
        final int? millis = parts.length > 1 ? int.tryParse(parts[1]) : null;
        if (millis != null && millis > 0) {
          lockedUntil = DateTime.fromMillisecondsSinceEpoch(millis);
        }
      }
    } catch (_) {
      // Storage unavailable: carry on with an empty, in-memory state.
    }

    final _AttemptState state = _AttemptState(failures, lockedUntil);
    _memory[key] = state;
    return state;
  }

  static Future<void> _save(String key, _AttemptState state) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (state.failures == 0 && state.lockedUntil == null) {
        await prefs.remove('$_prefix$key');
      } else {
        final int millis = state.lockedUntil?.millisecondsSinceEpoch ?? 0;
        await prefs.setString('$_prefix$key', '${state.failures}|$millis');
      }
    } catch (_) {
      // Storage unavailable: the in-memory copy still works for this session.
    }
  }

  /// How long this email address is still locked out, or null if it may try.
  static Future<Duration?> remainingLock(String email) async {
    final String key = _key(email);
    final _AttemptState state = await _load(key);

    final DateTime? until = state.lockedUntil;
    if (until == null) return null;

    final DateTime now = clock();
    if (now.isBefore(until)) {
      Duration remaining = until.difference(now);
      // A clock that jumped can never create a lock longer than the cooldown.
      if (remaining > cooldown) remaining = cooldown;
      return remaining;
    }

    // The cooldown is over: start counting again from zero.
    state.failures = 0;
    state.lockedUntil = null;
    await _save(key, state);
    return null;
  }

  /// Call after a wrong password. Returns the lock time if THIS failure was
  /// the one that triggered the lock, otherwise null.
  static Future<Duration?> recordFailure(String email) async {
    final String key = _key(email);
    final _AttemptState state = await _load(key);
    final DateTime now = clock();

    final DateTime? until = state.lockedUntil;
    if (until != null) {
      if (now.isBefore(until)) return until.difference(now);
      state.failures = 0;
      state.lockedUntil = null;
    }

    state.failures += 1;

    Duration? triggered;
    if (state.failures >= maxAttempts) {
      state.lockedUntil = now.add(cooldown);
      triggered = cooldown;
    }

    await _save(key, state);
    return triggered;
  }

  /// Call after a successful login: the failed-attempt count starts over.
  static Future<void> recordSuccess(String email) async {
    final String key = _key(email);
    final _AttemptState state = _AttemptState(0, null);
    _memory[key] = state;
    await _save(key, state);
  }

  static String lockedMessage(Duration remaining) {
    int minutes = (remaining.inSeconds / 60).ceil();
    if (minutes < 1) minutes = 1;
    if (minutes > 15) minutes = 15;
    final String unit = minutes == 1 ? 'minute' : 'minutes';
    return 'Too many failed login attempts. '
        'Please wait $minutes $unit before trying again.';
  }

  /// For tests only: forget everything held in memory.
  static void resetMemoryForTests() => _memory.clear();
}

class _AttemptState {
  int failures;
  DateTime? lockedUntil;

  _AttemptState(this.failures, this.lockedUntil);
}