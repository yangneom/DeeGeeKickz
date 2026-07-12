import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    super.dispose();
  }

  // ── Submit ────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // 1. Update password in Supabase Auth
      await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );

      // 2. Mark password_set = true in public.users
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase
            .from('users')
            .update({'password_set': true})
            .eq('id', userId);
      }

      if (!mounted) return;

      // 3. Show success then go to login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PASSWORD SET SUCCESSFULLY. PLEASE LOG IN.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          backgroundColor: Colors.black,
          duration: Duration(seconds: 2),
        ),
      );

      // Sign out so they log in fresh with new password
      await supabase.auth.signOut();

      if (!mounted) return;

      // Navigate to login — pop everything
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
          // ── Header ─────────────────────────────
          const Text(
            'DEEGEEKICKZ',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            'SET YOUR PASSWORD',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Create a secure password for your account. '
            'You will use this to log in from now on.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.6,
              color: Color(0xFF4C4546),
            ),
          ),

          const SizedBox(height: 32),

          // ── New password ────────────────────────
          _fieldLabel('NEW PASSWORD'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: Colors.black,
            ),
            decoration: _inputDecoration(
              hint: 'At least 8 characters',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF4C4546),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter a password';
              }
              if (v.trim().length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // ── Confirm password ────────────────────
          _fieldLabel('CONFIRM PASSWORD'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: Colors.black,
            ),
            decoration: _inputDecoration(
              hint: 'Re-enter your password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF4C4546),
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
              color: const Color(0xFFFFEDED),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFFBA1A1A),
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
                padding: const EdgeInsets.symmetric(vertical: 18),
                color: Colors.black,
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
                        'SET PASSWORD',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
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

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: Colors.black,
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
        fontFamily: 'Inter',
        fontSize: 15,
        color: Color(0xFFCFC4C5),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF3F3F4),
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(0),
        borderSide: const BorderSide(color: Color(0xFFCFC4C5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(0),
        borderSide: const BorderSide(color: Color(0xFFCFC4C5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(0),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(0),
        borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(0),
        borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 2),
      ),
      errorStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        color: Color(0xFFBA1A1A),
      ),
    );
  }
}