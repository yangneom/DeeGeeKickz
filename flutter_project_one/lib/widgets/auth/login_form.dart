// Basic Flutter import
import 'package:flutter/material.dart';
import '../../providers/customer/customer_cart_provider.dart';
// Riverpod import
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Our providers
import '../../providers/auth/auth_provider.dart';
import '../../services/auth/auth_service.dart';
import '../../screens/auth/otp_screen.dart';

// Import RegisterScreen so we can navigate to it when user taps Sign Up
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';


// Import AdminLayout for role-based navigation
import '../../screens/admin/admin_layout.dart';

// ✅ Import CashierLayout — now built!
import '../../screens/cashier/cashier_layout.dart';

// TODO: Import CustomerLayout when built
// import '../../screens/customer/customer_layout.dart';

import '../../screens/super/super_layout.dart'; // ← ADD THIS

import '../../screens/customer/homescreen/home_screen.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

// ================================================
// LOGIN FORM WIDGET
// ================================================
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ================================================
  // HANDLE LOGIN FUNCTION
  // ================================================
    Future<void> _handleLogin() async {

    bool formIsValid = _formKey.currentState!.validate();
    if (formIsValid == false) return;

    // Captured ONCE, up front — these notifier references stay valid
    // even after this widget is disposed by navigation, unlike calling
    // ref.read(...) again later, which throws if the widget's own
    // element has already been torn down mid-navigation. That throw
    // was silent and uncaught before, leaving isLoading stuck at
    // true forever (it's a global provider), which is why a fresh
    // login screen could show a permanently-spinning button.
    final loadingNotifier = ref.read(isLoadingProvider.notifier);
    final errorNotifier = ref.read(errorMessageProvider.notifier);

    loadingNotifier.setLoading(true);
    errorNotifier.setError(null);

    try {

      final authService = ref.read(authServiceProvider);

     final String? errorMessage = await authService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (errorMessage == AuthService.unconfirmedEmailMarker) {
        ref.read(errorMessageProvider.notifier).setError(
          'This account was never fully verified. Please sign up again '
          'with the same email to resend your verification code.',
        );
        return;
      }

      if (errorMessage == AuthService.incompleteRegistrationMarker) {
        // Password was correct, session is alive, but the phone step
        // was never finished. Recover name/phone from auth metadata
        // and drop them straight into the phone-verification screen.
        final currentUser = authService.currentUser;
        final meta = currentUser?.userMetadata;
        final phone = meta?['phone'] as String? ?? '';

        if (currentUser == null || phone.isEmpty) {
          ref.read(errorMessageProvider.notifier).setError(
            'Your signup wasn\'t finished and we couldn\'t recover your '
            'details. Please sign up again.',
          );
          return;
        }

        ref.read(pendingRegistrationProvider.notifier).set(
          PendingRegistration(
            firstName: meta?['first_name'] as String? ?? '',
            lastName: meta?['last_name'] as String? ?? '',
            email: currentUser.email ?? '',
            phone: phone,
          ),
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const OtpVerificationScreen(startAtPhoneStep: true),
            ),
          );
        }
        return;
      }

      if (errorMessage != null) {
        ref.read(errorMessageProvider.notifier).setError(errorMessage);
        return;
      }
final String? role = await authService.getUserRole();

      // Staff roles (Admin/Cashier/Super Admin) are web-only — the
      // mobile app is Customer-only by design. Block here rather than
      // letting them reach a staff layout that assumes web-only
      // features (CSV/Excel export, etc.) are available.
      if (!kIsWeb && role != 'Customer' && role != null) {
        await authService.logout();
        ref.read(errorMessageProvider.notifier).setError(
          'This account type isn\'t supported on the mobile app. '
          'Please use the web version to log in as $role.',
        );
        return;
      }

      if (role == 'Admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminLayout()),
        );

      } else if (role == 'Super Admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SuperLayout()),
        );

      } else if (role == 'Cashier') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CashierLayout()),
        );

     } else if (role == 'Customer') {
       await ref.read(customerCartProvider.notifier).mergeGuestCartIntoAccount(); // ← add this line
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(),
          ),
        );

      } else { 
        ref.read(errorMessageProvider.notifier).setError(
          'Unknown role: $role. Please contact support.',
        );
}
    } catch (error) {
      ref.read(errorMessageProvider.notifier).setError(
        'Something went wrong. Please try again.',
      );

       } finally {

      loadingNotifier.setLoading(false);

    }
  }

  // ================================================
  // BUILD
  // ================================================
  // ================================================
  // FORGOT PASSWORD
  // ================================================
  Future<void> _handleForgotPassword() async {
    final TextEditingController resetEmailController =
        TextEditingController(text: _emailController.text);

    final String? email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: resetEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Enter your account email',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(resetEmailController.text.trim()),
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );

    if (email == null || email.isEmpty || !mounted) return;

    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('If an account exists for $email, a reset link has been sent.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    }
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {

    final bool isLoading = ref.watch(isLoadingProvider);
    final String? errorMessage = ref.watch(errorMessageProvider);

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

            // ── LOGO ──
            Center(
              child: Image.asset(
                'assets/images/logo.jpg',
                height: 100,
                width: 100,
              ),
            ),

            const SizedBox(height: 20),

            // ── TITLE ──
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

            // ── SUBTITLE ──
            const Center(
              child: Text(
                'Enter your credentials to continue',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),

            const SizedBox(height: 30),

            // ── EMAIL LABEL ──
            const Text(
              'Email Address',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 8),

            // ── EMAIL FIELD ──
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

            // ── PASSWORD LABEL ──
            const Text(
              'Password',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 8),

            // ── PASSWORD FIELD ──
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

            // ── REMEMBER ME + FORGOT PASSWORD ──
            // ── FORGOT PASSWORD ──
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                  );
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
            ),

            const SizedBox(height: 16),

            // ── ERROR MESSAGE ──
            if (errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),

            if (errorMessage != null) const SizedBox(height: 16),

            // ── LOGIN BUTTON ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
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

            // ── OR DIVIDER ──
            const Center(
              child: Text(
                'OR',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),

            const SizedBox(height: 20),

            // ── SIGN UP LINK ──
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
                    style: TextStyle(fontSize: 14, color: Colors.black),
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