import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth/auth_provider.dart';
import '../../widgets/auth/reset_password_form.dart';
import 'login_screen.dart';
import '../../main.dart';
import '../../widgets/common/dialog/app_toast.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, Supabase;
import '../../services/auth/password_reset_email_errors.dart';
import '../../widgets/auth/recovery_steps.dart';

class ResetPasswordOtpScreen extends ConsumerStatefulWidget {
  final String email;
  const ResetPasswordOtpScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordOtpScreen> createState() => _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends ConsumerState<ResetPasswordOtpScreen> {
  final TextEditingController _codeController = TextEditingController();

  bool _isVerifying = false;
  bool _codeVerified = false;
  String? _errorMessage;

  Timer? _timer;
  // Supabase allows ONE reset email per 60 seconds for an address. The button used to
  // unlock after 30, so a single click at 31 seconds was refused with a 429.
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }
  void _startTimer({int seconds = 60}) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _handleVerify() async {
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    isCustomerPasswordResetFlow = true;

    final String? error = await ref.read(authServiceProvider).verifyPasswordResetOtp(
          email: widget.email,
          token: _codeController.text.trim(),
        );

    setState(() => _isVerifying = false);

    if (error != null) {
      isCustomerPasswordResetFlow = false;
      setState(() => _errorMessage = error);
      return;
    }

    setState(() => _codeVerified = true);
  }

  Future<void> _handleResend() async {
    if (_secondsLeft > 0) return;
    setState(() => _errorMessage = null);

    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(widget.email);
      _startTimer();
      if (mounted) {
        AppToast.success(
          context,
          'A new code was sent to your email.',
          title: 'Code sent',
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (error is AuthException) {
        final ResetEmailFailure failure = describeResetEmailFailure(
          statusCode: error.statusCode,
          message: error.message,
        );
        setState(() => _errorMessage = failure.message);
        // A refusal for being too early, or for the email allowance: lock the
        // button for the time the server asked (or a minute), so it cannot be
        // clicked into the same refusal again.
        if (failure.limit != ResetEmailLimit.other) {
          _startTimer(seconds: failure.waitSeconds ?? 60);
        }
      } else {
        setState(() => _errorMessage = 'Could not resend the code. Please try again.');
      }
    }
  }

  Future<void> _handlePasswordSaved() async {
    isCustomerPasswordResetFlow = false;
    // The recovery session was only meant to get the password changed. End it, so
    // the person logs in with the NEW password (and their authenticator), exactly as
    // the message says. This device only: the password change already ended every
    // other session of the account.
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (mounted) {
      AppToast.success(
        context,
        'Please log in with your new password.',
        title: 'Password updated',
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    // Once the code is verified, Supabase has a temporary session
    // active — hand off to the shared SetPasswordForm to finish, using
    // the exact same centered container pattern as every other auth
    // screen (RegisterScreen, SetPasswordScreen).
    if (_codeVerified) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight),
            child: IntrinsicHeight(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ResetPasswordForm(
                        onSuccess: _handlePasswordSaved,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final double formWidth = screenWidth > 600 ? 400 : screenWidth * 0.85;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: screenHeight),
          child: IntrinsicHeight(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: formWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Row(
                              children: [
                                Icon(Icons.arrow_back, size: 16, color: Colors.grey),
                                SizedBox(width: 6),
                                Text('Back', style: TextStyle(fontSize: 13, color: Colors.grey)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const RecoveryStepper(
                            labels: RecoveryStepper.withAuthenticator,
                            active: 1,
                          ),
                          const SizedBox(height: 24),

                          const Text(
                            'Enter verification code',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
'Step 1: Enter the code we sent to ${widget.email}. If your account uses an authenticator app, you will be asked for its code next.',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 30),

                          const Text(
                            'Verification Code',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                              TextFormField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              maxLength: 8,
                              decoration: InputDecoration(
                                hintText: '8-digit code',                              counterText: '',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 4),

                          Align(
                            alignment: Alignment.centerRight,
                            child: _secondsLeft > 0
                                ? Text(
'Resend code in ${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  )
                                : TextButton(onPressed: _handleResend, child: const Text('Resend code')),
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                            ),
                          ],

                          const SizedBox(height: 26),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isVerifying ? null : _handleVerify,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _isVerifying
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Verify Code',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
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