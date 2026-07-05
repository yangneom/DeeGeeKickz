import 'package:flutter/material.dart';

// ================================================
// CANCEL REASON DIALOG
//
// Shared widget used by:
//   - Admin: rejecting an order
//   - Customer: cancelling their own order
//
// HOW TO USE (admin reject):
//   showCancelReasonDialog(
//     context: context,
//     title: 'Reject Order',
//     subtitle: 'Select a reason to reject this order',
//     confirmLabel: 'Reject Order',
//     confirmColor: Color(0xFFEF4444),
//     onConfirm: (String reason) async {
//       await paymentService.rejectPayment(...);
//     },
//   );
//
// HOW TO USE (customer cancel):
//   showCancelReasonDialog(
//     context: context,
//     title: 'Cancel Order',
//     subtitle: 'Select a reason to cancel your order instantly',
//     confirmLabel: 'Cancel Order',
//     confirmColor: Color(0xFFEF4444),
//     onConfirm: (String reason) async {
//       await paymentService.cancelOrder(...);
//     },
//   );
// ================================================

Future<void> showCancelReasonDialog({
  required BuildContext context,
  required String       title,
  required String       subtitle,
  required String       confirmLabel,
  required Color        confirmColor,
  required Future<void> Function(String reason) onConfirm,
  List<String>?         reasons,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return CancelReasonDialog(
        title:        title,
        subtitle:     subtitle,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
        onConfirm:    onConfirm,
        reasons:      reasons ?? _defaultReasons,
      );
    },
  );
}

const List<String> _defaultReasons = [
  'Incomplete order details',
  'Duplicate order detected',
  'High delivery cost',
  'Invalid delivery address',
  'Suspicious transaction detected',
];

// ================================================
// DIALOG WIDGET
// ================================================
class CancelReasonDialog extends StatefulWidget {
  final String       title;
  final String       subtitle;
  final String       confirmLabel;
  final Color        confirmColor;
  final Future<void> Function(String reason) onConfirm;
  final List<String> reasons;

  const CancelReasonDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
    required this.reasons,
  });

  @override
  State<CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<CancelReasonDialog> {
  String? _selectedReason;
  final TextEditingController _otherController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  // ================================================
  // GET FINAL REASON STRING
  // ================================================
  String get _finalReason {
    if (_selectedReason == 'Others') {
      return _otherController.text.trim();
    }
    return _selectedReason ?? '';
  }

  // ================================================
  // HANDLE CONFIRM
  // ================================================
  Future<void> _handleConfirm() async {
    if (_finalReason.isEmpty) {
      setState(() {
        _errorMessage = 'Please select or specify a reason.';
      });
      return;
    }

    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm(_finalReason);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isLoading    = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical:   40,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── FIXED HEADER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize:   20,
                      fontWeight: FontWeight.bold,
                      color:      Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color:    Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                ],
              ),
            ),

            // ── SCROLLABLE BODY ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── REASON OPTIONS ──
                    ...widget.reasons.map((String reason) {
                      final bool isSelected = _selectedReason == reason;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedReason = reason;
                            _errorMessage   = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                reason,
                                style: TextStyle(
                                  fontSize:   15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              Container(
                                width:  20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? const Color(0xFF111827)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF111827)
                                        : const Color(0xFFD1D5DB),
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size:  12,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // ── OTHERS OPTION ──
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedReason = 'Others';
                          _errorMessage   = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Others',
                              style: TextStyle(
                                fontSize: 15,
                                color:    Color(0xFF111827),
                              ),
                            ),
                            Container(
                              width:  20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _selectedReason == 'Others'
                                    ? const Color(0xFF111827)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _selectedReason == 'Others'
                                      ? const Color(0xFF111827)
                                      : const Color(0xFFD1D5DB),
                                  width: 2,
                                ),
                              ),
                              child: _selectedReason == 'Others'
                                  ? const Icon(
                                      Icons.check,
                                      size:  12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── "OTHERS" TEXT FIELD ──
                    if (_selectedReason == 'Others') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _otherController,
                        maxLines:   4,
                        decoration: InputDecoration(
                          hintText: 'Specify reason',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color:    Color(0xFF9CA3AF),
                          ),
                          filled:      true,
                          fillColor:   const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF374151),
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],

                    // ── ERROR ──
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color:    Color(0xFFDC2626),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── FIXED FOOTER — confirm button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: GestureDetector(
                onTap: _isLoading ? null : _handleConfirm,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _isLoading
                        ? widget.confirmColor.withOpacity(0.6)
                        : widget.confirmColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width:  18,
                            height: 18,
                            child:  CircularProgressIndicator(
                              strokeWidth: 2,
                              color:       Colors.white,
                            ),
                          )
                        : Text(
                            widget.confirmLabel,
                            style: const TextStyle(
                              fontSize:   15,
                              fontWeight: FontWeight.w600,
                              color:      Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}