import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/auth/mfa_challenge_screen.dart';
import '../../screens/auth/mfa_enroll_screen.dart';
import '../../core/utils/form_validators.dart';
import '../../widgets/common/forms/auth_form_fields.dart';
import '../../widgets/auth/recovery_steps.dart';


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

  // Becomes true once the person has passed the authenticator step. From then on
  // the step is never asked for again, so a refusal can never send them round in a
  // loop and they are never asked twice.
  bool _mfaStepDone = false;

  // True once this person has been (or is being) sent through the authenticator
  // step. It decides whether the step indicator shows three steps or two.
  bool _hasAuthenticatorStep = false;

  @override
  void initState() {
    super.initState();
    // The order people expect: the emailed code (already done), THEN the
    // authenticator code, THEN the new password. The screen is pushed over the form,
    // so the password can't be typed until it is passed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _secondFactorFirst();
    });
  }

  // An account with an authenticator is asked for its code now. A STAFF account
  // with none is sent to set one up now. A customer is asked nothing. The step is
  // NOT followed by a password change (nothing has been typed yet).
  //
  // This is an addition, not a replacement: pressing the Reset button still runs
  // the same check (it is skipped once passed), and the server enforces the rule
  // regardless. If anything here fails, nothing is skipped: the button's check
  // still asks.
  Future<void> _secondFactorFirst() async {
    if (!mounted || _mfaStepDone) return;
    try {
      final aal = _supabase.auth.mfa.getAuthenticatorAssuranceLevel();
      if (aal.currentLevel == AuthenticatorAssuranceLevels.aal2) return;

      final factors = await _supabase.auth.mfa.listFactors();
      if (!mounted) return;

      if (factors.totp.isNotEmpty) {
        await _askForAuthenticatorCode(thenUpdate: false);
      } else if (await _staffMustEnrolFirst()) {
        await _enrolFirst(thenUpdate: false);
      }
    } catch (e) {
      print('[AUTH-DEBUG] Early second-factor step skipped: ${e.runtimeType}');
    }
  }

  // Staff roles must have an authenticator, exactly as the login enforces.
  static bool _isStaffRole(String? role) =>
      role == 'Admin' || role == 'Cashier' || role == 'Super Admin';

  // True for a STAFF account with no authenticator yet (its setup was never finished,
  // or it was reset). Only asked once the form has already established that the
  // account has no verified authenticator and the session is not at that level.
  Future<bool> _staffMustEnrolFirst() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    final profileRow = await _supabase
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    return _isStaffRole(profileRow?['role'] as String?);
  }

  // Staff enrol an authenticator FIRST (the same screen the login uses), and only
  // then does the password change. The person is NOT signed out in between: the
  // enrolment screen hands control back here. The enrolment screen itself is
  // wrapped, not edited, so the login's use of it is unchanged.
  Future<void> _enrolFirst({bool thenUpdate = true}) async {
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _hasAuthenticatorStep = true;
    });

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecoveryStepFrame(
          labels: RecoveryStepper.withAuthenticator,
          active: 2,
          instruction: 'Step 2 of 3: Set up an authenticator app. Your account needs '
              'one before you can choose a new password.',
          child: MfaEnrollScreen(
            onEnrolled: () async {
              // The new authenticator is verified, so this session is now at the
              // authenticator level: carry on, and never ask again.
              _mfaStepDone = true;
              Navigator.of(context).pop();
              if (thenUpdate) await _completePasswordUpdate();
            },
          ),
        ),
      ),
    );
  }
  // The authenticator step. A recovery session only proves access to the email, so
  // an account that has an authenticator must pass it before the password can
  // change. (The server enforces this too.) Used both when the form can see the
  // account has an authenticator, and as a fallback if the server refuses the
  // update for exactly that reason. The code screen itself is wrapped, not edited,
  // so the login's use of it is unchanged.
  Future<void> _askForAuthenticatorCode({bool thenUpdate = true}) async {
    final userId = _supabase.auth.currentUser!.id;
    final profileRow = await _supabase
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    final String? role = profileRow?['role'] as String?;

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _hasAuthenticatorStep = true;
    });

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecoveryStepFrame(
          labels: RecoveryStepper.withAuthenticator,
          active: 2,
          instruction: 'Step 2 of 3: Enter the code from your authenticator app. It '
              'keeps your account safe even if someone else can read your email.',
          child: MfaChallengeScreen(
            role: role,
            onVerified: () async {
              // Session is now genuinely aal2 — safe to proceed, and never ask again.
              _mfaStepDone = true;
              Navigator.of(context).pop();
              if (thenUpdate) await _completePasswordUpdate();
            },
          ),
        ),
      ),
    );
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
      final bool isAal2 = aal.currentLevel == AuthenticatorAssuranceLevels.aal2;
      bool needsMfaStep = !_mfaStepDone &&
          !isAal2 &&
          aal.nextLevel == AuthenticatorAssuranceLevels.aal2;

      // nextLevel is read from the user data that arrived WITH this recovery
      // session. If that data did not list the person's authenticator, the check
      // above says "no step needed" even though the account has one. So ask the
      // server for the CURRENT list before concluding there is nothing to verify.
      if (!needsMfaStep && !_mfaStepDone && !isAal2) {
        final factors = await _supabase.auth.mfa.listFactors();
        needsMfaStep = factors.totp.isNotEmpty;
      }

      if (needsMfaStep) {
        await _askForAuthenticatorCode();
        return;
      }

      // A STAFF account with no authenticator has not finished two-factor setup.
      // It must enrol one first, as at login, instead of changing the password
      // with only the emailed code. (A customer, or any account that already has an
      // authenticator or is already verified, never reaches this.)
      if (!_mfaStepDone && !isAal2 && await _staffMustEnrolFirst()) {
        await _enrolFirst();
        return;
      }

      // No authenticator required for this account (or already verified): proceed directly.
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

      // Record the change date, as the Profile change and Set Password do. Best
      // effort: a failure here must never undo or hide a password change that has
      // already succeeded. (A database trigger would be the tamper-proof version.)
      try {
        final String? changedUserId = _supabase.auth.currentUser?.id;
        if (changedUserId != null) {
          await _supabase
              .from('users')
              .update({'password_changed_at': DateTime.now().toUtc().toIso8601String()})
              .eq('id', changedUserId);
        }
      } catch (_) {}

      if (mounted) widget.onSuccess();
    } on AuthException catch (error) {
      // The server refused because this session has not passed the authenticator
      // step. Ask for it (once), instead of showing the raw message.
      if (!_mfaStepDone && error.message.toLowerCase().contains('aal2')) {
        if (mounted) await _askForAuthenticatorCode();
        return;
      }
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
              RecoveryStepper(
                labels: _hasAuthenticatorStep
                    ? RecoveryStepper.withAuthenticator
                    : RecoveryStepper.emailOnly,
                active: _hasAuthenticatorStep ? 3 : 2,
              ),
              const SizedBox(height: 24),
              const Text(
                'Reset Your Password',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _hasAuthenticatorStep
                    ? 'Step 3 of 3: Choose a new password for your account.'
                    : 'Step 2 of 2: Choose a new password for your account.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
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