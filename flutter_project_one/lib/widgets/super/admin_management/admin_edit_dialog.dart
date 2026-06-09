import 'package:flutter/material.dart';
import '../../../models/admin_account.dart';

// ================================================
// ADMIN EDIT DIALOG
//
// Shows when super admin clicks "Edit & View"
// on an admin account
//
// Contains:
//   - First Name + Last Name fields
//   - Contact Number (read only)
//   - Email (read only)
//   - Password and Security section
// ================================================

late TextEditingController _phoneController;
late TextEditingController _emailController;

void showAdminEditDialog(
  BuildContext context,
  AdminAccount account,
  Function(AdminAccount) onSave,
) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AdminEditDialog(
        account: account,
        onSave: onSave,
      );
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
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  bool _showPasswordFields = false;
  String? _passwordError;

 @override
void initState() {
  super.initState();
  _firstNameController = TextEditingController(
    text: widget.account.firstName,
  );
  _lastNameController = TextEditingController(
    text: widget.account.lastName,
  );
  _phoneController = TextEditingController(
    text: widget.account.phone,        // ← populated here, not inline
  );
  _emailController = TextEditingController(
    text: widget.account.email,        // ← populated here, not inline
  );
  _newPasswordController = TextEditingController();
  _confirmPasswordController = TextEditingController();

  _newPasswordController.addListener(() {
  final hasText = _newPasswordController.text.isNotEmpty;
  if (hasText != _showPasswordFields) {
    setState(() {
      _showPasswordFields = hasText;
      if (!hasText) _passwordError = null;
    });
  }
});

}

@override
void dispose() {
  _firstNameController.dispose();
  _lastNameController.dispose();
  _phoneController.dispose();          // ← dispose here
  _emailController.dispose();          // ← dispose here
  _newPasswordController.dispose();
  _confirmPasswordController.dispose();
  super.dispose();
}

  // ================================================
  // HANDLE SAVE
  // ================================================
  void _handleSave() {
    // validate password if shown
    if (_showPasswordFields) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        setState(() {
          _passwordError = 'Passwords do not match.';
        });
        return;
      }
      if (_newPasswordController.text.length < 6) {
        setState(() {
          _passwordError = 'Password must be at least 6 characters.';
        });
        return;
      }
    }

    widget.onSave(
    widget.account.copyWith(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
    ),
  );

    Navigator.pop(context);
  }

  // ================================================
  // BUILD TEXT FIELD
  // ================================================
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
            color: readOnly
                ? const Color(0xFF9CA3AF)
                : const Color(0xFF111827),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly
                ? const Color(0xFFF9FAFB)
                : Colors.white,
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

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 40,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── FIXED HEADER ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB)),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xFF6B7280),
                    ),
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

                    // first name + last name
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

                    // email — read only
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

                    const SizedBox(height: 12),

                    // new password field
                    _buildTextField(
                      label: 'New Password',
                      controller: _newPasswordController,
                      obscureText: true,
                    ),

                    // show confirm field when typing
                    if (_showPasswordFields) ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Re-enter Password',
                        controller: _confirmPasswordController,
                        obscureText: true,
                      ),
                    ],

                    if (_passwordError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _passwordError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],  

                    const SizedBox(height: 12),

                    // update password button
                    ElevatedButton(
                       onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Update Password',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── FOOTER BUTTONS ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [

                        // cancel
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            side: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // update
                        ElevatedButton(
                          onPressed: _handleSave,
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
                          child: const Text(
                            'Update',
                            style: TextStyle(fontSize: 13),
                          ),
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