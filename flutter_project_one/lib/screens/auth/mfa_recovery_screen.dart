import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/guards/mfa_flow_guard.dart';
import 'mfa_enroll_screen.dart';

class MfaRecoveryScreen extends StatefulWidget {
  const MfaRecoveryScreen({super.key});

  @override
  State<MfaRecoveryScreen> createState() => _MfaRecoveryScreenState();
}

class _MfaRecoveryScreenState extends State<MfaRecoveryScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _verifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    MfaFlowGuard.opened(MfaScreenKind.recovery);
  }

  @override
  void dispose() {
    _codeController.dispose();
    MfaFlowGuard.closed(MfaScreenKind.recovery);
    super.dispose();
  }

  Future<void> _verifyRecoveryCode() async {
    final String code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a recovery code.');
      return;
    }

    setState(() {
      _verifying = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'mfa-recovery-verify',
        body: {'code': code},
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        if (!mounted) return;
        setState(() {
          _verifying = false;
          _errorMessage = data?['error'] ?? 'Invalid recovery code.';
        });
        return;
      }

      if (!mounted) return;
      // Old factor is already removed server-side — straight into
      // enrollment for a brand-new one. Session stays aal1 the whole
      // time; only a real mfa.verify() on the NEW factor grants aal2.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MfaEnrollScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
      print('MfaRecoveryScreen error: $e');
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
                  IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 20),
                  ),
                  const SizedBox(height: 8),
                  const Text('Account Recovery', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter one of your saved recovery codes. This will let you '
                    'set up a new authenticator, since your old one is unavailable. '
                    'This code can only be used once.',
                    style: TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 24),
                                    TextField(
                    controller: _codeController,
                    autofocus: true,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    autofillHints: const [],
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    style: const TextStyle(fontSize: 16, fontFamily: 'monospace', letterSpacing: 1),
                    decoration: InputDecoration(
                      hintText: 'XXXXX-XXXXX',
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
                      onPressed: _verifying ? null : _verifyRecoveryCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _verifying
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}