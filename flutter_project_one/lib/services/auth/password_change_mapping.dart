import 'dart:convert';

// ================================================
// PASSWORD CHANGE: what the Auth server said, and what it means
//
// Pure functions with no network and no Flutter, so every rule here can be
// tested without a live Supabase.
//
// The rules below are the ones the Supabase Auth server applies to
// PUT /auth/v1/user when a password is set (read from the server's own source):
//   1. If the account has two-factor authentication and the session is not at
//      the two-factor level (aal2): refuse, code insufficient_aal (HTTP 401).
//   2. If "require reauthentication" is ON in the project and the SESSION is
//      older than 24 hours: a `nonce` (a code emailed by reauthenticate()) is
//      needed, otherwise reauthentication_needed (HTTP 400).
//   3. If "require current password" is ON (and this is not a recovery session):
//      `current_password` must be sent and correct, otherwise
//      current_password_required / current_password_mismatch (HTTP 400).
//   4. If the new password equals the old one: same_password (HTTP 422).
// When a setting is OFF the server simply ignores the matching field, so it is
// always safe to send current_password.
// ================================================

/// How a password change ended. Only [success] means the password changed.
enum PasswordChangeStatus {
  success,
  wrongCurrentPassword,
  needsMfa,
  needsReauthCode,
  reauthCodeInvalid,
  failed,
}

class PasswordChangeResult {
  final PasswordChangeStatus status;

  /// A message that is safe to show to the person. Never a raw exception or
  /// raw server text.
  final String? message;

  const PasswordChangeResult(this.status, this.message);
}

/// The answer of the check "is the current password right?".
enum CurrentPasswordCheck { correct, wrong, rateLimited, network, error }

/// A raw answer from the Auth server: the status code, plus the error code and
/// message when there are any.
class AuthHttpResponse {
  final int status;
  final Map<String, dynamic>? json;

  const AuthHttpResponse(this.status, this.json);

  factory AuthHttpResponse.fromRaw(int status, String body) {
    Map<String, dynamic>? parsed;
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) parsed = decoded;
    } catch (_) {
      parsed = null;
    }
    return AuthHttpResponse(status, parsed);
  }

  bool get ok => status >= 200 && status < 300;

  /// The server's machine-readable error, for example "insufficient_aal".
  String get errorCode {
    final dynamic a = json?['error_code'];
    if (a is String) return a;
    final dynamic b = json?['code'];
    if (b is String) return b; // some answers use a text "code"
    return '';
  }

  /// The server's own wording. Used ONLY for matching, never shown.
  String get serverMessage {
    for (final String key in const ['msg', 'message', 'error_description', 'error']) {
      final dynamic v = json?[key];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }
}

// ---------- "is the current password right?" ----------

CurrentPasswordCheck interpretPasswordGrant(AuthHttpResponse r) {
  if (r.ok) return CurrentPasswordCheck.correct;
  if (r.status == 429 || r.errorCode.contains('rate_limit')) {
    return CurrentPasswordCheck.rateLimited;
  }
  if (r.errorCode == 'invalid_credentials' ||
      r.serverMessage.toLowerCase().contains('invalid login credentials')) {
    return CurrentPasswordCheck.wrong;
  }
  return CurrentPasswordCheck.error;
}

// ---------- the password update itself ----------

const String kMsgSessionExpired = 'Your session has expired. Please log in again.';
const String kMsgTooMany = 'Too many attempts. Please wait a few minutes and try again.';
const String kMsgNetwork =
    'Unable to connect. Please check your internet connection and try again.';
const String kMsgGeneric = 'We couldn\'t update your password. Please try again.';

/// [reauthCodeSent] is true when this request already carried the emailed code.
PasswordChangeResult interpretPasswordUpdate(
  AuthHttpResponse r, {
  required bool reauthCodeSent,
}) {
  if (r.ok) {
    return const PasswordChangeResult(PasswordChangeStatus.success, null);
  }

  final String code = r.errorCode;
  final String msg = r.serverMessage.toLowerCase();

  // 1. Not at the two-factor level.
  if (code == 'insufficient_aal' || msg.contains('aal2')) {
    return const PasswordChangeResult(PasswordChangeStatus.needsMfa, null);
  }

  // 2. A wrong or expired emailed code.
  if (code == 'reauthentication_not_valid' ||
      code == 'reauth_nonce_missing' ||
      (reauthCodeSent && msg.contains('nonce'))) {
    return const PasswordChangeResult(
      PasswordChangeStatus.reauthCodeInvalid,
      'That code is incorrect or has expired. Check your email, or ask for a new code.',
    );
  }

  // 2b. An emailed code is needed.
  if (code == 'reauthentication_needed' ||
      msg.contains('requires reauthentication')) {
    return reauthCodeSent
        ? const PasswordChangeResult(
            PasswordChangeStatus.reauthCodeInvalid,
            'That code is incorrect or has expired. Check your email, or ask for a new code.',
          )
        : const PasswordChangeResult(PasswordChangeStatus.needsReauthCode, null);
  }

  // 3. The server's own current-password check.
  if (code == 'current_password_required' || code == 'current_password_mismatch') {
    return const PasswordChangeResult(
      PasswordChangeStatus.wrongCurrentPassword,
      'Current password is incorrect.',
    );
  }

  // 4. Same password.
  if (code == 'same_password' || msg.contains('different from the old password')) {
    return const PasswordChangeResult(
      PasswordChangeStatus.failed,
      'New password must be different from your current password.',
    );
  }

  // Strength rules set in the Supabase dashboard.
  if (code == 'weak_password' || msg.contains('weak') || msg.contains('password should')) {
    return const PasswordChangeResult(
      PasswordChangeStatus.failed,
      'That password doesn\'t meet the security requirements. Try a longer, more varied password.',
    );
  }

  if (r.status == 429 || code.contains('rate_limit')) {
    return const PasswordChangeResult(PasswordChangeStatus.failed, kMsgTooMany);
  }

  if (r.status == 401) {
    return const PasswordChangeResult(PasswordChangeStatus.failed, kMsgSessionExpired);
  }

  return const PasswordChangeResult(PasswordChangeStatus.failed, kMsgGeneric);
}