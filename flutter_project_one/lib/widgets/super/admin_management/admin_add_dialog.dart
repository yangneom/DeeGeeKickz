import 'package:flutter/material.dart';
import '../../common/dialog/confirm_dialog.dart';
// ================================================
// ADMIN ADD DIALOG
//
// Shows when super admin clicks "Add Account"
// Creates a new admin or cashier account
// ================================================

void showAdminAddDialog(
  BuildContext context,
  Future<void> Function({
  required String firstName,
  required String lastName,   
  required String email,
  required String role,
  }) onAdd,
) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AdminAddDialog(onAdd: onAdd);
    },  
  );
}

class AdminAddDialog extends StatefulWidget {
  final Future<void> Function({
  required String firstName,
  required String lastName,
  required String email,
  required String role,
}) onAdd;

  const AdminAddDialog({
    super.key,
    required this.onAdd,
  });


  @override
  State<AdminAddDialog> createState() => _AdminAddDialogState();
}

class _AdminAddDialogState extends State<AdminAddDialog> {

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

    String _selectedRole = 'Admin';
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Pulls the real error text out of a raw FunctionException dump
  // (e.g. "FunctionException(status: 400, details: {..., error: '...'}, ...)")
  // and translates known backend phrasing into plain, admin-facing wording.
  String _extractFriendlyError(Object e) {
    final String raw = e.toString();

    final RegExp pattern = RegExp(r'error:\s*(.+?)(?:,\s*reasonPhrase|\}$|\)$)');
    final Match? match = pattern.firstMatch(raw);
    String message = match != null ? match.group(1)!.trim() : raw;
    message = message.replaceAll(RegExp(r'[\{\}]+$'), '').trim();

    final String lower = message.toLowerCase();
    if (lower.contains('already been registered') || lower.contains('already exists')) {
      return 'An account with this email already exists.';
    }
    if (lower.contains('invalid role')) {
      return 'That role is not valid. Please pick a different role.';
    }
    if (lower.contains('forbidden')) {
      return 'You don\'t have permission to create this type of account.';
    }
    if (lower.contains('missing required fields')) {
      return 'Please fill in all required fields.';
    }

    return message;
  }

  // ================================================
  // HANDLE ADD
  // ================================================
Future<void> _handleAdd() async {
    // validate
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all required fields.';
      });
      return;
    }

    // Real format check — previously only checked for empty, so
    // something like "asdf" with no @ would pass here and only fail
    // later, confusingly, once it actually hit Supabase Auth.
    final String trimmedEmail = _emailController.text.trim();
    final RegExp emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(trimmedEmail)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
      });
      return;
    }

    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();

    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Create this account?',
      message: '$firstName $lastName will be added as $_selectedRole '
          'and will be able to log in with the email provided.',
      confirmLabel: 'Create Account',
      confirmColor: const Color(0xFF2563EB),
    );

     if (confirmed != true) return;
    // Cancelling here leaves the form exactly as it was — nothing is
    // cleared, so the admin can adjust details and try again without
    // retyping everything.

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onAdd(
        firstName: firstName,
        lastName: lastName,
        email: _emailController.text.trim(),
        role: _selectedRole,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$firstName $lastName was added as $_selectedRole.'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _extractFriendlyError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================================================
  // BUILD TEXT FIELD
  // ================================================
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
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
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
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

            // ── FIXED HEADER ──
            Container(
              width: double.infinity,
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Create a new admin or cashier account.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
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

                    _buildTextField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 16),


                    // role dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Role',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedRole,
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF111827),
                              ),
                              items: ['Admin', 'Cashier']
                                  .map((String role) {
                                return DropdownMenuItem<String>(
                                  value: role,
                                  child: Text(role),
                                );
                              }).toList(),
                              onChanged: (String? value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedRole = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    const SizedBox(height: 16),

                    // error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFCA5A5),
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // footer buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
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
                                                ElevatedButton(
                          onPressed: _isLoading ? null : _handleAdd,
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
                          child: _isLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Add Account',
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