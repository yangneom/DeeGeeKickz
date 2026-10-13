// Basic Flutter import
import 'package:flutter/material.dart';

// Riverpod import
import 'package:flutter_riverpod/flutter_riverpod.dart';

// The form itself
import '../../services/auth/register_form.dart';
import '../../widgets/common/forms/auth_form_fields.dart';

// ================================================
// REGISTER SCREEN
//
// Just the container for the sign-up form — same idea as
// login_screen.dart. It is responsible for:
//   - the white background
//   - the Back button
//   - centering the form and making it scrollable on small screens
//
// The fields and buttons live in RegisterForm.
// ================================================
class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    // We use the screen height to make sure the form is always at least
    // as tall as the screen (keeps it centered when the content is short).
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,

      // Scrollable, which matters on small phones when the keyboard opens.
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── BACK BUTTON ──
                  // A real button now: reachable with the keyboard and
                  // announced by screen readers.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 24, 0),
                    child: AuthBackButton(
                      label: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            RegisterForm(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}