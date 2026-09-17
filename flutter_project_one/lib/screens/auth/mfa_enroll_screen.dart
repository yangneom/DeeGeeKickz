import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/auth/login_screen.dart';
import 'package:flutter/services.dart';

class MfaEnrollScreen extends StatefulWidget {
  const MfaEnrollScreen({super.key});

  @override
  State<MfaEnrollScreen> createState() => _MfaEnrollScreenState();
}

class _MfaEnrollScreenState extends State<MfaEnrollScreen> {
  final TextEditingController _codeController = TextEditingController();
  String? _secret;
  String? _factorId;
  bool _loading = true;
  bool _verifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startEnrollment();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _startEnrollment() async {
    try {
      final supabase = Supabase.instance.client;
            final response = await supabase.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'DeeGeeKickz',
        // Prevents "friendly name already exists" collisions from
        // abandoned/unverified enrollment attempts (browser refresh,
        // hot restart, cancelled test) — each attempt now gets a
        // genuinely unique name instead of colliding on the default "".
        friendlyName: 'totp_${DateTime.now().millisecondsSinceEpoch}',
      );
           if (response.totp == null) {
        throw Exception('Enrollment response did not include TOTP setup data.');
      }

      if (!mounted) return;
      setState(() {
        _factorId = response.id;
        _secret = response.totp!.secret;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Could not start MFA setup. Please try again.';
      });
      print('MfaEnrollScreen enroll error: $e');
    }
  }

  Future<void> _verifyAndFinish() async {
    if (_factorId == null || _codeController.text.trim().length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code from your authenticator app.');
      return;
    }

    setState(() {
      _verifying = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final challenge = await supabase.auth.mfa.challenge(factorId: _factorId!);
      await supabase.auth.mfa.verify(
        factorId: _factorId!,
        challengeId: challenge.id,
        code: _codeController.text.trim(),
      );

      if (!mounted) return;

            // Was reading userMetadata['role'] — only ever populated by
      // create-admin-user's invite flow. This account (and any
      // other set up via direct SQL/manual means) has no role in
      // its JWT metadata at all, so that check silently always
      // failed. The users TABLE is the one reliable source of
      // truth for role, regardless of how the account was created.
      final String userId = supabase.auth.currentUser!.id;
      final profileRow = await supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final String? role = profileRow?['role'] as String?;

            if (role == 'Super Admin') {
        // Every successful enrollment for a Super Admin — first-time
        // AND post-recovery — generates a fresh recovery-code batch.
        // The RPC itself deletes any prior batch first, so this
        // naturally satisfies "a new set invalidates the old one."
        try {
          // Force a genuinely fresh session/token BEFORE calling the
          // aal2-gated RPC — mfa.verify() updates the session object,
          // but the client's cached auth header for the VERY NEXT
          // request isn't guaranteed to reflect that yet. This closes
          // that timing gap explicitly rather than hoping it's synced.
          await supabase.auth.refreshSession();

          final userId = supabase.auth.currentUser!.id;
          final List<dynamic> codes = await supabase.rpc(
            'generate_mfa_recovery_codes',
            params: {'p_user_id': userId},
          );

          if (!mounted) return;
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _RecoveryCodesDialog(codes: codes.cast<String>()),
          );
        } catch (e) {
          print('generate_mfa_recovery_codes error: $e');
          // Don't block the whole enrollment over this — MFA itself
          // is already successfully enabled at this point.
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Two-factor authentication enabled successfully.'),
          backgroundColor: Colors.black,
        ),
      );

      await supabase.auth.signOut();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _errorMessage = 'That code didn\'t match. Please check your authenticator app and try again.';
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Set Up Two-Factor Authentication',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This is required for your role. Add this account to Ente Auth '
                          '(or another TOTP authenticator app) using the code below, then '
                          'enter the 6-digit code it generates.',
                          style: TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SETUP KEY',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280), letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                _secret ?? '',
                                style: const TextStyle(fontSize: 15, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Enter the 6-digit code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
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
                            onPressed: _verifying ? null : _verifyAndFinish,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _verifying
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Verify & Enable', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

class _RecoveryCodesDialog extends StatelessWidget {
  final List<String> codes;
  const _RecoveryCodesDialog({required this.codes});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Save Your Recovery Codes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'If you lose access to your authenticator, you can use one of these '
              'codes to regain access. Each code works only once. Store them '
              'somewhere safe — they will not be shown again.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
            ),
            const SizedBox(height: 16),
                       Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: SelectableText(
                codes.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: codes.join('\n')));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recovery codes copied to clipboard.')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy All Codes'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('I\'ve Saved These Codes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}