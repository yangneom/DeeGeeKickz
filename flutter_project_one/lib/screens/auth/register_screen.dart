// Basic Flutter import
import 'package:flutter/material.dart';

// Riverpod import
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import our RegisterForm widget that we just built in Step 1
import '../../services/auth/register_form.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_use_screen.dart';

// ================================================
// REGISTER SCREEN
//
// This is the SCREEN that holds the register form
// It is just a container — same as login_screen.dart
//
// The screen is responsible for:
//   - The white background color
//   - Centering the form
//   - Making it scrollable on small screens
//
// The actual form fields and buttons are
// inside RegisterForm widget (Step 1)
// ================================================

// ConsumerWidget means this widget can
// read Riverpod providers if needed
class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    // Get the screen height
    // We use this to make sure the form
    // is always at least as tall as the screen
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(

      // White background
      backgroundColor: Colors.white,

      // SingleChildScrollView makes the screen scrollable
      // Important for small phones when keyboard appears
      body: SingleChildScrollView(
        child: ConstrainedBox(

          // Make sure content is at least as tall as the screen
          // This keeps the form centered even if content is short
          constraints: BoxConstraints(
            minHeight: screenHeight,
          ),

          child: IntrinsicHeight(
            child: Center(

              // Padding around the whole form
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    // This is where our RegisterForm widget goes
                    // All the fields and buttons are inside here
                    // This is the ONLY difference from login_screen.dart
                    const RegisterForm(),

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