import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../services/auth/auth_service.dart';
import 'confirm_dialog.dart';
import '../../../screens/auth/mfa_enroll_screen.dart' show RecoveryCodesDialog;
import 'app_toast.dart';
import '../../../core/utils/form_validators.dart';

const _kBlue= Color(0xFF2563EB);
const _kBlueBg = Color(0xFFEFF6FF);
const _kDarkText = Color(0xFF111827);
const _kMidText = Color(0xFF374151);
const _kMutedText = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE5E7EB);
const _kSurfaceGrey = Color(0xFFF9FAFB);
const _kRed = Color(0xFFEF4444);
const _kGreen = Color(0xFF16A34A);

class ProfileDialog extends StatefulWidget {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final bool canEdit;
  // When true (used by the 30-day reminder), the password section
  // opens already expanded instead of requiring a tap to reveal it.
  final bool autoOpenPasswordSection;

  const ProfileDialog({
    super.key,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    this.canEdit = false,
    this.autoOpenPasswordSection = false,
  });

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  bool _isEditing = false;
  bool _isSaving = false;
  String? _nameError;

  // Latest saved names. Cancel restores these (not widget.firstName /
  // lastName, which go stale after a successful save).
  late String _savedFirstName;
  late String _savedLastName;

  // Only the Super Admin can change their own name from this dialog.
  bool get _canChangeName => widget.canEdit && widget.role == 'Super Admin';

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // ── Password change state ──
  final AuthService _authService = AuthService();
  late bool _showPasswordSection;
  bool _changingPassword = false;
  String? _passwordError;
  String? _passwordSuccess;
  // A message directly under each field.
  String? _currentError;
  String? _newError;
  String? _confirmError;
  // False until the first Update press. After that the fields re-check
  // themselves as the person corrects them.
  bool _showFieldErrors = false;
  // The inline authenticator-code step. It only appears when this session is
  // NOT at the two-factor level, so the change never navigates away (which used
  // to wipe what was typed and lose the pending update).
  bool _needsMfaCode = false;
  String? _mfaError;
  final _mfaCodeController = TextEditingController();
  // The emailed-code step, used when the project asks for reauthentication.
  bool _needsReauthCode = false;
  String? _reauthError;
  final _reauthCodeController = TextEditingController();
  // Numbers each attempt, and remembers the last one that was announced with a
  // toast, so one result can never produce two toasts.
  int _submitSeq = 0;
  int _toastedSeq = -1;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ── Recovery codes (Super Admin only) ──
  bool _showRecoverySection = false;
  int? _recoveryCodesRemaining;
  bool _regeneratingCodes = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
        _phoneController = TextEditingController(text: widget.phone);
    _savedFirstName = widget.firstName;
    _savedLastName = widget.lastName;
    _showPasswordSection = widget.autoOpenPasswordSection;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _mfaCodeController.dispose();
    _reauthCodeController.dispose();
    super.dispose();
  }

  String get _displayName {
    final name = '${_firstNameController.text} ${_lastNameController.text}'.trim();
    return name.isNotEmpty ? name : widget.email;
  }

  String get _initials {
    final name = _displayName.trim();
    if (name.isEmpty) return '?';
    return name
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  // Letters (including accented ones like ñ), spaces, hyphens,
  // apostrophes and periods, e.g. "Ma. Cristina", "O'Connor".
  static final RegExp _nameRegex = RegExp(r"^[\p{L}\s\-'.]+$", unicode: true);

  String? _validateName(String value, String label) {
    if (value.isEmpty) return '$label is required.';
    if (value.length > 50) return '$label is too long (max 50 characters).';
    if (!_nameRegex.hasMatch(value)) {
      return '$label can only contain letters, spaces, hyphens, apostrophes and periods.';
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (!_canChangeName) return;

    final String first =
        _firstNameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String last =
        _lastNameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');

    final String? validationError =
        _validateName(first, 'First name') ?? _validateName(last, 'Last name');
    if (validationError != null) {
      setState(() => _nameError = validationError);
      return;
    }

    // Nothing changed: just leave edit mode.
    if (first == _savedFirstName && last == _savedLastName) {
      setState(() {
        _isEditing = false;
        _nameError = null;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _nameError = null;
    });

    try {
      // .select() so an update silently blocked by RLS (0 rows) is
      // detected instead of being reported as a success.
      final List<dynamic> updated = await Supabase.instance.client
          .from('users')
          .update({'first_name': first, 'last_name': last})
          .eq('id', widget.userId)
          .select('id');

      if (updated.isEmpty) {
        throw Exception('No rows updated');
      }

      if (!mounted) return;
      // Refresh the top-bar greeting immediately instead of waiting for
      // the realtime event (which also fires, and is harmless).
      ProviderScope.containerOf(context).invalidate(ownProfileProvider);
      _firstNameController.text = first;
      _lastNameController.text = last;
      setState(() {
        _savedFirstName = first;
        _savedLastName = last;
        _isEditing = false;
        _isSaving = false;
      });

      AppToast.success(
        context,
        'Your name has been updated.',
        title: 'Name updated',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _nameError = 'Could not update your name. Please try again.';
      });
    }
  }

  // ── Change password ──

  // Checks all three fields and shows each problem under ITS field.
  // Nothing is sent anywhere until this passes.
  bool _validatePasswordFields() {
    final String current = _currentPasswordController.text;
    final String next = _newPasswordController.text;
    final String confirm = _confirmPasswordController.text;

    String? currentError;
    if (current.trim().isEmpty) currentError = 'Enter your current password.';

    String? newError = FormValidators.strongPassword(next);
    // Login trims the password, so "same as current" is judged the same way.
    if (newError == null && next == current.trim()) {
      newError = 'New password must be different from your current password.';
    }

    String? confirmError;
    if (confirm.isEmpty) {
      confirmError = 'Re-enter your new password.';
    } else if (confirm != next) {
      confirmError = 'Passwords do not match.';
    }

    setState(() {
      _currentError = currentError;
      _newError = newError;
      _confirmError = confirmError;
    });
    return currentError == null && newError == null && confirmError == null;
  }

  Future<void> _handleChangePassword() async {
    // A second tap while one is running (or while the confirmation is open).
    if (_changingPassword) return;

    setState(() {
      _passwordError = null;
      _passwordSuccess = null;
      _showFieldErrors = true;
    });

    if (!_validatePasswordFields()) return;

    // Locked from here, so the button can't be pressed twice while the
    // confirmation is open.
    setState(() => _changingPassword = true);

    // ── Confirmation step ──
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Update Password?',
      message: 'You\'ll need to use your new password the next time you log in. Continue?',
      confirmLabel: 'Update Password',
    );

    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _changingPassword = false);
      return;
    }

    await _submitPasswordChange();
  }

  // Sends the change and reacts to exactly what came back. The success message
  // is shown ONLY for PasswordChangeStatus.success.
  // Shows ONE toast for an attempt, in the app's normal toast style. The message
  // is always one of our own friendly messages, never raw server text.
  void _toastOnce(int attempt, {required bool success, required String message}) {
    if (!mounted || _toastedSeq == attempt) return;
    _toastedSeq = attempt;
    if (success) {
      AppToast.success(context, message, title: 'Password changed');
    } else {
      AppToast.error(context, message, title: 'Password not changed');
    }
  }

  Future<void> _submitPasswordChange({String? reauthCode}) async {
    final int attempt = ++_submitSeq;

    setState(() {
      _changingPassword = true;
      _passwordError = null;
    });

    final PasswordChangeResult result = await _authService.changeOwnPassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      reauthCode: reauthCode,
    );

    if (!mounted) return;

    switch (result.status) {
      case PasswordChangeStatus.success:
        setState(() {
          _changingPassword = false;
          _needsMfaCode = false;
          _needsReauthCode = false;
          _showFieldErrors = false;
          _currentError = null;
          _newError = null;
          _confirmError = null;
          _passwordSuccess = 'Password updated successfully.';
          // Don't leave passwords or codes sitting in the form.
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          _mfaCodeController.clear();
          _reauthCodeController.clear();
          _obscureCurrent = true;
          _obscureNew = true;
          _obscureConfirm = true;
        });
        // Reached only for PasswordChangeStatus.success, which is only produced
        // when the server answered the password update with a 2xx.
        _toastOnce(attempt, success: true, message: 'Password changed successfully.');
        return;

      case PasswordChangeStatus.wrongCurrentPassword:
        setState(() {
          _changingPassword = false;
          _needsMfaCode = false;
          _needsReauthCode = false;
          _currentError = result.message;
        });
        _toastOnce(attempt,
            success: false,
            message: result.message ?? 'Current password is incorrect.');
        return;

      case PasswordChangeStatus.needsMfa:
        setState(() {
          _changingPassword = false;
          _needsMfaCode = true;
          _mfaError = null;
        });
        return;

      case PasswordChangeStatus.needsReauthCode:
        setState(() {
          _changingPassword = false;
          _needsReauthCode = true;
          _reauthError = null;
          _reauthCodeController.clear();
        });
        return;

      case PasswordChangeStatus.reauthCodeInvalid:
        setState(() {
          _changingPassword = false;
          _needsReauthCode = true;
          _reauthError = result.message;
        });
        return;

      case PasswordChangeStatus.failed:
        final String failMessage =
            result.message ?? 'We couldn\'t update your password. Please try again.';
        setState(() {
          _changingPassword = false;
          _passwordError = failMessage;
        });
        _toastOnce(attempt, success: false, message: failMessage);
        return;
    }
  }

  // The authenticator-code step: verify the 6-digit code, and ONLY if it is
  // right, send the change that was waiting. A wrong code changes nothing.
  Future<void> _handleVerifyMfaAndUpdate() async {
    if (_changingPassword) return;

    final String code = _mfaCodeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _mfaError = 'Enter the 6-digit code from your authenticator app.');
      return;
    }

    setState(() {
      _changingPassword = true;
      _mfaError = null;
    });

    final String? failure = await _authService.verifyMfaCode(code);

    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _changingPassword = false;
        _mfaError = failure;
      });
      return;
    }

    _mfaCodeController.clear();
    setState(() => _needsMfaCode = false);
    await _submitPasswordChange();
  }

  // The emailed-code step, used when the project's "require reauthentication"
  // setting asks for it (the sign-in for this session is more than 24 hours old).
  Future<void> _handleVerifyReauthAndUpdate() async {
    if (_changingPassword) return;

    final String code = _reauthCodeController.text.trim();
    if (!RegExp(r'^\d{6,10}$').hasMatch(code)) {
      setState(() => _reauthError = 'Enter the code we emailed you.');
      return;
    }

    setState(() => _reauthError = null);
    await _submitPasswordChange(reauthCode: code);
  }

  Future<void> _handleResendReauthCode() async {
    if (_changingPassword) return;
    setState(() {
      _changingPassword = true;
      _reauthError = null;
    });
    final String? failure = await _authService.sendReauthenticationCode();
    if (!mounted) return;
    setState(() {
      _changingPassword = false;
      _reauthError = failure; // null when the new code was sent
    });
    if (failure == null) {
      AppToast.success(context, 'A new code was sent to your email.', title: 'Code sent');
    }
  }
  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: _kMutedText),
      isDense: true,
      filled: true,
      fillColor: _kSurfaceGrey,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBlue, width: 1.5),
      ),
    );
  }

  Widget _obscurableField({
    required TextEditingController controller,
    required String label,
    required bool obscured,
    required VoidCallback onToggle,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscured,
      enableSuggestions: false,
      autocorrect: false,
      // Frozen while a change is running or waiting for the code, so what was
      // confirmed is exactly what gets sent.
      readOnly: _changingPassword || _needsMfaCode || _needsReauthCode,
      style: const TextStyle(fontSize: 13, color: _kMidText),
      onChanged: (_) {
        if (_showFieldErrors) {
          _validatePasswordFields();
        } else if (_passwordError != null) {
          setState(() => _passwordError = null);
        }
      },
      decoration: _fieldDecoration(label).copyWith(
        errorText: errorText,
        errorMaxLines: 3,
        errorStyle: const TextStyle(fontSize: 11, color: _kRed),
        suffixIcon: IconButton(
          icon: Icon(
            obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
            color: _kMutedText,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  Widget _buildPasswordSection() {
    final bool stepActive = _needsMfaCode || _needsReauthCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: _kBorder),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => setState(() => _showPasswordSection = !_showPasswordSection),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Security',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kMidText),
              ),
              Icon(
                _showPasswordSection ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: _kMutedText,
              ),
            ],
          ),
        ),
        if (_showPasswordSection) ...[
          const SizedBox(height: 4),
          const Text(
            'We need your current password to confirm it\'s really you. '
            'Your new password needs at least 8 characters, with an uppercase '
            'letter, a lowercase letter, a number and a special character.',
            style: TextStyle(fontSize: 11, color: _kMutedText),
          ),
          const SizedBox(height: 12),
          _obscurableField(
            controller: _currentPasswordController,
            label: 'Current password',
            obscured: _obscureCurrent,
            onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
            errorText: _currentError,
          ),
          const SizedBox(height: 10),
          _obscurableField(
            controller: _newPasswordController,
            label: 'New password',
            obscured: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
            errorText: _newError,
          ),
          const SizedBox(height: 10),
          _obscurableField(
            controller: _confirmPasswordController,
            label: 'Re-enter new password',
            obscured: _obscureConfirm,
            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
            errorText: _confirmError,
          ),
          if (_needsMfaCode) ...[
            const SizedBox(height: 14),
            const Text(
              'For your security, enter the 6-digit code from your authenticator '
              'app to finish updating your password.',
              style: TextStyle(fontSize: 12, color: _kMidText),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mfaCodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              readOnly: _changingPassword,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 16, letterSpacing: 4, color: _kMidText),
              decoration: _fieldDecoration('Authenticator code').copyWith(
                counterText: '',
                hintText: '000000',
                errorText: _mfaError,
                errorMaxLines: 3,
                errorStyle: const TextStyle(fontSize: 11, color: _kRed),
              ),
              onChanged: (_) {
                if (_mfaError != null) setState(() => _mfaError = null);
              },
              onSubmitted: (_) => _handleVerifyMfaAndUpdate(),
            ),
          ],
          if (_needsReauthCode) ...[
            const SizedBox(height: 14),
            const Text(
              'For your security, we emailed you a code. Enter it to finish '
              'updating your password.',
              style: TextStyle(fontSize: 12, color: _kMidText),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reauthCodeController,
              keyboardType: TextInputType.number,
              maxLength: 10,
              autofocus: true,
              readOnly: _changingPassword,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 16, letterSpacing: 3, color: _kMidText),
              decoration: _fieldDecoration('Code from your email').copyWith(
                counterText: '',
                errorText: _reauthError,
                errorMaxLines: 3,
                errorStyle: const TextStyle(fontSize: 11, color: _kRed),
              ),
              onChanged: (_) {
                if (_reauthError != null) setState(() => _reauthError = null);
              },
              onSubmitted: (_) => _handleVerifyReauthAndUpdate(),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _changingPassword ? null : _handleResendReauthCode,
                child: const Text('Send a new code', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
          if (_passwordError != null) ...[
            const SizedBox(height: 10),
            Text(_passwordError!, style: const TextStyle(fontSize: 12, color: _kRed)),
          ],
          if (_passwordSuccess != null) ...[
            const SizedBox(height: 10),
            Text(_passwordSuccess!, style: const TextStyle(fontSize: 12, color: _kGreen)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _changingPassword
                  ? null
                  : (_needsMfaCode
                      ? _handleVerifyMfaAndUpdate
                      : (_needsReauthCode
                          ? _handleVerifyReauthAndUpdate
                          : _handleChangePassword)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _changingPassword
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      stepActive ? 'Verify and Update Password' : 'Update Password',
                      style: const TextStyle(fontSize: 13),
                    ),
            ),
          ),
          if (stepActive && !_changingPassword)
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => setState(() {
                  _needsMfaCode = false;
                  _needsReauthCode = false;
                  _mfaError = null;
                  _reauthError = null;
                  _mfaCodeController.clear();
                  _reauthCodeController.clear();
                }),
                child: const Text('Cancel', style: TextStyle(fontSize: 12, color: _kMutedText)),
              ),
            ),
        ],
      ],
    );
  }
    Widget _buildRecoverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(height: 1, color: _kBorder),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => setState(() => _showRecoverySection = !_showRecoverySection),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Account Recovery',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kMidText),
              ),
              Icon(
                _showRecoverySection ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: _kMutedText,
              ),
            ],
          ),
        ),
        if (_showRecoverySection) ...[
          const SizedBox(height: 12),
          Text(
            _recoveryCodesRemaining == null
                ? 'Loading recovery codes…'
                : 'Recovery codes remaining: $_recoveryCodesRemaining of 10',
            style: const TextStyle(fontSize: 12, color: _kMutedText),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _regeneratingCodes ? null : _handleRegenerateCodes,
              icon: _regeneratingCodes
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 16),
              label: const Text('Regenerate Recovery Codes', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kMidText,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ],
    );
  }

    Future<void> _handleRegenerateCodes() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Regenerate Recovery Codes?',
      message: 'This will invalidate all of your current recovery codes '
          'and create 10 new ones. Your current authenticator will not '
          'be changed.',
      confirmLabel: 'Generate New Codes',
    );
    if (confirmed != true) return;

    setState(() => _regeneratingCodes = true);

    try {
      final List<dynamic> codes = await Supabase.instance.client.rpc(
        'generate_mfa_recovery_codes',
        params: {'p_user_id': widget.userId},
      );

      if (!mounted) return;
      setState(() {
        _regeneratingCodes = false;
        _recoveryCodesRemaining = 10;
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RecoveryCodesDialog(codes: codes.cast<String>()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _regeneratingCodes = false);
      AppToast.error(
        context,
        'We could not create new recovery codes. Please try again.',
        title: 'Recovery codes not changed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Profile',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kMidText),
                ),
              ),

              const SizedBox(height: 16),

              CircleAvatar(
                radius: 36,
                backgroundColor: _kBorder,
                child: Text(
                  _initials,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kMidText),
                ),
              ),
              const SizedBox(height: 14),

              if (!_isEditing) ...[
                Text(
                  _displayName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kDarkText),
                ),
                if (widget.role.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      widget.role.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: _kBlue, letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(height: 1, color: _kBorder),
                const SizedBox(height: 16),
                _ProfileRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: widget.email.isNotEmpty ? widget.email : '—',
                ),
                const SizedBox(height: 14),
                               _ProfileRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: _phoneController.text.isNotEmpty ? _phoneController.text : '—',
                ),
                // Super Admin only: change your own name.
                if (_canChangeName) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Change your name', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kMidText,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ] else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Editing profile',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                  ),
                ),
                const SizedBox(height: 12),
                               TextField(
                  controller: _firstNameController,
                  style: const TextStyle(fontSize: 13, color: _kMidText),
                  decoration: _fieldDecoration('First name'),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                    LengthLimitingTextInputFormatter(50),
                  ],
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lastNameController,
                  style: const TextStyle(fontSize: 13, color: _kMidText),
                  decoration: _fieldDecoration('Last name'),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                    LengthLimitingTextInputFormatter(50),
                  ],
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
                if (_nameError != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_nameError!, style: const TextStyle(fontSize: 12, color: _kRed)),
                  ),
                ],
                const SizedBox(height: 14),
                _ProfileRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: _phoneController.text.isNotEmpty ? _phoneController.text : '—',
                ),
                const SizedBox(height: 14),
                _ProfileRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: widget.email.isNotEmpty ? widget.email : '—',
                ),
                const SizedBox(height: 20),
              ],

                           // ── Security / change-password section (always available) ──
              _buildPasswordSection(),

              if (widget.role == 'Super Admin') _buildRecoverySection(),

              const SizedBox(height: 24),

              if (widget.canEdit && _isEditing) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kMidText,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () {
                                                                setState(() {
                                  _isEditing = false;
                                  _nameError = null;
                                  _firstNameController.text = _savedFirstName;
                                  _lastNameController.text = _savedLastName;
                                });
                              },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isSaving ? null : _handleSave,
                        child: _isSaving
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kMidText,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}



class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: _kSurfaceGrey, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: _kMutedText),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: _kMutedText)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _kMidText),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}