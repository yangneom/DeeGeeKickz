// Basic Flutter import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Needed for TapGestureRecognizer, which lets us make a single word
// inside a RichText/TextSpan tappable (a plain GestureDetector only
// works on whole widgets, not on a span of text inside a paragraph).
import 'package:flutter/gestures.dart';

// Riverpod import
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Our providers
import '../../providers/auth/auth_provider.dart';
import '../../screens/auth/otp_screen.dart';
import '../../screens/auth/privacy_policy_screen.dart';
import '../../screens/auth/terms_of_use_screen.dart';

// Shared validation rules + shared auth look
import '../../core/utils/form_validators.dart';
import '../../core/utils/phone_format.dart';
import '../../widgets/common/forms/auth_form_fields.dart';
import 'email_policy_service.dart';
import '../../providers/auth/pending_password_provider.dart';

// ================================================
// SIGN UP FORM
//
// Layout
//   Wide screens (wider than 600px): two equal columns that group related
//   fields —
//       left  = who you are:       First Name, Last Name, Phone Number
//       right = how you log in:    Email Address, Password, Confirm Password
//   Narrow screens: ONE column in this order —
//       First Name, Last Name, Email Address, Phone Number,
//       Password, Confirm Password
//
// Each field is defined ONCE (see the _xxxField() methods below) and just
// placed differently, instead of being written out twice as before.
//
// Behaviour
//   - Field problems appear UNDER the field. They first appear when the
//     user presses Sign up, and from then on update as the user corrects
//     the value.
//   - Server-side problems (email already registered, too many attempts)
//     appear in the red box above the button.
//   - Enter moves to the next field; Enter on the last field submits.
// ================================================
class RegisterForm extends ConsumerStatefulWidget {
  const RegisterForm({super.key});

  @override
  ConsumerState<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<RegisterForm> {

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Lets us re-check ONLY the Confirm Password field when the Password
  // field changes (otherwise a stale "Passwords do not match" would stay
  // on screen after the user fixed the password).
  final GlobalKey<FormFieldState<String>> _confirmKey =
      GlobalKey<FormFieldState<String>>();

  // True after the first failed submit; from then on the fields re-check
  // themselves as the user edits them.
  bool _showErrors = false;
  bool _isSubmitting = false;

  // A message about the email that only the server can know (a temporary
  // email provider, or an address that is already registered). It is shown
  // under the email box, and cleared as soon as the person edits the box.
  String? _emailPolicyError;

  // ── Tap recognizers for the two footer links ──
  // Created once here (not in build) and disposed below, so we don't
  // create a new one on every rebuild or leak them.
  late final TapGestureRecognizer _privacyPolicyTapRecognizer;
  late final TapGestureRecognizer _termsOfUseTapRecognizer;

  @override
  void initState() {
    super.initState();

    _privacyPolicyTapRecognizer = TapGestureRecognizer()
      ..onTap = () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
        );
      };

    _termsOfUseTapRecognizer = TapGestureRecognizer()
      ..onTap = () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const TermsOfUseScreen()),
        );
      };

    // The error message lives in a global provider, so an error from an
    // earlier visit to this screen would still be showing when it opens
    // again. Start clean. (Done after the first frame because providers
    // can't be changed while the widget tree is still being built.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(registerErrorProvider.notifier).setError(null);
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emailFocus.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _privacyPolicyTapRecognizer.dispose();
    _termsOfUseTapRecognizer.dispose();
    super.dispose();
  }

  // ================================================
  // HANDLE REGISTER
  // ================================================
  Future<void> _handleRegister() async {

    // Don't allow a second submit while one is already running
    // (double tap, or Enter pressed twice).
    if (_isSubmitting) return;

    final bool formIsValid = _formKey.currentState!.validate();
    if (!formIsValid) {
      setState(() => _showErrors = true);
      return;
    }

    _isSubmitting = true;

    // Captured ONCE, up front. Calling ref.read(...) again after the
    // await can throw if the user has already left this screen — and that
    // exception used to leave the (global) loading flag stuck on, so the
    // next visit to Sign Up showed a spinner forever.
    final loadingNotifier = ref.read(registerIsLoadingProvider.notifier);
    final errorNotifier = ref.read(registerErrorProvider.notifier);
    final pendingNotifier = ref.read(pendingRegistrationProvider.notifier);
    final authService = ref.read(authServiceProvider);

    loadingNotifier.setLoading(true);
    errorNotifier.setError(null);

    // Trimmed copies — a stray space from copy/paste must not be saved.
    // (The password is NOT trimmed here.)
    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String email = _emailController.text.trim().toLowerCase();
    // Saved as +639XXXXXXXXX. The box holds only the 10 digits after +63,
    // and the validator has already confirmed they are a real number.
    final String phone = PhoneFormat.toE164(_phoneController.text) ?? '';

    try {
      // Is this address allowed? Checked BEFORE anything is created or sent,
      // so a temporary or already-used address never reaches Supabase from
      // this form. (The database enforces the same rule on its own too.)
      final EmailPolicyResult policy = await EmailPolicyService().check(email);
      final String? policyMessage = EmailPolicyService.messageFor(policy);
      if (policyMessage != null) {
        if (mounted) {
          setState(() {
            _emailPolicyError = policyMessage;
            _showErrors = true;
          });
          // Re-run the form so the message appears under the email box.
          _formKey.currentState?.validate();
        }
        return;
      }

      final String? errorMessage = await authService.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        password: _passwordController.text,
      );

      // Registration failed: show the error and stop.
      if (errorMessage != null) {
        errorNotifier.setError(EmailPolicyService.friendlyRegisterError(errorMessage));
        return;
      }

      // Save form data so the OTP screen can use it later.
      pendingNotifier.set(
        PendingRegistration(
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: phone,
        ),
      );

      // Keep the password IN MEMORY for the verification screen only, so its
      // "Edit email" pop-up can restart the sign-up without asking again. It is
      // cleared on every way out of that screen.
      ref.read(pendingPasswordProvider.notifier).set(_passwordController.text);

      // Go to the OTP screen.
      if (mounted) {
        Navigator.of(context)
            .push(
              MaterialPageRoute(builder: (context) => const OtpVerificationScreen()),
            )
            .then((_) {
          // The verification screen's "Wrong email? Edit" brings the person
          // back here with everything still filled in. Put the cursor in the
          // email box, with the address selected, ready to be corrected.
          if (mounted) {
            _emailController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _emailController.text.length,
            );
            _emailFocus.requestFocus();
          }
        });
      }
    } catch (_) {
      errorNotifier.setError('Something went wrong. Please try again.');
    } finally {
      loadingNotifier.setLoading(false);
      _isSubmitting = false;
    }
  }

  // ================================================
  // THE SIX FIELDS — each defined once
  // ================================================
  Widget _firstNameField() {
    return AuthTextField(
      label: 'First Name',
      hint: 'Jane',
      controller: _firstNameController,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.givenName],
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
        LengthLimitingTextInputFormatter(FormValidators.maxNameLength),
      ],
      validator: (String? value) => FormValidators.personName(value, 'First name'),
    );
  }

  Widget _lastNameField() {
    return AuthTextField(
      label: 'Last Name',
      hint: 'Doe',
      controller: _lastNameController,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.familyName],
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
        LengthLimitingTextInputFormatter(FormValidators.maxNameLength),
      ],
      validator: (String? value) => FormValidators.personName(value, 'Last name'),
    );
  }

  Widget _emailField() {
    return AuthTextField(
      label: 'Email Address',
      hint: 'Enter your email address',
      controller: _emailController,
      focusNode: _emailFocus,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      // Format first; then any message the server gave about this address.
      // Customers register with a Gmail address only. The server checks the
      // same rule again, so skipping this form does not skip the rule.
      validator: (String? value) =>
          FormValidators.gmailEmail(value) ?? _emailPolicyError,
      onChanged: (_) {
        if (_emailPolicyError != null) {
          setState(() => _emailPolicyError = null);
        }
      },
    );
  }

  Widget _phoneField() {
    return AuthPhoneField(
      controller: _phoneController,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _passwordField() {
    return AuthPasswordField(
      label: 'Password',
      hint: 'Enter your password',
      controller: _passwordController,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.newPassword],
      validator: FormValidators.newPassword,
      onChanged: (_) {
        // The password changed, so "Passwords do not match" may no longer
        // be true (or may have just become true). Re-check only Confirm.
        if (_showErrors && _confirmPasswordController.text.isNotEmpty) {
          _confirmKey.currentState?.validate();
        }
      },
    );
  }

  Widget _confirmPasswordField() {
    return AuthPasswordField(
      label: 'Confirm Password',
      hint: 'Re-enter your password',
      controller: _confirmPasswordController,
      fieldKey: _confirmKey,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      // Enter on the last field submits the form.
      onFieldSubmitted: (_) => _handleRegister(),
      validator: (String? value) =>
          FormValidators.confirmPassword(value, _passwordController.text),
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {

    // Read loading and error state from providers
    final bool isLoading = ref.watch(registerIsLoadingProvider);
    final String? errorMessage = ref.watch(registerErrorProvider);

    // Responsiveness
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 600;
    final double formWidth = isWideScreen ? 600 : screenWidth * 0.90;

    const SizedBox gap = SizedBox(height: 16);

    // The fields, arranged for the current width.
    final Widget fields = isWideScreen
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT — who you are
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _firstNameField(),
                    gap,
                    _lastNameField(),
                    gap,
                    _phoneField(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // RIGHT — how you log in
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _emailField(),
                    gap,
                    _passwordField(),
                    gap,
                    _confirmPasswordField(),
                  ],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _firstNameField(),
              gap,
              _lastNameField(),
              gap,
              _emailField(),
              gap,
              _phoneField(),
              gap,
              _passwordField(),
              gap,
              _confirmPasswordField(),
            ],
          );

    return Form(
      key: _formKey,
      // Quiet until the first submit; after that, fields update as they
      // are corrected.
      autovalidateMode: _showErrors
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: SizedBox(
        width: formWidth,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── TITLE ──
              const Text(
                'Create Your Account',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 8),

              // ── SUBTITLE ──
              const Text(
                'Fill in your details to get started',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),

              const SizedBox(height: 30),

              // ── THE FIELDS ──
              fields,

              const SizedBox(height: 30),

              // ── WHOLE-FORM ERROR (email already used, too many attempts...) ──
              if (errorMessage != null) ...[
                AuthFormError(message: errorMessage),
                const SizedBox(height: 16),
              ],

              // ── SIGN UP BUTTON ──
              AuthPrimaryButton(
                label: 'Sign up',
                isLoading: isLoading,
                onPressed: _handleRegister,
              ),

              const SizedBox(height: 20),

              // ── PRIVACY POLICY / TERMS OF USE FOOTER TEXT ──
              // One RichText; only the two linked words carry a
              // recognizer, so only they respond to taps.
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                    children: [
                      const TextSpan(text: "By continuing, I agree to DeeGeeKickz's "),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: _privacyPolicyTapRecognizer,
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Terms of Use',
                        style: const TextStyle(
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: _termsOfUseTapRecognizer,
                      ),
                      const TextSpan(text: '.'),
                    ],
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