// lib/services/auth/password_reset_email_errors.dart
//
// WHAT A 429 FROM "send me a reset code" REALLY MEANS.
//
// Supabase answers HTTP 429 on /auth/v1/recover for different reasons, and the
// right message (and wait) is different for each:
//
//   tooSoon          This address was asked for a code a moment ago. The server
//                    allows one request per 60 seconds, and says how many seconds
//                    are left. One click can hit this if a screen's own countdown
//                    is shorter than the server's.
//   projectCap       The WHOLE PROJECT's email allowance is used up. Sign-up codes,
//                    reset codes and email changes all share it, and the built-in
//                    email service allows very few per hour. Nobody clicked too
//                    much: other emails in the last hour used it.
//   tooManyRequests  Too many requests from this connection (it may be shared).
//
// This file only reads the words and the status code of the error. It does not
// talk to Supabase.

enum ResetEmailLimit { tooSoon, projectCap, tooManyRequests, other }

class ResetEmailFailure {
  final ResetEmailLimit limit;

  /// How long to wait, when the server said so (tooSoon only).
  final int? waitSeconds;

  /// A message safe to show to a person.
  final String message;

  const ResetEmailFailure(this.limit, this.message, {this.waitSeconds});
}

ResetEmailFailure describeResetEmailFailure({
  required String? statusCode,
  required String message,
}) {
  final String lower = message.toLowerCase();

  // The whole project's allowance is used up. Not the person's doing.
  if (lower.contains('email rate limit') ||
      lower.contains('over_email_send_rate_limit')) {
    return const ResetEmailFailure(
      ResetEmailLimit.projectCap,
      'We can\'t send another code right now because our email service has '
      'reached its limit. Please try again in a little while.',
    );
  }

  // A code for this address was sent a moment ago.
  if (lower.contains('security purposes') ||
      (lower.contains('after') && lower.contains('second'))) {
    final Match? m = RegExp(r'after\s+(\d+)\s+second').firstMatch(lower);
    final int? wait = m == null ? null : int.tryParse(m.group(1)!);
    final String how = wait == null ? 'about a minute' : '$wait seconds';
    return ResetEmailFailure(
      ResetEmailLimit.tooSoon,
      'A code was just sent. Please wait $how before asking for another one, '
      'and check your inbox and spam folder.',
      waitSeconds: wait,
    );
  }

  // Too many requests from this connection.
  if (statusCode == '429' || lower.contains('rate limit')) {
    return const ResetEmailFailure(
      ResetEmailLimit.tooManyRequests,
      'Too many requests from your connection. Please wait a few minutes and try again.',
    );
  }

  return const ResetEmailFailure(
    ResetEmailLimit.other,
    'We couldn\'t send the code. Please check your connection and try again.',
  );
}