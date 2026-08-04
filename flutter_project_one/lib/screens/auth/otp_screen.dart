import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth/auth_provider.dart';
import '../customer/homescreen/home_screen.dart';
import '../../providers/customer/customer_cart_provider.dart';
import 'login_screen.dart';

enum _OtpStep { email, phone }

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final bool startAtPhoneStep;

  const OtpVerificationScreen({super.key, this.startAtPhoneStep = false});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  _OtpStep _step = _OtpStep.email;
  final _codeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  Timer? _timer;
  int _secondsLeft = 60;

 @override
  void initState() {
    super.initState();
    if (widget.startAtPhoneStep) {
      _step = _OtpStep.phone;
      _secondsLeft = 0; // let them tap "Resend code" immediately, no auto-send
    } else {
      _startTimer();
    }
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
    final pending = ref.read(pendingRegistrationProvider);
    if (pending == null) {
      setState(() => _errorMessage = 'Something went wrong. Please sign up again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final smsService = ref.read(iprogSmsServiceProvider);

    if (_step == _OtpStep.email) {
      final emailError = await authService.verifyEmailOtp(
        email: pending.email,
        token: _codeController.text.trim(),
      );

      if (emailError != null) {
        setState(() {
          _isLoading = false;
          _errorMessage = emailError;
        });
        return;
      }

      // Email verified — NOW send the phone OTP, not before
      // Email verified — NOW send the phone OTP, not before
      final bool smsSent = await smsService.sendOtp(pending.phone);

      if (!smsSent) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'We couldn\'t send a code to that phone number. '
              'Please check the number is correct, or try resending.';
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _step = _OtpStep.phone;
        _codeController.clear();
        _errorMessage = null;
      });
      _startTimer();
      return;
    }

    // Phone step
    final phoneOk = await smsService.verifyOtp(
      pending.phone,
      _codeController.text.trim(),
    );

    if (!phoneOk) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid or expired phone code.';
      });
      return;
    }

    final profileError = await authService.completeRegistration(
      firstName: pending.firstName,
      lastName: pending.lastName,
      email: pending.email,
      phone: pending.phone,
    );

    if (profileError != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = profileError;
      });
      return;
    }

    // Account is now fully real — safe to merge whatever they had in
    // their guest cart into it.
    await ref.read(customerCartProvider.notifier).mergeGuestCartIntoAccount();

    setState(() => _isLoading = false);

    ref.read(pendingRegistrationProvider.notifier).clear();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleEditPhoneNumber() async {
    final pending = ref.read(pendingRegistrationProvider);
    if (pending == null) return;

    final controller = TextEditingController(text: pending.phone);

    final String? newPhone = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EDIT PHONE NUMBER',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'We\'ll send a new code to the corrected number.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  style: const TextStyle(fontSize: 15, color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'e.g. 09171234567',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Colors.black, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text(
                          'SAVE & RESEND',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (newPhone == null || newPhone.isEmpty || !mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Update the pending registration with the corrected phone —
    // keeps their email verification progress intact, only the
    // phone number changes.
    ref.read(pendingRegistrationProvider.notifier).set(
      PendingRegistration(
        firstName: pending.firstName,
        lastName: pending.lastName,
        email: pending.email,
        phone: newPhone,
      ),
    );

    final bool smsSent = await ref.read(iprogSmsServiceProvider).sendOtp(newPhone);

    setState(() => _isLoading = false);

    if (!smsSent) {
      setState(() => _errorMessage = 'We couldn\'t send a code to that number. Please check it and try again.');
      return;
    }

    setState(() {
      _codeController.clear();
      _errorMessage = null;
    });
    _startTimer();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A new code was sent to $newPhone.')),
      );
    }
  }

  Future<void> _handleCancelSignup() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CANCEL SIGNUP?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This will stop your registration. You\'ll need to sign up again from the start if you change your mind.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: const Text('Keep going', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBA1A1A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: const Text(
                        'CANCEL SIGNUP',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    if (confirmed != true || !mounted) return;

    await ref.read(authServiceProvider).logout();
    ref.read(pendingRegistrationProvider.notifier).clear();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleResend() async {
    final pending = ref.read(pendingRegistrationProvider);
    if (pending == null || _secondsLeft > 0) return;

    setState(() => _errorMessage = null);

    if (_step == _OtpStep.email) {
      final authService = ref.read(authServiceProvider);
      final error = await authService.resendEmailOtp(email: pending.email);
      if (error != null) {
        setState(() => _errorMessage = error);
        return;
      }
    } else {
      final bool smsSent = await ref.read(iprogSmsServiceProvider).sendOtp(pending.phone);
      if (!smsSent) {
        setState(() => _errorMessage = 'We couldn\'t resend the code. Please check your phone number.');
        return;
      }
    }

    _startTimer();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A new code was sent to your ${_step == _OtpStep.email ? "email" : "phone"}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingRegistrationProvider);
    final isEmailStep = _step == _OtpStep.email;
    final destination = isEmailStep ? pending?.email : pending?.phone;

    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop) {
          ref.read(pendingRegistrationProvider.notifier).clear();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator
              Row(
                children: [
                  _StepDot(active: isEmailStep, done: !isEmailStep, label: 'Email'),
                  const SizedBox(width: 8),
                  Container(width: 24, height: 2, color: Colors.grey.shade300),
                  const SizedBox(width: 8),
                  _StepDot(active: !isEmailStep, done: false, label: 'Phone'),
                ],
              ),
              const SizedBox(height: 24),

            Text(
                isEmailStep ? 'Verify your email' : 'Verify your phone',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                destination == null
                    ? 'Enter the code we sent you.'
                    : 'Enter the 6-digit code sent to $destination',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),

              // ── Wrong number? Edit — only on the phone step ──
              if (!isEmailStep) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _isLoading ? null : _handleEditPhoneNumber,
                  child: const Text(
                    'Wrong number? Edit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(
                  hintText: '8-digit code',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: _secondsLeft > 0
                    ? Text('Resend code in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13))
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

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEmailStep ? 'Verify Email' : 'Verify Phone',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              // ── Cancel signup — small, low-emphasis, always available ──
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _handleCancelSignup,
                  child: Text(
                    'Cancel signup',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  final bool done;
  final String label;

  const _StepDot({required this.active, required this.done, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.black : (done ? Colors.green : Colors.grey.shade400);
    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: color,
          child: done
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : Text('${active ? 1 : 2}', style: const TextStyle(fontSize: 11, color: Colors.white)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}