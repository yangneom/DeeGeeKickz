import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/auth/mfa_challenge_screen.dart';
import '../../core/utils/form_validators.dart';
import '../../widgets/common/forms/auth_form_fields.dart';

/// Customer-facing "set a new password" form, used only at the end of
/// the Forgot Password flow — after the recovery OTP has been verified
/// and a temporary session is active.
///
/// Deliberately separate from SetPasswordForm (staff invite flow):
/// that one also flips `password_set = true` on the users table, which
/// is specific to staff accounts created via admin invite. Customers
/// don't go through that flow, so this form only updates the password
/// itself and skips that flag entirely. Styling also matches the
/// customer auth screens (rounded, white) rather than the staff theme
/// (sharp corners, filled grey).
///
/// Uses the same shared fields and the same password rule as Sign Up
/// (FormValidators.newPassword). It used to accept 6 characters while
/// Sign Up asked for 8.
class ResetPasswordForm extends StatefulWidget {
  final VoidCallback onSuccess;

  const ResetPasswordForm({super.key, required this.onSuccess});

  @override
  State<ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<ResetPasswordForm> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Re-checks ONLY the confirm field when the new password changes.
  final GlobalKey<FormFieldState<String>> _confirmKey =
      GlobalKey<FormFieldState<String>>();

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  // True after the first failed submit; from then on the fields re-check
  // themselves as the user edits them.
  bool _showErrors = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      setState(() => _showErrors = true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // AUDIT FIX: a recovery session only ever reaches aal1 — proving
      // email ownership isn't proof of the second factor. Supabase
      // itself blocks updateUser() on an MFA-enabled account unless
      // the CURRENT session has actually reached aal2, regardless of
      // how that session was established. This checks the real,
      // authoritative answer (not just "does a factor exist") before
      // deciding whether a challenge step is needed at all.
      final aal = await _supabase.auth.mfa.getAuthenticatorAssuranceLevel();
      final bool needsMfaStep =
          aal.currentLevel != AuthenticatorAssuranceLevels.aal2 &&
          aal.nextLevel == AuthenticatorAssuranceLevels.aal2;

      if (needsMfaStep) {
        final userId = _supabase.auth.currentUser!.id;
        final profileRow = await _supabase
            .from('users')
            .select('role')
            .eq('id', userId)
            .maybeSingle();
        final String? role = profileRow?['role'] as String?;

        if (!mounted) return;
        setState(() => _isSubmitting = false);

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MfaChallengeScreen(
              role: role,
              onVerified: () async {
                // Session is now genuinely aal2 — safe to proceed.
                Navigator.of(context).pop();
                await _completePasswordUpdate();
              },
            ),
          ),
        );
        return;
      }

      // No MFA required for this account/session — proceed directly.
      await _completePasswordUpdate();
    } on AuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
      if (mounted) setState(() => _isSubmitting = false);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = 'Something went wrong. Please try again.');
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _completePasswordUpdate() async {
    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Trimmed on purpose: sign-up and login (AuthService) trim the
      // password too, so all three flows stay consistent.
      await _supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );

      if (mounted) widget.onSuccess();
    } on AuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double formWidth = screenWidth > 600 ? 400 : screenWidth * 0.85;

    return Form(
      key: _formKey,
      autovalidateMode: _showErrors
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: SizedBox(
        width: formWidth,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reset Your Password',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter a new password for your account.',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 30),

              // ── NEW PASSWORD ──
              AuthPasswordField(
                label: 'New Password',
                hint: 'Enter a new password',
                controller: _passwordController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: FormValidators.newPassword,
                onChanged: (_) {
                  // "Passwords do not match" may have just become true or
                  // false — re-check only the confirm field.
                  if (_showErrors && _confirmController.text.isNotEmpty) {
                    _confirmKey.currentState?.validate();
                  }
                },
              ),

              const SizedBox(height: 16),

              // ── CONFIRM ──
              AuthPasswordField(
                label: 'Confirm Password',
                hint: 'Re-enter your new password',
                controller: _confirmController,
                fieldKey: _confirmKey,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                // Enter submits.
                onFieldSubmitted: (_) => _handleSubmit(),
                validator: (String? value) =>
                    FormValidators.confirmPassword(value, _passwordController.text),
              ),

              const SizedBox(height: 20),

              // ── WHOLE-FORM ERROR ──
              if (_errorMessage != null) ...[
                AuthFormError(message: _errorMessage!),
                const SizedBox(height: 16),
              ],

              // ── SUBMIT ──
              AuthPrimaryButton(
                label: 'Reset Password',
                isLoading: _isSubmitting,
                onPressed: _handleSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}