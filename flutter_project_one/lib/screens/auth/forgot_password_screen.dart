import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import '../../providers/auth/auth_provider.dart';
import '../../core/utils/form_validators.dart';
import '../../widgets/common/forms/auth_form_fields.dart';
import '../../services/auth/password_reset_email_errors.dart';
import 'reset_password_otp_screen.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // True after the first failed submit; from then on the field re-checks
  // itself as the user edits it.
  bool _showErrors = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Turns whatever was thrown into something a customer can act on.
  // Before, the raw exception text (for example
  // "AuthApiException(message: ..., statusCode: 429 ...)") was shown.
  String _friendlyError(Object error) {
    if (error is AuthException) {
      // Supabase answers 429 for different reasons (a code was just sent, the whole
      // project's email allowance is used up, too many requests from this
      // connection). Each now gets the message that is actually true.
      return describeResetEmailFailure(
        statusCode: error.statusCode,
        message: error.message,
      ).message;
    }
    return 'We couldn\'t send the code. Please check your connection and try again.';
  }

  Future<void> _handleSendCode() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      setState(() => _showErrors = true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final String email = _emailController.text.trim();

    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(email);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResetPasswordOtpScreen(email: email),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double formWidth = screenWidth > 600 ? 400 : screenWidth * 0.85;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight),
            child: IntrinsicHeight(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Form(
                        key: _formKey,
                        autovalidateMode: _showErrors
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        child: SizedBox(
                          width: formWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // ── BACK ──
                              AuthBackButton(
                                label: 'Back to Login',
                                onPressed: () => Navigator.of(context).pop(),
                              ),

                              const SizedBox(height: 16),

                              const Text(
                                'Forgot your password?',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Enter your account email and we\'ll send you a '
                                'verification code to reset your password.',
                                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                              ),
                              const SizedBox(height: 30),

                              // ── EMAIL ──
                              AuthTextField(
                                label: 'Email Address',
                                hint: 'Enter your email address',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.email],
                                // Enter sends the code.
                                onFieldSubmitted: (_) => _handleSendCode(),
                                // The same email rule as login and sign-up
                                // (this screen used to only check for an "@").
                                validator: FormValidators.email,
                              ),

                              const SizedBox(height: 30),

                              // ── WHOLE-FORM ERROR ──
                              if (_errorMessage != null) ...[
                                AuthFormError(message: _errorMessage!),
                                const SizedBox(height: 16),
                              ],

                              // ── SEND CODE ──
                              AuthPrimaryButton(
                                label: 'Send Code',
                                isLoading: _isSubmitting,
                                onPressed: _handleSendCode,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}