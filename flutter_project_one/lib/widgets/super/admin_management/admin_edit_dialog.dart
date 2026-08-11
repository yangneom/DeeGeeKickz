import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/admin_account.dart';
import '../../common/dialog/confirm_dialog.dart';

void showAdminEditDialog(
  BuildContext context,
  AdminAccount account,
  Function(AdminAccount) onSave,
) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AdminEditDialog(account: account, onSave: onSave);
    },
  );
}

class AdminEditDialog extends StatefulWidget {
  final AdminAccount account;
  final Function(AdminAccount) onSave;

  const AdminEditDialog({
    super.key,
    required this.account,
    required this.onSave,
  });

  @override
  State<AdminEditDialog> createState() => _AdminEditDialogState();
}

class _AdminEditDialogState extends State<AdminEditDialog> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  bool _showPasswordFields = false;
  bool _saving = false;
  String? _formError;
  String? _formSuccess;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.account.firstName);
    _lastNameController = TextEditingController(text: widget.account.lastName);
    _phoneController = TextEditingController(text: widget.account.phone);
    _emailController = TextEditingController(text: widget.account.email);
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    _newPasswordController.addListener(() {
      final hasText = _newPasswordController.text.isNotEmpty;
      if (hasText != _showPasswordFields) {
        setState(() {
          _showPasswordFields = hasText;
          if (!hasText) {
            _formError = null;
            _formSuccess = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Validate + confirm + save (name, and password if provided) ──
  Future<void> _handleSaveAll() async {
    setState(() {
      _formError = null;
      _formSuccess = null;
    });

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _formError = 'First and last name are required.');
      return;
    }

    final wantsPasswordChange = newPass.isNotEmpty;

    if (wantsPasswordChange) {
      if (newPass.length < 8) {
        setState(() => _formError = 'Password must be at least 8 characters.');
        return;
      }
      if (newPass != confirmPass) {
        setState(() => _formError = 'Passwords do not match.');
        return;
      }
    }

    // ── Confirmation step ──
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Save Changes?',
      message: wantsPasswordChange
          ? 'This will update this account\'s details and set a new login password for this account. Continue?'
          : 'This will update this account\'s details. Continue?',
      confirmLabel: 'Save Changes',
    );

    if (confirmed != true) return;

    setState(() => _saving = true);

    try {
      // 1. Always save name changes
      widget.onSave(
        widget.account.copyWith(
          firstName: firstName,
          lastName: lastName,
        ),
      );

      // 2. Optionally update password
      if (wantsPasswordChange) {
        final response = await Supabase.instance.client.functions.invoke(
          'update-user-password',
          body: {
            'user_id': widget.account.id,
            'new_password': newPass,
          },
        );

        print('========== UPDATE PASSWORD RESPONSE ==========');
        print('Status: ${response.status}');
        print('Data: ${response.data}');
        print('================================================');

        final data = response.data;
        final success = data is Map && data['success'] == true;

        if (!success) {
          final errorMsg = (data is Map ? data['error'] : null) ??
              'Password update failed (status ${response.status}).';
          throw Exception(errorMsg);
        }
      }

      if (!mounted) return;
      setState(() => _formSuccess = 'Saved successfully.');

      // Close after a brief moment so the user sees the success state
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print('========== SAVE ERROR ==========');
      print(e);
      print('=================================');
      if (mounted) {
        setState(() => _formError = 'Failed to save: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          obscureText: obscureText,
          style: TextStyle(
            fontSize: 13,
            color: readOnly ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly ? const Color(0xFFF9FAFB) : Colors.white,
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
              borderSide: const BorderSide(color: Color(0xFF2563EB)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

           // ── HEADER ──
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
                    'Edit & View',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Update admin account details',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),

            // ── SCROLLABLE CONTENT ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Name row
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'First Name',
                            controller: _firstNameController,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            label: 'Last Name',
                            controller: _lastNameController,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _buildTextField(
                      label: 'Email',
                      controller: _emailController,
                      readOnly: true,
                    ),

                    const SizedBox(height: 24),

                    // ── PASSWORD SECTION ──
                    const Text(
                      'Password and Security',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Leave blank to keep the current password.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),

                    const SizedBox(height: 12),

                    _buildTextField(
                      label: 'New Password',
                      controller: _newPasswordController,
                      obscureText: true,
                    ),

                    if (_showPasswordFields) ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Re-enter Password',
                        controller: _confirmPasswordController,
                        obscureText: true,
                      ),
                    ],

                    if (_formError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _formError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],

                    if (_formSuccess != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _formSuccess!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── FOOTER BUTTONS (single save action) ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _saving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _saving ? null : _handleSaveAll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save Changes', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}