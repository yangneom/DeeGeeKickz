// Basic Flutter import
import 'package:flutter/material.dart';

// Riverpod import
// ProviderScope is needed to wrap screens that use Riverpod
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import our LoginForm widget that we just built
import '../../widgets/auth/login_form.dart';

// ================================================
// LOGIN SCREEN
//
// This is the SCREEN that holds the login form
// Think of this as the "page" or "container"
//
// The screen is responsible for:
//   - The background color
//   - Centering the form
//   - Making it scrollable on small screens
//   - Responsive layout
//
// The actual form fields and buttons are
// inside LoginForm widget
// ================================================

// ConsumerWidget means this widget can
// read Riverpod providers
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    // Get the screen width to make layout responsive
    final double screenWidth = MediaQuery.of(context).size.width;

    // Get the screen height
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(

      // White background color
      backgroundColor: Colors.white,

      // SingleChildScrollView makes the screen scrollable
      // This is important for small phones when keyboard appears
      body: SingleChildScrollView(
        child: ConstrainedBox(

          // Make sure the content is at least as tall as the screen
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

                    // This is where our LoginForm widget goes
                    // All the form fields and buttons are inside here
                    const LoginForm(),

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