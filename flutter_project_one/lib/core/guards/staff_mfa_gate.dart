import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/mfa_challenge_screen.dart';
import '../../screens/auth/mfa_enroll_screen.dart';

// ================================================
// STAFF MFA GATE
//
// Wraps the Admin, Super Admin and Cashier layouts (it sits inside
// StaffDeviceGate). Whatever path brought a staff session here (the login form,
// the global listener, a saved session at app start, a refresh, the browser's
// Back button, the Set Password or MFA screens), THIS is the last check before
// any staff screen is built.
//
// WHAT IT CHECKS, in this order, using the SERVER'S CURRENT answer and not saved
// data or a cached role:
//   1. The account's authenticator list (listFactors() asks the server; it
//      refreshes the session first). Only VERIFIED authenticators count.
//   2. Then the session's assurance level (aal1 or aal2).
//
// WHAT IT DOES (see decideStaffMfa):
//   - no verified authenticator  -> the enrolment screen (QR code), whatever the
//     session says. An authenticator that exists but was never verified does NOT
//     count: the enrolment screen removes it and starts a fresh one.
//   - verified authenticator, session still aal1 -> the code screen
//   - verified authenticator AND aal2 -> the staff screens are built
//   - anything fails (server unreachable, no session, timeout) -> NOTHING staff
//     is built. A "could not confirm" screen with Try again / Log out is shown.
//
// While it is checking, only a spinner is shown: the staff screens are never
// built early, so they never start loading data.
//
// It NEVER navigates: the code or enrolment screen is shown IN PLACE of the staff
// screens, so there is no redirect that could loop, and Back cannot reach the
// staff screens. Decided once per gate (and again after the code is accepted).
//
// This is a UI gate. Real authorisation stays server-side (RLS, edge functions).
// ================================================

enum StaffMfaDecision { allowed, mustChallenge, mustEnroll }

/// The whole rule, kept free of Supabase so it can be tested on its own.
/// [verifiedTotpCount] counts VERIFIED authenticators only. An unverified one never counts.
StaffMfaDecision decideStaffMfa({
  required bool isAal2,
  required int verifiedTotpCount,
}) {
  if (verifiedTotpCount <= 0) return StaffMfaDecision.mustEnroll;
  return isAal2 ? StaffMfaDecision.allowed : StaffMfaDecision.mustChallenge;
}

class StaffMfaGate extends StatefulWidget {
  final Widget child;

  const StaffMfaGate({super.key, required this.child});

  @override
  State<StaffMfaGate> createState() => _StaffMfaGateState();
}

enum _GateStage { checking, failed, challenge, enroll, allowed }

class _StaffMfaGateState extends State<StaffMfaGate> {
  _GateStage _stage = _GateStage.checking;
  String? _role;
  // Numbers each check, so an old answer can never overwrite a newer one.
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final int run = ++_run;
    if (_stage != _GateStage.checking && mounted) {
      setState(() => _stage = _GateStage.checking);
    }

    try {
      final auth = Supabase.instance.client.auth;
      final String? userId = auth.currentUser?.id;
      if (userId == null) {
        _settle(run, _GateStage.failed);
        return;
      }

      // The server's CURRENT authenticator list (not saved session data).
      final factors =
          await auth.mfa.listFactors().timeout(const Duration(seconds: 15));
      final aal = auth.mfa.getAuthenticatorAssuranceLevel();

      final StaffMfaDecision decision = decideStaffMfa(
        isAal2: aal.currentLevel == AuthenticatorAssuranceLevels.aal2,
        verifiedTotpCount: factors.totp.length,
      );

      // Only the code screen needs the role (Super Admin gets the recovery link).
      String? role;
      if (decision == StaffMfaDecision.mustChallenge) {
        try {
          final row = await Supabase.instance.client
              .from('users')
              .select('role')
              .eq('id', userId)
              .maybeSingle();
          role = row?['role'] as String?;
        } catch (_) {
          // The code screen still works without it; only the recovery link is hidden.
        }
      }

      if (!mounted || run != _run) return;
      setState(() {
        _role = role;
        _stage = switch (decision) {
          StaffMfaDecision.allowed => _GateStage.allowed,
          StaffMfaDecision.mustChallenge => _GateStage.challenge,
          StaffMfaDecision.mustEnroll => _GateStage.enroll,
        };
      });
    } catch (e) {
      // Fail CLOSED. Only the type is printed, never the message.
      print('StaffMfaGate check failed: ${e.runtimeType}');
      _settle(run, _GateStage.failed);
    }
  }

  void _settle(int run, _GateStage stage) {
    if (!mounted || run != _run) return;
    setState(() => _stage = stage);
  }

  Future<void> _logOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Leave the staff screens even if signing out fails (no connection).
    }
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _GateStage.allowed:
        return widget.child;

      case _GateStage.challenge:
        // Shown IN PLACE of the staff screens. When the code is accepted the
        // session is aal2, so the next check lets the staff screens through.
        return MfaChallengeScreen(
          role: _role,
          onVerified: () {
            _check();
          },
        );

      case _GateStage.enroll:
        // Finishing enrolment signs the person out and returns to login, exactly
        // as it always has.
        return const MfaEnrollScreen();

      case _GateStage.failed:
        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 36, color: Color(0xFF6B7280)),
                    const SizedBox(height: 16),
                    const Text(
                      'We couldn\'t confirm your two-factor authentication status.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'For your security, the staff screens stay closed until it is confirmed. '
                      'Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _check,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Try again'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _logOut, child: const Text('Log out')),
                  ],
                ),
              ),
            ),
          ),
        );

      case _GateStage.checking:
        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: CircularProgressIndicator()),
        );
    }
  }
}
