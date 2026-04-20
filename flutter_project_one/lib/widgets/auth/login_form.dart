// Basic Flutter import
import 'package:flutter/material.dart';

// Riverpod import
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Our providers
import '../../providers/auth/auth_provider.dart';

// Import RegisterScreen so we can navigate to it when user taps Sign Up
import '../../screens/auth/register_screen.dart';

// Import AdminLayout for role-based navigation
import '../../screens/admin/admin_layout.dart';

// TODO: Import these screens later when built
// import '../../screens/cashier/cashier_layout.dart';
// import '../../screens/customer/customer_layout.dart';

// ================================================
// LOGIN FORM WIDGET
//
// This widget contains:
//   - Email text field
//   - Password text field
//   - Remember me checkbox
//   - Forgot password link
//   - Login button
//   - Sign up link
//
// ConsumerStatefulWidget means this widget:
//   - Has its own state (can use setState)
//   - Can also read Riverpod providers (ref.watch)
// ================================================
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {

  // ================================================
  // CONTROLLERS
  // Controllers let us READ what the user typed
  // ================================================
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // ================================================
  // LOCAL STATE VARIABLES
  // ================================================

  // Controls if password is visible or hidden
  bool _isPasswordVisible = false;

  // Controls the remember me checkbox
  bool _rememberMe = false;

  // ================================================
  // FORM KEY
  // Used to validate the form before login
  // ================================================
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // ================================================
  // DISPOSE
  // Clean up controllers when widget is removed
  // ================================================
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ================================================
  // HANDLE LOGIN FUNCTION
  //
  // Step 1 - Validate the form
  // Step 2 - Set loading to true
  // Step 3 - Call AuthService to login
  // Step 4 - Fetch user role from Firestore
  // Step 5 - Navigate based on role
  // Step 6 - Handle any errors
  // ================================================
  Future<void> _handleLogin() async {

    // Step 1 - Validate form
    // If any field is empty or invalid stop here
    bool formIsValid = _formKey.currentState!.validate();
    if (formIsValid == false) {
      return;
    }

    // Step 2 - Set loading to true
    // Shows spinner on the button
    ref.read(isLoadingProvider.notifier).setLoading(true);

    // Clear any old error message from previous attempt
    ref.read(errorMessageProvider.notifier).setError(null);

    // Wrap everything in try/catch
    // So if ANYTHING goes wrong we handle it cleanly
    try {

      // Step 3 - Call AuthService to login
      // Returns null if successful
      // Returns error string if failed
      final authService = ref.read(authServiceProvider);

      final String? errorMessage = await authService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // If login failed show the error message and stop
      if (errorMessage != null) {
        ref.read(errorMessageProvider.notifier).setError(errorMessage);
        return;
      }

      // Step 4 - Login was successful
      // Now fetch the user's role from Firestore
      // So we know which screen to navigate to
      final String? role = await authService.getUserRole();

      // Step 5 - Check if widget is still on screen
      // before navigating
      // This prevents errors if user closed the screen
      // while waiting for the login to complete
      if (!mounted) return;

      // Navigate based on role
      if (role == 'admin' || role == 'super_admin') {

        // Admin and Super Admin go to Admin Layout
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminLayout(),
          ),
        );

      } else if (role == 'cashier') {

        // TODO: Navigate to CashierLayout once created
        ref.read(errorMessageProvider.notifier).setError(
          'Cashier screen coming soon.',
        );

      } else if (role == 'customer') {

        // TODO: Navigate to CustomerLayout once created
        ref.read(errorMessageProvider.notifier).setError(
          'Customer screen coming soon.',
        );

      } else {

        // Role is null or unknown
        // This should not happen but handle it just in case
        ref.read(errorMessageProvider.notifier).setError(
          'Unknown role. Please contact support.',
        );

      }

    } catch (error) {

      // Step 6 - Something unexpected went wrong
      // Show a generic error message
      // This catches things like no internet connection
      // or any other unexpected error
      ref.read(errorMessageProvider.notifier).setError(
        'Something went wrong. Please try again.',
      );

    } finally {

      // This runs whether login succeeded or failed
      // ALWAYS set loading back to false here
      // So the button never gets stuck in loading state
      ref.read(isLoadingProvider.notifier).setLoading(false);

    }
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {

    // Read loading and error state from providers
    final bool isLoading = ref.watch(isLoadingProvider);
    final String? errorMessage = ref.watch(errorMessageProvider);

    // Responsiveness
    final double screenWidth = MediaQuery.of(context).size.width;

    double formWidth;
    if (screenWidth > 600) {
      formWidth = 400;
    } else {
      formWidth = screenWidth * 0.85;
    }

    return Form(
      key: _formKey,
      child: SizedBox(
        width: formWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ================================================
            // LOGO
            // ================================================
            Center(
              child: Image.asset(
                'assets/images/logo.jpg',
                height: 100,
                width: 100,
              ),
            ),

            const SizedBox(height: 20),

            // ================================================
            // TITLE
            // ================================================
            const Center(
              child: Text(
                'Log in to Your Account',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ================================================
            // SUBTITLE
            // ================================================
            const Center(
              child: Text(
                'Enter your credentials to continue',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ================================================
            // EMAIL LABEL
            // ================================================
            const Text(
              'Email Address',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 8),

            // ================================================
            // EMAIL TEXT FIELD
            // ================================================
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Enter your email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ================================================
            // PASSWORD LABEL
            // ================================================
            const Text(
              'Password',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 8),

            // ================================================
            // PASSWORD TEXT FIELD
            // ================================================
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                hintText: 'Enter your password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            // ================================================
            // REMEMBER ME + FORGOT PASSWORD ROW
            // ================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                // Remember Me checkbox on the left
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (bool? value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                    ),
                    const Text(
                      'Remember Me',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),

                // Forgot Password link on the right
                GestureDetector(
                  onTap: () {
                    // TODO: Navigate to forgot password screen later
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ================================================
            // ERROR MESSAGE BOX
            // Only shows when there is an error
            // ================================================
            if (errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.shade200,
                  ),
                ),
                child: Text(
                  errorMessage,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
              ),

            if (errorMessage != null) const SizedBox(height: 16),

            // ================================================
            // LOGIN BUTTON
            // ================================================
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(

                // Disabled when loading
                onPressed: isLoading ? null : _handleLogin,

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),

                // Show spinner when loading
                // Show text when not loading
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ================================================
            // OR DIVIDER
            // ================================================
            const Center(
              child: Text(
                'OR',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ================================================
            // SIGN UP LINK
            // ================================================
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
                child: RichText(
                  text: const TextSpan(
                    text: "Don't have an account? ",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    children: [
                      TextSpan(
                        text: 'Sign Up',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}