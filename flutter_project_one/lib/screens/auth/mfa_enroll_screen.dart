import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/auth/login_screen.dart';
import '../../widgets/common/dialog/app_toast.dart';
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

      AppToast.success(
        context,
        'You have been signed out. Please log in again to continue.',
        title: 'Two-factor authentication enabled',
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

   // True while "Back to login" is running, so a double-tap can't run it twice.
  bool _leaving = false;

  // Back to login: at this screen the user is already signed in with their
  // password (they just haven't finished MFA), so going "back" has to sign
  // them out. Merely navigating away would leave a half-logged-in session
  // that the app's auth listener could send straight back here.
  Future<void> _backToLogin() async {
    if (_leaving) return;
    setState(() => _leaving = true);

    final supabase = Supabase.instance.client;

    // Best effort: remove the unfinished authenticator setup so abandoned
    // attempts don't pile up on the account. If this fails we still sign out.
    final String? factorId = _factorId;
    if (factorId != null) {
      try {
        await supabase.auth.mfa.unenroll(factorId);
      } catch (_) {
        // best effort
      }
    }

    try {
      await supabase.auth.signOut();
    } catch (_) {
      // best effort: we still leave the screen below
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 176,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: TextButton.icon(
              onPressed: (_verifying || _leaving) ? null : _backToLogin,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to login', style: TextStyle(fontSize: 14)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF374151)),
            ),
          ),
        ),
      ),
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

class RecoveryCodesDialog extends StatelessWidget {
  final List<String> codes;
  const RecoveryCodesDialog({super.key, required this.codes});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header — matches Add Account dialog exactly ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Save Your Recovery Codes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'If you lose access to your authenticator, you can use one of these codes to regain access.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Color(0xFF92400E)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Each code can only be used once. Store them somewhere safe — they will not be shown again.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
                          ),
                        ),
                      ],
                    ),
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
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: codes.join('\n')));
                            AppToast.success(context, 'Recovery codes copied to clipboard.');
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy All Codes', style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('I\'ve Saved These Codes', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}