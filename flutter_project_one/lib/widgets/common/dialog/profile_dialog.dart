import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================
// PROFILE DIALOG
//
// Shows the logged-in user's profile details.
//
// - canEdit = false (Admin) → view-only, just shows info + Close.
// - canEdit = true  (Super Admin) → shows an Edit button that turns
//   the name/phone fields into text fields, then Save updates
//   the 'users' row in Supabase.
//
// All colors here are explicit (not theme-derived) so the dialog
// matches the app's white/grey/blue look regardless of the ambient
// MaterialApp theme (avoids the default Material 3 purple/pink tint).
// ================================================

const _kBlue = Color(0xFF2563EB);
const _kBlueBg = Color(0xFFEFF6FF);
const _kDarkText = Color(0xFF111827);
const _kMidText = Color(0xFF374151);
const _kMutedText = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE5E7EB);
const _kSurfaceGrey = Color(0xFFF9FAFB);

class ProfileDialog extends StatefulWidget {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final bool canEdit;

  const ProfileDialog({
    super.key,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    this.canEdit = false,
  });

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
    _phoneController = TextEditingController(text: widget.phone);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
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

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.from('users').update({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
      }).eq('id', widget.userId);

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated'),
          backgroundColor: _kDarkText,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── HEADER: title + close X ──
              Row(
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _kMidText,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: _kMutedText),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              CircleAvatar(
                radius: 36,
                backgroundColor: _kBorder,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _kMidText,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              if (!_isEditing) ...[
                Text(
                  _displayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _kDarkText,
                  ),
                ),
                if (widget.role.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kBlueBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.role.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kBlue,
                        letterSpacing: 0.3,
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
              ] else ...[
                // ── EDIT MODE (super admin only) ──
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Editing profile',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _firstNameController,
                  style: const TextStyle(fontSize: 13, color: _kMidText),
                  decoration: _fieldDecoration('First name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lastNameController,
                  style: const TextStyle(fontSize: 13, color: _kMidText),
                  decoration: _fieldDecoration('Last name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  style: const TextStyle(fontSize: 13, color: _kMidText),
                  decoration: _fieldDecoration('Phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _ProfileRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: widget.email.isNotEmpty ? widget.email : '—',
                ),
              ],

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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () {
                                setState(() {
                                  _isEditing = false;
                                  _firstNameController.text = widget.firstName;
                                  _lastNameController.text = widget.lastName;
                                  _phoneController.text = widget.phone;
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isSaving ? null : _handleSave,
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ] else if (widget.canEdit) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kMidText,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => setState(() => _isEditing = true),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _kSurfaceGrey,
            borderRadius: BorderRadius.circular(8),
          ),
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _kMidText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}