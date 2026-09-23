import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/auth/mfa_enroll_screen.dart';

// ================================================
// SET PASSWORD FORM
//
// Shown after a staff member clicks the invite
// link from their email. Lets them set their own
// password to replace the admin-created one.
//
// Flow:
//   1. Admin invites via Edge Function
//   2. Staff clicks email link → lands here
//   3. Staff sets their own password
//   4. password_set = true saved to users table
//   5. Redirected to login screen
// ================================================

class SetPasswordForm extends StatefulWidget {
  const SetPasswordForm({super.key});

  @override
  State<SetPasswordForm> createState() => _SetPasswordFormState();
}

class _SetPasswordFormState extends State<SetPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();Pmain
  }

  // ── Submit ──────────────────────────────────── (unchanged)
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );

      final userId = supabase.auth.currentUser?.id;
      final String? role = supabase.auth.currentUser?.userMetadata?['role'] as String?;

      if (userId != null) {
        await supabase
            .from('users')
            .update({
              'password_set': true,
              'password_changed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);
      }

      if (!mounted) return;

      // Admin/Super Admin: mandatory MFA enrollment, right here,
      // before they ever reach a real screen — this is the one
      // moment they're guaranteed to have full attention on it.
      // Cashier stays on the original flow (MFA optional, enabled
      // later from Profile if they choose to).
      if (role == 'Admin' || role == 'Super Admin') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MfaEnrollScreen()),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password set successfully. Please log in.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.black,
          duration: Duration(seconds: 2),
        ),
      );

      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
      print('SetPasswordForm error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header — matches Sign Up's title/subtitle treatment ──
          const Text(
            'Set Your Password',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Create a secure password for your account. '
            'You will use this to log in from now on.',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Color(0xFF6B7280),
            ),
          ),

          const SizedBox(height: 32),

          // ── New password ────────────────────────
          _fieldLabel('New Password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF111827),
            ),
            decoration: _inputDecoration(
              hint: 'Enter your password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF6B7280),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
                        validator: _validatePasswordStrength,
          ),

          const SizedBox(height: 20),

          // ── Confirm password ────────────────────
          _fieldLabel('Confirm Password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF111827),
            ),
            decoration: _inputDecoration(
              hint: 'Re-enter your password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF6B7280),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please confirm your password';
              }
              if (v.trim() != _passwordController.text.trim()) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // ── Error message ───────────────────────
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Submit button ───────────────────────
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _loading ? null : _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Set Password',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A small blocklist of the most common/obvious weak passwords —
  // not exhaustive, just catches the laziest choices someone might
  // type for a staff account they didn't personally pick.
  static const List<String> _commonPasswords = [
    'password', 'password123', 'admin123', 'admin1234',
    '12345678', '123456789', 'qwerty123', 'letmein123',
    'welcome123', 'changeme', 'password1', 'admin@123',
  ];

  String? _validatePasswordStrength(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Please enter a password';
    }
    final String password = v.trim();

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (_commonPasswords.contains(password.toLowerCase())) {
      return 'This password is too common — please choose something more unique';
    }

    // Reject a password built around the person's own name/email —
    // invite_user's user_metadata carries first_name/last_name from
    // create-admin-user, and the email is on the authenticated
    // invite session itself, both available here pre-login.
    final user = Supabase.instance.client.auth.currentUser;
    final String lowerPassword = password.toLowerCase();

    final String? firstName =
        user?.userMetadata?['first_name'] as String?;
    final String? lastName =
        user?.userMetadata?['last_name'] as String?;
    final String? email = user?.email;

    if (firstName != null &&
        firstName.trim().length >= 3 &&
        lowerPassword.contains(firstName.trim().toLowerCase())) {
      return 'Password should not contain your first name';
    }
    if (lastName != null &&
        lastName.trim().length >= 3 &&
        lowerPassword.contains(lastName.trim().toLowerCase())) {
      return 'Password should not contain your last name';
    }
    if (email != null && email.contains('@')) {
      final String localPart = email.split('@').first.toLowerCase();
      if (localPart.length >= 3 && lowerPassword.contains(localPart)) {
        return 'Password should not be based on your email';
      }
    }

    return null;
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF374151),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFF9CA3AF),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
      errorStyle: const TextStyle(
        fontSize: 12,
        color: Color(0xFFDC2626),
      ),
    );
  }
}