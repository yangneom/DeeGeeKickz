import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../services/auth/auth_service.dart';
import 'confirm_dialog.dart';
import '../../../screens/auth/mfa_enroll_screen.dart' show RecoveryCodesDialog;
import 'app_toast.dart';

const _kBlue = Color(0xFF2563EB);
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
 Future<void> _handleChangePassword() async {
    setState(() {
      _passwordError = null;
      _passwordSuccess = null;
    });

    final current = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (current.isEmpty) {
      setState(() => _passwordError = 'Enter your current password.');
      return;
    }
    if (newPass.length < 8) {
      setState(() => _passwordError = 'New password must be at least 8 characters.');
      return;
    }
    if (newPass != confirm) {
      setState(() => _passwordError = 'New passwords do not match.');
      return;
    }
    if (newPass == current) {
      setState(() => _passwordError = 'New password must be different from your current password.');
      return;
    }

    // ── Confirmation step ──
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Update Password?',
      message: 'You\'ll need to use your new password the next time you log in. Continue?',
      confirmLabel: 'Update Password',
    );

    if (confirmed != true) return;

    setState(() => _changingPassword = true);

    final error = await _authService.changeOwnPassword(
      currentPassword: current,
      newPassword: newPass,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _changingPassword = false;
        _passwordError = error;
      });
      return;
    }

    setState(() {
      _changingPassword = false;
      _passwordSuccess = 'Password updated successfully.';
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
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
  }) {
    return TextField(
      controller: controller,
      obscureText: obscured,
      style: const TextStyle(fontSize: 13, color: _kMidText),
      onChanged: (_) {
        if (_passwordError != null) setState(() => _passwordError = null);
      },
      decoration: _fieldDecoration(label).copyWith(
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
            'New password must be at least 8 characters.',
            style: TextStyle(fontSize: 11, color: _kMutedText),
          ),
          const SizedBox(height: 12),
          _obscurableField(
            controller: _currentPasswordController,
            label: 'Current password',
            obscured: _obscureCurrent,
            onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
          ),
          const SizedBox(height: 10),
          _obscurableField(
            controller: _newPasswordController,
            label: 'New password',
            obscured: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
          ),
          const SizedBox(height: 10),
          _obscurableField(
            controller: _confirmPasswordController,
            label: 'Re-enter new password',
            obscured: _obscureConfirm,
            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
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
              onPressed: _changingPassword ? null : _handleChangePassword,
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
                  : const Text('Update Password', style: TextStyle(fontSize: 13)),
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