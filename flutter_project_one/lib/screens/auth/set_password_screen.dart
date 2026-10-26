import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/auth/set_password_form.dart';

// ================================================
// SET PASSWORD SCREEN
//
// Container screen for the SetPasswordForm.
// Matches the same layout as LoginScreen.
//
// This screen is shown when:
//   - A staff member clicks their invite email link
//   - main.dart detects password_set = false
//     and navigates here automatically
//
// WIDTH: the form is at most 400px wide, and on a narrow phone 85% of the screen.
// A SizedBox can never be wider than the space it is offered, so it cannot
// overflow a very small screen either.
//
// REFUSED LINK: an invitation link works ONCE. If Supabase refuses it (already
// used, expired, or the account was removed) it opens this page with
// "#error=access_denied&error_code=otp_expired..." in the address and NO session.
// Before, the page then showed the normal form, and pressing the button said
// "Auth session is missing!". Now it says plainly what happened and offers a way
// back. A real invite (which has a session) shows the form exactly as before.
// ================================================

/// True when the page was opened from an email link that Supabase refused.
/// It only reads the address; it does not talk to Supabase.
bool linkWasRefused(Uri uri) {
  final String text = '${uri.fragment}&${uri.query}';
  return text.contains('error_code=otp_expired') ||
      text.contains('error=access_denied');
}

class SetPasswordScreen extends StatelessWidget {
  const SetPasswordScreen({super.key});

  // The widest the form is allowed to be (the login form uses 400 too).
  static const double _maxFormWidth = 400;

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    final double rawWidth = screenWidth * 0.85;
    final double formWidth = rawWidth < _maxFormWidth ? rawWidth : _maxFormWidth;

    // The address is checked FIRST, and the session only if the address says the
    // link was refused. A person who is actually signed in (a valid invite, or a
    // staff member sent here after logging in) always gets the normal form.
    final bool refused = linkWasRefused(Uri.base) &&
        Supabase.instance.client.auth.currentSession == null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: screenHeight),
          child: IntrinsicHeight(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: formWidth,
                      child: refused
                          ? const _RefusedLinkCard()
                          : const SetPasswordForm(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RefusedLinkCard extends StatelessWidget {
  const _RefusedLinkCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This invitation link can\'t be used',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'It has expired, or it was already used. Each invitation link works '
          'only once. Ask a Super Admin to send you a new invitation.',
          style: TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (route) => false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Back to login',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}