import 'package:supabase_flutter/supabase_flutter.dart';

/// The database's answer about an email address.
///   ok          - fine to continue
///   invalid     - empty or not shaped like an email address
///   notGmail    - a valid address, but not @gmail.com (customers use Gmail only)
///   disposable  - a temporary-email provider
///   taken       - already belongs to a verified account
///   unavailable - the check itself could not run (no connection, or the
///                 database script has not been installed yet)
enum EmailPolicyResult { ok, invalid, notGmail, disposable, taken, unavailable }

/// Asks the database (check_email_policy) whether an email address may be
/// used, so the screen can show an inline error BEFORE anything is sent.
///
/// This is only the first line of defence and the friendly one. The part that
/// cannot be bypassed is a trigger inside Supabase itself, which refuses to
/// create an account, or to start an email change, for a blocked domain no
/// matter which app or tool made the request.
///
/// If the check cannot run (unavailable) the screen carries on, because that
/// trigger still enforces the rule.
class EmailPolicyService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String disposableMessage =
      'Temporary email addresses are not allowed. Please use a permanent email address.';
  static const String takenMessage = 'An account already exists with this email.';
  static const String invalidMessage = 'Please enter a valid email address.';
  static const String notGmailMessage = 'Please use a Gmail address that ends in @gmail.com.';

  Future<EmailPolicyResult> check(String email) async {
    try {
      final dynamic answer = await _supabase.rpc(
        'check_email_policy',
        params: {'p_email': email.trim().toLowerCase()},
      );

      if (answer == 'ok') return EmailPolicyResult.ok;
      if (answer == 'invalid') return EmailPolicyResult.invalid;
      if (answer == 'not_gmail') return EmailPolicyResult.notGmail;
      if (answer == 'disposable') return EmailPolicyResult.disposable;
      if (answer == 'taken') return EmailPolicyResult.taken;
      return EmailPolicyResult.unavailable;
    } catch (_) {
      return EmailPolicyResult.unavailable;
    }
  }

  /// The inline message for a result, or null when there is nothing to show.
  static String? messageFor(EmailPolicyResult result) {
    switch (result) {
      case EmailPolicyResult.disposable:
        return disposableMessage;
      case EmailPolicyResult.taken:
        return takenMessage;
      case EmailPolicyResult.invalid:
        return invalidMessage;
      case EmailPolicyResult.notGmail:
        return notGmailMessage;
      case EmailPolicyResult.ok:
      case EmailPolicyResult.unavailable:
        return null;
    }
  }

  /// When the database trigger refuses an account, Supabase only says
  /// "Database error saving new user". Turn that into something a customer can
  /// act on; every other message passes through unchanged.
  static String friendlyRegisterError(String raw) {
    final String lower = raw.toLowerCase();

    if (lower.contains('database error')) {
      return 'We couldn\'t create an account with that email address. '
          'If it is a temporary email address, please use a permanent one.';
    }

    // The verification email could not be sent: Supabase caps how many emails
    // the whole project may send per hour. This is not the customer's fault
    // and not about their own attempts, so say so.
    if (lower.contains('email rate limit') ||
        lower.contains('over_email_send_rate_limit')) {
      return 'We couldn\'t send your verification email right now because too '
          'many emails were requested. Please wait a few minutes and try again.';
    }

    // Too many sign-up requests from this connection (HTTP 429).
    if (lower.contains('rate limit') ||
        lower.contains('too many') ||
        lower.contains('over_request_rate_limit') ||
        RegExp(r'\b429\b').hasMatch(lower)) {
      return 'Too many sign-up attempts. Please wait a few minutes and try again.';
    }

    return raw;
  }
}