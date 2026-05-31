import 'package:flutter/material.dart';
import '../../../models/customer_account.dart';
import '../../../widgets/common/confirm_dialog.dart';

// ================================================
// CUSTOMER EDIT DIALOG
//
// Shows when super admin clicks Edit & View
// on a customer account row
//
// Super admin can:
//   - Edit first name and last name
//   - View contact info (read-only)
//   - Update password
// ================================================

void showCustomerEditDialog({
  required BuildContext context,
  required CustomerAccount account,
  required Function(CustomerAccount updatedAccount) onSave,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return CustomerEditDialog(
        account: account,
        onSave: onSave,
      );
    },
  );
}

class CustomerEditDialog extends StatefulWidget {
  final CustomerAccount account;
  final Function(CustomerAccount updatedAccount) onSave;

  const CustomerEditDialog({
    super.key,
    required this.account,
    required this.onSave,
  });

  @override
  State<CustomerEditDialog> createState() => _CustomerEditDialogState();
}

class _CustomerEditDialogState extends State<CustomerEditDialog> {

  // controllers for editable fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // ================================================
  // INIT STATE
  // ================================================
  @override
  void initState() {
    super.initState();
    _firstNameController.text = widget.account.firstName;
    _lastNameController.text = widget.account.lastName;
    _passwordController.text = '********';
  }

  // ================================================
  // DISPOSE
  // ================================================
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ================================================
  // HANDLE SAVE
  // uses ConfirmDialog before saving
  // ================================================
  Future<void> _handleSave() async {
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Update this account?',
      message: 'Changes to the account details will be saved immediately.',
      confirmLabel: 'Update',
      confirmColor: const Color(0xFF2563EB),
    );

    if (confirmed != true) return;

    // build updated account
    final CustomerAccount updated = CustomerAccount(
      id: widget.account.id,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: widget.account.email,
      phone: widget.account.phone,
      address: widget.account.address,
      landmark: widget.account.landmark,
      status: widget.account.status,
      lastLogin: widget.account.lastLogin,
      registeredOn: widget.account.registeredOn,
      isArchived: widget.account.isArchived,
      isDisabled: widget.account.isDisabled,
      archivedDate: widget.account.archivedDate,
      disabledDate: widget.account.disabledDate,
      disableReason: widget.account.disableReason,
    );

    widget.onSave(updated);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  // ================================================
  // BUILD INPUT FIELD
  // reusable styled text field
  // ================================================
  Widget _buildInputField({
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
            fontSize: 12,
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
                ? const Color(0xFF6B7280)
                : const Color(0xFF111827),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly
                ? const Color(0xFFF3F4F6)
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
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
  // BUILD READ ONLY INFO ROW
  // label + value, no text field
  // ================================================
  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  // ================================================
  // BUILD
  // follows feedback_details_dialog pattern:
  // fixed header + scrollable content + fixed footer
  // ================================================
  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: screenWidth < 700 ? screenWidth * 0.95 : 540,
        height: screenHeight * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── FIXED HEADER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit & View',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Update user account details',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE5E7EB), height: 1),
                ],
              ),
            ),

            // ── SCROLLABLE CONTENT ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── LEFT — editable name fields ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          _buildInputField(
                            label: 'First Name',
                            controller: _firstNameController,
                          ),

                          const SizedBox(height: 16),

                          _buildInputField(
                            label: 'Last Name',
                            controller: _lastNameController,
                          ),

                          const SizedBox(height: 20),

                          // read only info
                          _buildInfoRow(
                            'Contact Number',
                            widget.account.phone,
                          ),

                          const SizedBox(height: 12),

                          _buildInfoRow(
                            'Email',
                            widget.account.email,
                          ),

                          const SizedBox(height: 12),

                          _buildInfoRow(
                            'Address',
                            widget.account.address,
                          ),

                          const SizedBox(height: 12),

                          _buildInfoRow(
                            'Landmark',
                            widget.account.landmark,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 24),

                    // ── RIGHT — password section ──
                    SizedBox(
                      width: 180,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          const Text(
                            'Password and Security',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // password field — masked
                          _buildInputField(
                            label: 'Password',
                            controller: _passwordController,
                            obscureText: true,
                            readOnly: true,
                          ),

                          const SizedBox(height: 10),

                          // update password button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                // TODO: trigger password reset
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Update Password',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── FIXED FOOTER ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [

                  // cancel
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // update
                  ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}