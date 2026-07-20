// Basic Flutter import
import 'package:flutter/material.dart';
import '../../providers/customer/customer_cart_provider.dart';
// Riverpod import
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Our providers
import '../../providers/auth/auth_provider.dart';

// Import RegisterScreen so we can navigate to it when user taps Sign Up
import '../../screens/auth/register_screen.dart';

// Import AdminLayout for role-based navigation
import '../../screens/admin/admin_layout.dart';

// ✅ Import CashierLayout — now built!
import '../../screens/cashier/cashier_layout.dart';

// TODO: Import CustomerLayout when built
// import '../../screens/customer/customer_layout.dart';

import '../../screens/super/super_layout.dart'; // ← ADD THIS

import '../../screens/customer/homescreen/home_screen.dart';

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
  bool _rememberMe = false;

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

    ref.read(isLoadingProvider.notifier).setLoading(true);
    ref.read(errorMessageProvider.notifier).setError(null);

    try {

      final authService = ref.read(authServiceProvider);

      final String? errorMessage = await authService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (errorMessage != null) {
        ref.read(errorMessageProvider.notifier).setError(errorMessage);
        return;
      }

      final String? role = await authService.getUserRole();

      // ✅ REPLACE the role check section with this:

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

      ref.read(isLoadingProvider.notifier).setLoading(false);

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                GestureDetector(
                  onTap: () {
                    // TODO: Navigate to forgot password screen
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