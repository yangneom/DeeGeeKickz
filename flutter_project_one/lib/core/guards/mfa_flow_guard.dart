// ================================================
// MFA FLOW GUARD
//
// Two jobs, both about NOT doing the same MFA thing twice.
//
// 1. WHICH MFA SCREENS ARE ON SCREEN RIGHT NOW.
//    The app-wide auth listener in main.dart used to push its own MFA screen
//    (replacing the whole screen stack) every time it saw a sign-in event, even
//    when the person was already on an MFA screen. It reacts to events that
//    arrive late (the login's own event, one from another open tab, the start-up
//    event), so it could throw away the recovery-code screen and show a second
//    MFA prompt, or start a second authenticator enrolment.
//    Each MFA screen now registers here while it is open, and the listener checks
//    before it replaces anything. This only stops a DUPLICATE MFA screen: the
//    person still has to pass the MFA screen that is already showing.
//
// 2. ONE AUTHENTICATOR ENROLMENT PER ATTEMPT.
//    Asking Supabase to enrol an authenticator creates a NEW factor every time.
//    If two enrol screens exist for a moment (login form plus the listener, or
//    start-up plus the listener) both used to ask, leaving an orphan factor behind
//    and showing the loading spinner twice. Now they share one request.
//
// The enrolment details (they contain the setup secret) live only in memory, are
// never printed, and are forgotten as soon as the last enrol screen closes.
// ================================================

enum MfaScreenKind { enroll, challenge, recovery }

/// What Supabase returned for a new authenticator. Held in memory only.
class MfaEnrollment {
  final String factorId;

  /// The provisioning address that the QR code is drawn from. It contains the
  /// secret, so it is never printed or logged.
  final String uri;

  /// The same secret as text, for the optional "enter the key manually" fallback.
  final String secret;

  const MfaEnrollment({
    required this.factorId,
    required this.uri,
    required this.secret,
  });

  // A stray print() or log line must never reveal the secret.
  @override
  String toString() => 'MfaEnrollment(factorId: $factorId, uri: ***, secret: ***)';
}

class MfaFlowGuard {
  MfaFlowGuard._();

  // ---- 1. which MFA screens are open ----------------------------------------

  // A COUNT, not a flag: when one screen replaces another, the new one opens
  // before the old one closes, so for a moment two are open.
  static final Map<MfaScreenKind, int> _open = <MfaScreenKind, int>{
    for (final MfaScreenKind k in MfaScreenKind.values) k: 0,
  };

  static void opened(MfaScreenKind kind) {
    _open[kind] = (_open[kind] ?? 0) + 1;
  }

  static void closed(MfaScreenKind kind) {
    final int next = (_open[kind] ?? 0) - 1;
    _open[kind] = next < 0 ? 0 : next;
  }

  static bool isShowing(MfaScreenKind kind) => (_open[kind] ?? 0) > 0;

  /// True while any MFA screen (enrol, challenge or recovery code) is open.
  static bool get anyShowing => _open.values.any((int n) => n > 0);

  // ---- 2. one enrolment per attempt -----------------------------------------

  static String? _enrollUserId;
  static Future<MfaEnrollment>? _enrollment;

  /// Runs [start] at most once per attempt for [userId]. Everyone who asks while
  /// it is running, or after it succeeded, gets the SAME result. A FAILED attempt
  /// is not remembered, so asking again really tries again.
  static Future<MfaEnrollment> enrollOnce({
    required String userId,
    required Future<MfaEnrollment> Function() start,
  }) {
    final Future<MfaEnrollment>? existing = _enrollment;
    if (existing != null && _enrollUserId == userId) return existing;

    final Future<MfaEnrollment> attempt = start();
    _enrollUserId = userId;
    _enrollment = attempt;

    attempt.then<void>((MfaEnrollment _) {}, onError: (Object _) {
      if (identical(_enrollment, attempt)) {
        _enrollment = null;
        _enrollUserId = null;
      }
    });

    return attempt;
  }

  /// Forget the current enrolment, so the next enrol screen asks for a new one.
  static void forgetEnrollment() {
    _enrollment = null;
    _enrollUserId = null;
  }

  /// For tests only.
  static void resetForTests() {
    for (final MfaScreenKind k in MfaScreenKind.values) {
      _open[k] = 0;
    }
    forgetEnrollment();
  }
}