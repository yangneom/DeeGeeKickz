// Basic Flutter import
import 'package:flutter/material.dart';

// Riverpod import
// ConsumerStatefulWidget is just like StatefulWidget
// but it can also READ and WATCH Riverpod providers
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Our providers
import '../../providers/auth/auth_provider.dart';
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
  // _emailController.text    → gives us the email
  // _passwordController.text → gives us the password
  // ================================================
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // ================================================
  // LOCAL STATE VARIABLES
  // These are simple true/false values
  // that control what the form looks like
  // ================================================

  // Controls if password is visible or hidden
  bool _isPasswordVisible = false;

  // Controls the remember me checkbox
  bool _rememberMe = false;

  // ================================================
  // FORM KEY
  // This is used to validate the form
  // It checks if all fields are filled correctly
  // before we try to login
  // ================================================
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // ================================================
  // DISPOSE
  // This runs when the widget is removed from screen
  // We clean up controllers here to free memory
  // ================================================
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ================================================
  // HANDLE LOGIN FUNCTION
  // This runs when user taps the Login button
  // Step 1 - Validate the form
  // Step 2 - Set loading to true
  // Step 3 - Call AuthService to login
  // Step 4 - Handle success or failure
  // ================================================
  Future<void> _handleLogin() async {

    // Step 1 - Check if form is valid
    // If email or password is empty this returns false
    // and shows error messages under the text fields
    bool formIsValid = _formKey.currentState!.validate();

    // If form is not valid stop here
    if (formIsValid == false) {
      return;
    }

    // Step 2 - Set loading to true
    // This shows a loading spinner on the button
    ref.read(isLoadingProvider.notifier).setLoading(true);

    // Clear any old error message
    ref.read(errorMessageProvider.notifier).setError(null);

    // Step 3 - Get AuthService and try to login
    final authService = ref.read(authServiceProvider);

    // Call the login function from AuthService
    // It returns null if successful
    // It returns an error message if failed
    final String? errorMessage = await authService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    // Step 4 - Set loading back to false
    ref.read(isLoadingProvider.notifier).setLoading(false);

    // Check if login was successful or not
    if (errorMessage == null) {
      // Login was SUCCESSFUL
      // Firebase will automatically detect the login
      // and authStateProvider will update
      // The app will navigate to home screen automatically
      print('Login successful!');

    } else {
      // Login FAILED
      // Show the error message to the user
      ref.read(errorMessageProvider.notifier).setError(errorMessage);
    }
  }

  // ================================================
  // BUILD
  // This is where we build the actual UI
  // ================================================
  @override
  Widget build(BuildContext context) {

    // Read the current loading state
    // isLoading is true when login is in progress
    final bool isLoading = ref.watch(isLoadingProvider);

    // Read the current error message
    // errorMessage is null when there is no error
    final String? errorMessage = ref.watch(errorMessageProvider);

    // Get the screen width so we can make the form responsive
    final double screenWidth = MediaQuery.of(context).size.width;

    // If screen is wide like tablet or desktop
    // limit the form width to 400
    // If screen is small like phone
    // use 85% of the screen width
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
              // Connect this field to our email controller
              controller: _emailController,

              // This shows the email keyboard on mobile
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

              // Validator runs when we call _formKey.currentState!.validate()
              // Return null    → field is valid
              // Return String  → field is invalid (shows this error message)
              validator: (String? value) {

                // Check if email is empty
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }

                // Check if email has @ symbol
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }

                // Email is valid
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
              // Connect this field to our password controller
              controller: _passwordController,

              // obscureText hides the password text
              // When _isPasswordVisible is true  → show password
              // When _isPasswordVisible is false → hide password
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

                // Eye icon button on the right side of password field
                suffixIcon: IconButton(

                  // Change icon based on password visibility
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility       // eye open
                        : Icons.visibility_off,  // eye closed
                  ),

                  // When user taps the eye icon
                  // toggle password visibility
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),

              // Validate password field
              validator: (String? value) {

                // Check if password is empty
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }

                // Check if password is at least 6 characters
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }

                // Password is valid
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
            // This only shows when there is an error
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

            // Add spacing after error message if it exists
            if (errorMessage != null) const SizedBox(height: 16),

            // ================================================
            // LOGIN BUTTON
            // ================================================
            SizedBox(
              // Make button full width
              width: double.infinity,
              height: 50,
              child: ElevatedButton(

                // If loading is true  → disable button (null)
                // If loading is false → enable button (_handleLogin)
                onPressed: isLoading ? null : _handleLogin,

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),

                // If loading show spinner
                // If not loading show Login text
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
                  // TODO: Navigate to register screen later
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