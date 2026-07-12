import 'package:flutter/material.dart';
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
// ================================================

class SetPasswordScreen extends StatelessWidget {
  const SetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

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
                  children: const [
                    SetPasswordForm(),
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