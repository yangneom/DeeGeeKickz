import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth/auth_provider.dart';
import '../../widgets/auth/reset_password_form.dart';
import 'login_screen.dart';
import '../../main.dart';

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

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new code was sent to your email.')),
        );
      }
    } catch (_) {
      setState(() => _errorMessage = 'Could not resend the code. Please try again.');
    }
  }

  void _handlePasswordSaved() {
    isCustomerPasswordResetFlow = false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. Please log in with your new password.')),
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
                            'Enter the 6-digit code sent to ${widget.email}',
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
                                    'Resend code in 0:${_secondsLeft.toString().padLeft(2, '0')}',
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