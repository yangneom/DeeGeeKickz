import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth/auth_provider.dart';
import '../customer/homescreen/home_screen.dart';

enum _OtpStep { email, phone }

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

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
      await smsService.sendOtp(pending.phone);

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

    setState(() => _isLoading = false);

    if (profileError != null) {
      setState(() => _errorMessage = profileError);
      return;
    }

    ref.read(pendingRegistrationProvider.notifier).clear();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
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
      await ref.read(iprogSmsServiceProvider).sendOtp(pending.phone);
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
              const SizedBox(height: 24),

              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                decoration: InputDecoration(
                  hintText: '6-digit code',
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

              const SizedBox(height: 24),
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