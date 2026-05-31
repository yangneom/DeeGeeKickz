import 'package:flutter/material.dart';
import '../../../models/customer_account.dart';

// ================================================
// CUSTOMER DISABLE DIALOG
//
// Shows when super admin clicks Disable
// on a customer account row
//
// Super admin must select a reason:
//   - Suspicious Account Activity
//   - Multiple Failed Login Attempts
//   - Violation of Platform Policy
//   - Others (free text)
//
// HOW TO USE:
//   showCustomerDisableDialog(
//     context: context,
//     account: account,
//     onDisable: (reason) {
//       // handle disable
//     },
//   );
// ================================================

void showCustomerDisableDialog({
  required BuildContext context,
  required CustomerAccount account,
  required Function(String reason) onDisable,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return CustomerDisableDialog(
        account: account,
        onDisable: onDisable,
      );
    },
  );
}

class CustomerDisableDialog extends StatefulWidget {
  final CustomerAccount account;
  final Function(String reason) onDisable;

  const CustomerDisableDialog({
    super.key,
    required this.account,
    required this.onDisable,
  });

  @override
  State<CustomerDisableDialog> createState() => _CustomerDisableDialogState();
}

class _CustomerDisableDialogState extends State<CustomerDisableDialog> {

  // preset reasons from Figma
  final List<String> _presetReasons = [
    'Suspicious Account Activity',
    'Multiple Failed Login Attempts',
    'Violation of Platform Policy',
  ];

  // currently selected preset reason
  String? _selectedReason;

  // controller for the Others free text
  final TextEditingController _othersController = TextEditingController();

  // ================================================
  // DISPOSE
  // ================================================
  @override
  void dispose() {
    _othersController.dispose();
    super.dispose();
  }

  // ================================================
  // GET FINAL REASON
  // returns selected preset or the others text
  // ================================================
  String get _finalReason {
    if (_selectedReason != null) {
      return _selectedReason!;
    }
    return _othersController.text.trim();
  }

  // ================================================
  // CAN CONFIRM
  // true only when a reason is provided
  // ================================================
  bool get _canConfirm {
    if (_selectedReason != null) return true;
    return _othersController.text.trim().isNotEmpty;
  }

  // ================================================
  // HANDLE CONFIRM
  // ================================================
  void _handleConfirm() {
    if (_canConfirm == false) return;

    widget.onDisable(_finalReason);
    Navigator.pop(context);
  }

  // ================================================
  // BUILD RADIO OPTION
  // matches Figma radio button style
  // ================================================
  Widget _buildRadioOption(String reason) {
    final bool isSelected = _selectedReason == reason;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedReason = reason;
          // clear others text when preset is selected
          _othersController.clear();
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [

            // radio circle
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : Colors.white,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.circle,
                        size: 7,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),

            const SizedBox(width: 10),

            // reason label
            Text(
              reason,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.white,
      child: Container(
        width: 460,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── TITLE ──
            const Text(
              'Disable Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Please select a reason for disabling this account.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),

            const SizedBox(height: 20),

            // ── PRESET REASONS ──
            for (String reason in _presetReasons)
              _buildRadioOption(reason),

            const SizedBox(height: 16),

            // ── OTHERS LABEL ──
            const Text(
              'Others',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),

            const SizedBox(height: 8),

            // ── OTHERS TEXT FIELD ──
            TextField(
              controller: _othersController,
              maxLines: 4,
              onChanged: (String value) {
                // clear preset if typing in others
                setState(() {
                  if (value.isNotEmpty) {
                    _selectedReason = null;
                  }
                });
              },
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Specify Reason',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
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
                contentPadding: const EdgeInsets.all(12),
              ),
            ),

            const SizedBox(height: 24),

            // ── BUTTONS ──
            Row(
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

                // confirm — disabled until reason selected
                ElevatedButton(
                  onPressed: _canConfirm ? _handleConfirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFBFDBFE),
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
                    'Confirm',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}