import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/auth/mfa_recovery_screen.dart';
import 'login_screen.dart';

class MfaChallengeScreen extends StatefulWidget {
  final VoidCallback onVerified;
  final String? role; // recovery codes are Super Admin only

  const MfaChallengeScreen({super.key, required this.onVerified, this.role});

  @override
  State<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends State<MfaChallengeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _verifying = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeController.text.trim().length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code.');
      return;
    }

    setState(() {
      _verifying = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final factors = await supabase.auth.mfa.listFactors();

      if (factors.totp.isEmpty) {
        throw Exception('No MFA factors enrolled.');
      }

      // Tries the code against EVERY enrolled factor in turn — the
      // old code always checked factors.totp.first only, meaning a
      // genuinely correct code from any device OTHER than the first
      // one enrolled could never succeed, no matter what was typed.
      Object? lastError;
      for (final factor in factors.totp) {
        try {
          final challenge = await supabase.auth.mfa.challenge(factorId: factor.id);
          await supabase.auth.mfa.verify(
            factorId: factor.id,
            challengeId: challenge.id,
            code: _codeController.text.trim(),
          );

          if (!mounted) return;
          widget.onVerified();
          return;
        } catch (e) {
          lastError = e;
          continue;
        }
      }

      throw lastError ?? Exception('Verification failed');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _errorMessage = 'Incorrect code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // This screen is reached via pushReplacement, so
                  // there's nothing underneath it to pop back to —
                  // "back" here correctly means signing out and
                  // returning to login, not a real navigation pop.
                  IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: _verifying
                        ? null
                        : () async {
                            await Supabase.instance.client.auth.signOut();
                            if (!context.mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          },
                    icon: const Icon(Icons.arrow_back, size: 20),
                  ),
                  const SizedBox(height: 8),
                  const Text('Two-Factor Verification', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the 6-digit code from your authenticator app.',
                    style: TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    style: const TextStyle(fontSize: 18, letterSpacing: 4),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '000000',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMessage!, style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                  ],
                                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _verifying ? null : _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _verifying
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Verify', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  if (widget.role == 'Super Admin') ...[
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _verifying
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const MfaRecoveryScreen()),
                                );
                              },
                        child: const Text(
                          'Lost your device? Use a recovery code',
                          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}