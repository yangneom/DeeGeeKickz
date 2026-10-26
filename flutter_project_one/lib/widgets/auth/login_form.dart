// Basic Flutter import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
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

import '../../screens/super/super_layout.dart';

import '../../screens/customer/homescreen/home_screen.dart';

import '../../screens/auth/mfa_enroll_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../screens/auth/mfa_challenge_screen.dart';
import '../../main.dart';
import '../../core/guards/staff_device_rules.dart';

// Shared auth look + shared validation rules
import '../../core/utils/form_validators.dart';
import '../../widgets/common/forms/auth_form_fields.dart';

// ================================================
// LOGIN FORM WIDGET
//
// Standardised on the shared auth components (AuthTextField,
// AuthPasswordField, AuthFormError, AuthPrimaryButton), so the field look,
// the error style and the button are the same as every other auth form.
//
// Behaviour notes:
//   - Field problems appear UNDER the field. They first appear when the
//     user presses Login, and from then on update as the user corrects
//     the value (not while typing the very first time).
//   - A whole-form problem (wrong credentials, no internet, unsupported
//     account type) appears in the red box above the button.
//   - Enter submits from the password field; Enter in the email field
//     moves to the password field.
//   - The password is NEVER trimmed or altered. There is no length rule
//     here: strength rules belong to sign-up and password change, and
//     checking them at login only locks out people whose password
//     predates a rule.
// ================================================
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Becomes true after the first failed submit; from then on the fields
  // re-check themselves as the user edits them.
  bool _showErrors = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ================================================
  // HANDLE LOGIN FUNCTION
  // ================================================
  Future<void> _handleLogin() async {

    // A second request (Enter key or a fast double tap) while one is
    // already running is ignored.
    if (ref.read(isLoadingProvider)) return;

    final bool formIsValid = _formKey.currentState!.validate();
    if (!formIsValid) {
      setState(() => _showErrors = true);
      return;
    }

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

    // True once the credentials were accepted and the account is allowed on
    // this device. Only used to tell the browser's autofill / password manager
    // whether to offer to save the password (see the finally block).
    bool loginSucceeded = false;

    try {
      // Check BEFORE attempting the request at all — faster,
      // clearer feedback than waiting for the request to time out,
      // and avoids sending a login attempt the device can't
      // possibly deliver anyway.
      final List<ConnectivityResult> connectivity =
          await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none) || connectivity.isEmpty) {
        errorNotifier.setError(
          'No internet connection. Please check your connection and try again.',
        );
        return;
      }

      final authService = ref.read(authServiceProvider);

      final String? errorMessage = await authService.login(
        // The email is trimmed (a stray space from copy/paste must not
        // make a correct login fail). The password is sent exactly as typed.
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (errorMessage == AuthService.unconfirmedEmailMarker) {
        errorNotifier.setError(
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
          // Nothing to resume from: do not leave this account signed in.
          await authService.logout();
          errorNotifier.setError(
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
        errorNotifier.setError(errorMessage);
        return;
      }

      final String? role = await authService.getUserRole();

      // Staff roles (Admin/Cashier/Super Admin) are not allowed on a phone or
      // in the mobile app. This is the SAME rule the global auth listener, app
      // start-up and every staff layout use (StaffDeviceGuard). It also no
      // longer depends on `mounted`: the old phone-browser check was silently
      // skipped whenever this form had already been replaced by another screen.
      final StaffDeviceBlock? deviceBlock = StaffDeviceGuard.isStaff(role)
          ? StaffDeviceGuard.blockForThisDevice(
              width: mounted ? MediaQuery.of(context).size.width : null,
            )
          : null;
      if (deviceBlock != null) {
        await authService.logout();
        errorNotifier.setError(deviceBlock.messageFor(role));
        return;
      }

      loginSucceeded = true;
      isOwnLoginInProgress = true;

      if (role == 'Admin' || role == 'Super Admin' || role == 'Cashier') {
        // Cashier now mandatory too — permissions-based reasoning:
        // Cashier accounts can process sales and perform
        // inventory-affecting operations, so they're treated as
        // privileged staff accounts, same tier as Admin/Super Admin.
        // Fail CLOSED: if the server's authenticator list cannot be read, the staff
        // session is ended and nothing staff-related opens. (Before, the error was
        // swallowed by the outer catch while the password-only session stayed signed
        // in, and the "login in progress" flag stayed on.)
        final List<Factor> verifiedTotp;
        try {
          final factors = await Supabase.instance.client.auth.mfa.listFactors();
          verifiedTotp = factors.totp; // VERIFIED authenticators only
        } catch (_) {
          await authService.logout();
          isOwnLoginInProgress = false;
          errorNotifier.setError(
            'We couldn\'t confirm your two-factor authentication status. '
            'Please check your connection and try again.',
          );
          return;
        }
        final bool hasMfaEnrolled = verifiedTotp.isNotEmpty;

        if (!hasMfaEnrolled) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MfaEnrollScreen()),
            );
          }
          return;
        }

        isOwnLoginInProgress = false;
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (mfaScreenContext) => MfaChallengeScreen(
                role: role,
                onVerified: () {
                  // FIX: was checking LoginForm's OWN `mounted` — but
                  // LoginForm is disposed the instant this MfaChallengeScreen
                  // route replaces it, which happens on EVERY login, not
                  // just during a race. This uses mfaScreenContext (THIS
                  // screen's own context) instead, which is what's
                  // actually still alive when this callback runs.
                  Navigator.of(mfaScreenContext).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => role == 'Admin'
                          ? const AdminLayout()
                          : role == 'Cashier'
                              ? const CashierLayout()
                              : const SuperLayout(),
                    ),
                  );
                },
              ),
            ),
          );
        }

      } else if (role == 'Customer') {
        await ref.read(customerCartProvider.notifier).mergeGuestCartIntoAccount();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const HomeScreen(),
            ),
          );
        }

      } else {
        // An account with no usable role must not stay signed in, and the
        // "login in progress" flag set above must not be left on.
        await authService.logout();
        isOwnLoginInProgress = false;
        errorNotifier.setError(
          'Unknown role: $role. Please contact support.',
        );
      }
    } catch (error) {
      // Network-specific failures are now caught inside
      // authService.login() itself and returned as a real error
      // message above — this remains a genuine last-resort catch
      // for anything else unexpected.
      errorNotifier.setError(
        'Something went wrong. Please try again.',
      );

    } finally {

      loadingNotifier.setLoading(false);

      // Ends the autofill session that the login form's AutofillGroup opened.
      // Flutter's documentation says to do this after EVERY attempt: with
      // shouldSave=true after a successful login (so the browser can offer to
      // save the password) and false after a failed one. This form never did,
      // so a failed attempt left that session open.
      TextInput.finishAutofillContext(shouldSave: loginSucceeded);

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
      // Quiet until the first submit; after that, fields update as they
      // are corrected.
      autovalidateMode: _showErrors
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: SizedBox(
        width: formWidth,
        // Lets browsers and password managers fill the email + password.
        child: AutofillGroup(
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
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
              ),

              const SizedBox(height: 30),

              // ── EMAIL ──
              AuthTextField(
                label: 'Email Address',
                hint: 'Enter your email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                validator: FormValidators.email,
              ),

              const SizedBox(height: 16),

              // ── PASSWORD ──
              AuthPasswordField(
                label: 'Password',
                hint: 'Enter your password',
                controller: _passwordController,
                focusNode: _passwordFocus,
                textInputAction: TextInputAction.done,
                // Enter submits the form.
                onFieldSubmitted: (_) => _handleLogin(),
                // Not trimmed: a password may legitimately contain spaces.
                validator: (String? value) =>
                    FormValidators.requiredField(value, 'Password', trim: false),
              ),

              const SizedBox(height: 8),

              // ── FORGOT PASSWORD ──
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── WHOLE-FORM ERROR (wrong credentials, no internet, ...) ──
              if (errorMessage != null) ...[
                AuthFormError(message: errorMessage),
                const SizedBox(height: 16),
              ],

              // ── LOGIN BUTTON ──
              AuthPrimaryButton(
                label: 'Login',
                isLoading: isLoading,
                onPressed: _handleLogin,
              ),

              const SizedBox(height: 20),

              // ── OR DIVIDER ──
              const Center(
                child: Text(
                  'OR',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ),

              const SizedBox(height: 12),

              // ── SIGN UP LINK ──
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text.rich(
                    TextSpan(
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
      ),
    );
  }
}