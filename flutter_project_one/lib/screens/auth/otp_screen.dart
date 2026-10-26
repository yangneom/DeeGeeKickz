import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import '../../providers/auth/auth_provider.dart';
import '../../services/auth/iprog_sms_service.dart';
import '../../services/auth/email_policy_service.dart';
import '../../providers/auth/pending_password_provider.dart';
import '../customer/homescreen/home_screen.dart';
import '../../providers/customer/customer_cart_provider.dart';
import 'login_screen.dart';
import '../../widgets/common/dialog/confirm_dialog.dart';
import '../../widgets/common/dialog/app_toast.dart';
import '../../core/utils/form_validators.dart';
import '../../core/utils/phone_format.dart';
import '../../widgets/common/forms/auth_form_fields.dart';

enum _OtpStep { email, phone }

// Turns the technical text the email service returns into something a
// customer can act on. Messages that are already readable pass through.
String _friendlyCodeError(String raw) {
  final String lower = raw.toLowerCase();
  if (lower.contains('expired') || lower.contains('invalid')) {
    return 'That code is invalid or has expired. Request a new code and try again.';
  }
  return raw;
}

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final bool startAtPhoneStep;

  const OtpVerificationScreen({super.key, this.startAtPhoneStep = false});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  _OtpStep _step = _OtpStep.email;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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
    setState(() => _secondsLeft = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  // The message to show for each way a phone code request can fail.
  String _sendFailureMessage(OtpSendResult result) {
    if (result == OtpSendResult.rateLimited) {
      return 'Too many codes were requested. Please wait about 10 minutes and try again.';
    }
    if (result == OtpSendResult.sessionExpired) {
      return 'Your session has expired. Please log in again to finish signing up.';
    }
    return 'We couldn\'t send a code to that phone number. '
        'Please check the number is correct, or try resending.';
  }

  Future<void> _handleVerify() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

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
    final String code = _codeController.text.trim();

    if (_step == _OtpStep.email) {
      final emailError = await authService.verifyEmailOtp(
        email: pending.email,
        token: code,
      );
      if (!mounted) return;

      if (emailError != null) {
        setState(() {
          _isLoading = false;
          _errorMessage = _friendlyCodeError(emailError);
        });
        return;
      }

      // Email verified — NOW send the phone OTP, not before
      final OtpSendResult sent = await smsService.sendOtpDetailed(pending.phone);
      if (!mounted) return;

      // The email code is used up the moment it is verified, so the person
      // must move on to the phone step EVEN IF the text message could not be
      // sent. (Staying on the email step meant a retry re-used a spent code
      // and failed forever.) On the phone step, "Resend code" is available
      // straight away.
      setState(() {
        _isLoading = false;
        _step = _OtpStep.phone;
        _codeController.clear();
        _errorMessage = sent == OtpSendResult.sent ? null : _sendFailureMessage(sent);
      });
      if (sent == OtpSendResult.sent) {
        _startTimer();
      } else {
        _timer?.cancel();
        setState(() => _secondsLeft = 0);
      }
      return;
    }

    // Phone step
    final phoneOk = await smsService.verifyOtp(pending.phone, code);
    if (!mounted) return;

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
    if (!mounted) return;

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
    if (!mounted) return;

    setState(() => _isLoading = false);

    ref.read(pendingRegistrationProvider.notifier).clear();

    ref.read(pendingPasswordProvider.notifier).clear();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  // ── Wrong number? Edit ──────────────────────────────────────────
  // The dialog does the whole job (check the number, send the code) and only
  // closes with a value once the text message was really sent, so the screen
  // never shows success before it is true and the old number is kept until
  // then.
  Future<void> _handleEditPhoneNumber() async {
    final pending = ref.read(pendingRegistrationProvider);
    if (pending == null) return;

    final String? newPhone = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      barrierDismissible: false,
      builder: (_) => _EditPhoneDialog(currentPhone: pending.phone),
    );

    if (newPhone == null || !mounted) return;

    setState(() {
      _codeController.clear();
      _errorMessage = null;
    });
    _startTimer();

    AppToast.success(
      context,
      'A new code was sent to ${PhoneFormat.display(newPhone)}.',
      title: 'Code sent',
    );
  }

  // ── Wrong email? Edit ───────────────────────────────────────────
  // The Edit email pop-up: ONE field (the corrected Gmail address), Cancel and
  // Update Email, shown on this same screen.
  //
  // At this point the account is not confirmed and nobody is signed in, so
  // Supabase cannot change its email in place. The only way to get a code at a
  // different address is to sign up again with it, and a sign-up needs a
  // password. The pop-up uses the password the sign-up form handed over (see
  // pending_password_provider.dart), so it never has to ask for it a second
  // time. The corrected address goes through the same checks as any sign-up.
  Future<void> _handleEditEmail() async {
    if (_isLoading) return;

    final pending = ref.read(pendingRegistrationProvider);
    final String? heldPassword = ref.read(pendingPasswordProvider);

    // Not expected. If the sign-up details are no longer available, fall back
    // to returning to the sign-up form, where they are still filled in.
    if (pending == null || heldPassword == null) {
      await _backToSignUp();
      return;
    }

    final String? newEmail = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      barrierDismissible: false,
      builder: (_) => _EditEmailDialog(currentEmail: pending.email),
    );

    // Cancel (or nothing changed): the screen stays exactly as it was.
    if (newEmail == null || !mounted) return;

    setState(() {
      _codeController.clear();
      _errorMessage = null;
    });
    _startTimer();

    AppToast.success(
      context,
      'A new code was sent to $newEmail.',
      title: 'Code sent',
    );
  }

  // Fallback only: go back to the sign-up form.
  Future<void> _backToSignUp() async {
    final NavigatorState navigator = Navigator.of(context);
    // Still alive after this screen closes, so the message can be shown then.
    final BuildContext messageContext =
        Navigator.of(context, rootNavigator: true).context;

    if (navigator.canPop()) {
      // Closing this screen also clears the half-finished sign-up (see the
      // PopScope below).
      navigator.pop();
      AppToast.info(
        messageContext,
        'Fix your email address, then press Sign up again. '
        'We\'ll send a new code to it.',
        title: 'Change your email',
      );
      return;
    }

    // Nothing underneath to go back to (not expected): start over cleanly.
    ref.read(pendingRegistrationProvider.notifier).clear();
    ref.read(pendingPasswordProvider.notifier).clear();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    AppToast.info(
      messageContext,
      'Please sign up again with the correct email address.',
      title: 'Start again',
    );
  }

  Future<void> _handleCancelSignup() async {
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Cancel signup?',
      message: 'This will stop your registration. You\'ll need to sign up again '
          'from the start if you change your mind.',
      confirmLabel: 'Cancel Signup',
      confirmColor: const Color(0xFFDC2626),
    );

    if (confirmed != true || !mounted) return;

    await ref.read(authServiceProvider).logout();
    ref.read(pendingRegistrationProvider.notifier).clear();
    ref.read(pendingPasswordProvider.notifier).clear();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleResend() async {
    final pending = ref.read(pendingRegistrationProvider);
    if (pending == null || _secondsLeft > 0 || _isLoading) return;

    setState(() => _errorMessage = null);

    if (_step == _OtpStep.email) {
      final authService = ref.read(authServiceProvider);
      final error = await authService.resendEmailOtp(email: pending.email);
      if (!mounted) return;
      if (error != null) {
        setState(() => _errorMessage = error);
        return;
      }
    } else {
      final OtpSendResult result =
          await ref.read(iprogSmsServiceProvider).sendOtpDetailed(pending.phone);
      if (!mounted) return;
      if (result != OtpSendResult.sent) {
        setState(() => _errorMessage = result == OtpSendResult.failed
            ? 'We couldn\'t resend the code. Please check your phone number.'
            : _sendFailureMessage(result));
        return;
      }
    }

    _startTimer();
    AppToast.success(
      context,
      'A new code was sent to your ${_step == _OtpStep.email ? "email" : "phone"}.',
      title: 'Code sent',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingRegistrationProvider);
    final isEmailStep = _step == _OtpStep.email;
    final String? destination =
        isEmailStep ? pending?.email : PhoneFormat.display(pending?.phone);

    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop) {
          ref.read(pendingRegistrationProvider.notifier).clear();
          ref.read(pendingPasswordProvider.notifier).clear();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
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
                        (destination == null || destination.isEmpty)
                            ? 'Enter the code we sent you.'
                            : 'Enter the code sent to $destination',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                      ),

                      // ── Wrong email/number? Edit — available on both steps ──
                      // A real button, so a keyboard can reach it.
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : (isEmailStep ? _handleEditEmail : _handleEditPhoneNumber),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 36),
                            alignment: Alignment.centerLeft,
                          ),
                          child: Text(
                            isEmailStep ? 'Wrong email? Edit' : 'Wrong number? Edit',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── The code ──
                      AuthTextField(
                        label: 'Verification Code',
                        hint: 'Enter code',
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        maxLength: 8,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onFieldSubmitted: (_) => _handleVerify(),
                        validator: (String? value) {
                          final String v = (value ?? '').trim();
                          if (v.isEmpty) return 'Enter the code we sent you.';
                          if (v.length < 4) return 'That code is too short.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: _secondsLeft > 0
                            ? Text(
                                'Resend code in ${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13))
                            : TextButton(onPressed: _handleResend, child: const Text('Resend code')),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        AuthFormError(message: _errorMessage!),
                        const SizedBox(height: 16),
                      ],

                      AuthPrimaryButton(
                        label: isEmailStep ? 'Verify Email' : 'Verify Phone',
                        isLoading: _isLoading,
                        onPressed: _handleVerify,
                      ),

                      // ── Cancel signup — small, low-emphasis, always available ──
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading ? null : _handleCancelSignup,
                          child: Text(
                            'Cancel signup',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SHARED LOOK FOR THE TWO EDIT DIALOGS
//
// WHY THEY WERE HUGE: the old dialogs only set a 24px side margin and no
// maximum width, so on a desktop the box stretched to the screen width minus
// 48px. This frame gives both the same width rule: at most 520px, and on a
// phone the screen width minus a 16px margin on each side.
// ═══════════════════════════════════════════════════════════════════
class _EditDialogFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSaving;
  // False while the form is incomplete or invalid: Save is switched off, so
  // nothing can be submitted (and nothing sent) until it is valid.
  final bool canSave;
  final Widget body;
  final VoidCallback onSave;
  final String saveLabel;

  const _EditDialogFrame({
    required this.title,
    required this.subtitle,
    required this.isSaving,
    required this.canSave,
    required this.body,
    required this.onSave,
    this.saveLabel = 'Save & Resend',
  });

  @override
  Widget build(BuildContext context) {
    final double width = math.min(520.0, MediaQuery.of(context).size.width - 32);

    return PopScope(
      // No closing the window (back button) while a request is running.
      canPop: !isSaving,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 20),
                body,
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cancel = OutlinedButton(
                      onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                    );

                    final save = ElevatedButton(
                      // Off while a request is running AND while the form is
                      // invalid, so it cannot be double-clicked or submitted
                      // half-filled.
                      onPressed: (isSaving || !canSave) ? null : onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            isSaving ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              saveLabel,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                    );

                    // Narrow screens: stack the buttons, the main action first.
                    if (constraints.maxWidth < 360) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [save, const SizedBox(height: 10), cancel],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: cancel),
                        const SizedBox(width: 12),
                        Expanded(child: save),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// EDIT PHONE NUMBER DIALOG
//
//   - fixed "+63"; the user types only the 10 digits (letters cannot be typed)
//   - live checks, shown under the box: starts with 9, exactly 10 digits,
//     and not the same number as before
//   - Save & Resend stays off until the number is valid
//   - a number that already belongs to another account is refused
//   - the saved number is replaced ONLY after the text message was sent
//   - "too many codes" and other failures get their own message
//   - closes with the new +639XXXXXXXXX number, or with nothing on Cancel
// ═══════════════════════════════════════════════════════════════════
class _EditPhoneDialog extends ConsumerStatefulWidget {
  final String currentPhone;

  const _EditPhoneDialog({required this.currentPhone});

  @override
  ConsumerState<_EditPhoneDialog> createState() => _EditPhoneDialogState();
}

class _EditPhoneDialogState extends ConsumerState<_EditPhoneDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;

  bool _isSaving = false;
  String? _error;

  String? get _currentPhone => PhoneFormat.toE164(widget.currentPhone);

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: PhoneFormat.nationalDigits(widget.currentPhone) ?? '',
    );
    _phoneController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onChanged);
    _phoneController.dispose();
    super.dispose();
  }

  void _onChanged() {
    // Typing clears an old failure message and re-checks the Save button.
    setState(() => _error = null);
  }

  // The same rule feeds the message under the box AND the Save button.
  String? _validate(String? value) {
    final String? problem = FormValidators.nationalPhone(value);
    if (problem != null) return problem;

    if (PhoneFormat.toE164(value) == _currentPhone) {
      return 'That is already the number we sent the code to. Tap "Resend code" instead.';
    }
    return null;
  }

  bool get _canSave => _validate(_phoneController.text) == null;

  Future<void> _save() async {
    if (_isSaving || !_canSave) return;
    if (!_formKey.currentState!.validate()) return;

    final String? newPhone = PhoneFormat.toE164(_phoneController.text);
    if (newPhone == null) return; // the check above already guarantees a real number

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      // Is the number already on another account?
      final dynamic taken = await Supabase.instance.client
          .rpc('is_phone_taken', params: {'p_phone': newPhone});
      if (!mounted) return;
      if (taken == true) {
        setState(() {
          _isSaving = false;
          _error = 'An account already exists with this phone number.';
        });
        return;
      }

      final OtpSendResult result =
          await ref.read(iprogSmsServiceProvider).sendOtpDetailed(newPhone);
      if (!mounted) return;

      if (result != OtpSendResult.sent) {
        setState(() {
          _isSaving = false;
          _error = result == OtpSendResult.rateLimited
              ? 'Too many codes were requested. Please wait about 10 minutes and try again.'
              : result == OtpSendResult.sessionExpired
                  ? 'Your session has expired. Please log in again to finish signing up.'
                  : 'We couldn\'t send a code to that number. Please check it and try again.';
        });
        return;
      }

      // The text message really went out — only NOW replace the saved number.
      final pending = ref.read(pendingRegistrationProvider);
      if (pending != null) {
        ref.read(pendingRegistrationProvider.notifier).set(
          PendingRegistration(
            firstName: pending.firstName,
            lastName: pending.lastName,
            email: pending.email,
            phone: newPhone,
          ),
        );
      }

      Navigator.of(context).pop(newPhone);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditDialogFrame(
      title: 'Edit phone number',
      subtitle: 'We\'ll send a new code to the corrected number.',
      isSaving: _isSaving,
      canSave: _canSave,
      onSave: _save,
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthPhoneField(
              controller: _phoneController,
              validator: _validate,
              autofocus: true,
              enabled: !_isSaving,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter the 10 digits after +63, for example 9171234567.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AuthFormError(message: _error!),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// EDIT EMAIL DIALOG  (compact: one field, Cancel, Update Email)
//
//   - Gmail addresses only (same rule as sign-up), checked as you type
//   - a temporary-email domain or an already-registered address is refused
//     under the box BEFORE anything is created or sent
//   - the same address as before is refused
//   - Update Email stays off until the address is valid, and while it runs
//     (so it cannot be submitted twice)
//   - the saved address is replaced ONLY after the new sign-up was accepted
//     (and its code sent). Cancel changes nothing.
//   - the change is not complete until the new address is verified with the
//     code that was just sent
// ═══════════════════════════════════════════════════════════════════
class _EditEmailDialog extends ConsumerStatefulWidget {
  final String currentEmail;

  const _EditEmailDialog({required this.currentEmail});

  @override
  ConsumerState<_EditEmailDialog> createState() => _EditEmailDialogState();
}

class _EditEmailDialogState extends ConsumerState<_EditEmailDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  bool _isSaving = false;
  // The whole request failed (shown in the red box).
  String? _error;
  // A message about the ADDRESS that only the server can give (shown under
  // the box).
  String? _emailPolicyError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.currentEmail);
    _emailController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_onChanged);
    _emailController.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _emailPolicyError = null;
      _error = null;
    });
  }

  String? _validateEmail(String? value) {
    final String? problem = FormValidators.gmailEmail(value);
    if (problem != null) return problem;

    if ((value ?? '').trim().toLowerCase() ==
        widget.currentEmail.trim().toLowerCase()) {
      return 'That is already the address we sent the code to. Tap "Resend code" instead.';
    }
    return _emailPolicyError;
  }

  bool get _canSave => _validateEmail(_emailController.text) == null;

  Future<void> _save() async {
    if (_isSaving || !_canSave) return;
    if (!_formKey.currentState!.validate()) return;

    final String newEmail = _emailController.text.trim().toLowerCase();
    final pending = ref.read(pendingRegistrationProvider);
    final String? password = ref.read(pendingPasswordProvider);

    if (pending == null || password == null) {
      setState(() => _error =
          'Your sign-up session has ended. Please close this window and sign up again.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      // Temporary-email domain, not Gmail, or already registered? Asked
      // BEFORE anything is created or sent.
      final EmailPolicyResult policy = await EmailPolicyService().check(newEmail);
      if (!mounted) return;
      final String? policyMessage = EmailPolicyService.messageFor(policy);
      if (policyMessage != null) {
        setState(() {
          _isSaving = false;
          _emailPolicyError = policyMessage;
        });
        _formKey.currentState?.validate();
        return;
      }

      // Start the sign-up again with the corrected address (the existing
      // sign-up flow, unchanged).
      final String? error = await ref.read(authServiceProvider).register(
            firstName: pending.firstName,
            lastName: pending.lastName,
            email: newEmail,
            phone: pending.phone,
            password: password,
          );
      if (!mounted) return;

      if (error != null) {
        final bool taken = error == EmailPolicyService.takenMessage;
        setState(() {
          _isSaving = false;
          if (taken) {
            _emailPolicyError = error;
          } else {
            _error = EmailPolicyService.friendlyRegisterError(error);
          }
        });
        if (taken) _formKey.currentState?.validate();
        return;
      }

      // Accepted, and the code went to the NEW address — only now switch.
      ref.read(pendingRegistrationProvider.notifier).set(
        PendingRegistration(
          firstName: pending.firstName,
          lastName: pending.lastName,
          email: newEmail,
          phone: pending.phone,
        ),
      );

      Navigator.of(context).pop(newEmail);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditDialogFrame(
      title: 'Edit email address',
      subtitle: 'Enter the correct Gmail address. We\'ll send a new code to it, '
          'and the change is complete once you verify that address.',
      saveLabel: 'Update Email',
      isSaving: _isSaving,
      canSave: _canSave,
      onSave: _save,
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthTextField(
              label: 'New Gmail Address',
              hint: 'Enter your Gmail address',
              controller: _emailController,
              enabled: !_isSaving,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              validator: _validateEmail,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AuthFormError(message: _error!),
            ],
          ],
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