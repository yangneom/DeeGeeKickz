import 'package:flutter/material.dart';

// ================================================
// CANCEL REASON DIALOG
//
// Shared widget used by:
//   - Admin: rejecting an order
//   - Customer: cancelling their own order
//
// WHAT CHANGED
//   Two OPTIONAL parameters were added, so every existing call keeps working
//   and the admin dialog looks exactly as before:
//     style:        CancelDialogStyle.admin (default) | CancelDialogStyle.customer
//     dismissLabel: text of a second "go back" button (customer style only)
//
//   Customer style follows the rest of the customer site: square corners,
//   #CFC4C5 borders, Inter / Archivo Narrow, a radio list with a clear selected
//   state, a "go back" button, and a confirm button that stays grey until a
//   reason is chosen.
//
//   Fixes that apply to BOTH styles (they were bugs, not styling):
//     - While the request is running, Back / Esc / tapping outside can no longer
//       close the dialog and leave the request running unseen.
//     - A second tap on the confirm button cannot send a second request.
//     - If the request fails after the dialog was closed, it no longer calls
//       setState on a dead dialog.
//     - The dialog only closes itself if it is still open. Some callers also
//       pop inside onConfirm, and two pops closed the page UNDER the dialog.
//     - "Others" text is limited to 200 characters.
//     - If the caller's reasons already contain "Others", it is not shown twice.
//
// HOW TO USE (admin reject): unchanged
//   showCancelReasonDialog(
//     context: context,
//     title: 'Reject Order',
//     subtitle: 'Select a reason to reject this order',
//     confirmLabel: 'Reject Order',
//     confirmColor: Color(0xFFEF4444),
//     onConfirm: (String reason) async { ... },
//   );
//
// HOW TO USE (customer cancel):
//   showCancelReasonDialog(
//     context: context,
//     style: CancelDialogStyle.customer,
//     title: 'Cancel Order',
//     subtitle: '...',
//     confirmLabel: 'Cancel Order',
//     dismissLabel: 'Keep Order',
//     confirmColor: Color(0xFFBA1A1A),
//     onConfirm: (String reason) async { ... },
//   );
// ================================================

enum CancelDialogStyle { admin, customer }

Future<void> showCancelReasonDialog({
  required BuildContext context,
  required String       title,
  required String       subtitle,
  required String       confirmLabel,
  required Color        confirmColor,
  required Future<void> Function(String reason) onConfirm,
  List<String>?         reasons,
  CancelDialogStyle     style = CancelDialogStyle.admin,
  String?               dismissLabel,
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
        style:        style,
        dismissLabel: dismissLabel,
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
  final CancelDialogStyle style;
  final String?      dismissLabel;

  const CancelReasonDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
    required this.reasons,
    this.style = CancelDialogStyle.admin,
    this.dismissLabel,
  });

  @override
  State<CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<CancelReasonDialog> {
  // Customer-style tokens (the same values checkout and the address cards use).
  static const Color _border   = Color(0xFFCFC4C5);
  static const Color _muted    = Color(0xFF656464);
  static const Color _errorRed = Color(0xFFBA1A1A);
  static const int   _maxOtherLength = 200;

  String? _selectedReason;
  final TextEditingController _otherController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isCustomer => widget.style == CancelDialogStyle.customer;

  // "Others" is always offered by this dialog, so never list it twice.
  List<String> get _reasonList =>
      widget.reasons.where((String r) => r != 'Others').toList();

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

  // Null when a usable reason has been given.
  String? get _validationMessage {
    if (!_isCustomer) {
      return _finalReason.isEmpty
          ? 'Please select or specify a reason.'
          : null;
    }
    if (_selectedReason == null) return 'Please select a reason.';
    if (_finalReason.isEmpty) return 'Please tell us the reason.';
    return null;
  }

  // Customer style only: turns the database's answer into a sentence. The
  // admin dialog keeps its original generic message.
  String _friendlyError(Object error) {
    final String msg = error.toString();
    if (msg.contains('P1005') || msg.contains('no longer Pending')) {
      return 'This order can no longer be cancelled because it has already '
          'been processed.';
    }
    if (msg.contains('28000') || msg.contains('Not authorized')) {
      return 'You are not allowed to cancel this order.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _select(String reason) {
    if (_isLoading) return;
    setState(() {
      _selectedReason = reason;
      _errorMessage   = null;
    });
  }

  // ================================================
  // HANDLE CONFIRM
  // ================================================
  Future<void> _handleConfirm() async {
    // A second tap while the first request is running does nothing.
    if (_isLoading) return;

    final String? problem = _validationMessage;
    if (problem != null) {
      setState(() {
        _errorMessage = problem;
      });
      return;
    }

    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm(_finalReason);

      // Close only if this dialog is still open. Some callers pop it
      // themselves inside onConfirm; a second pop would close the PAGE under
      // the dialog as well.
      if (mounted && (ModalRoute.of(context)?.isActive ?? false)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            _isCustomer ? _friendlyError(e) : 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // canPop is false while a request is running: system Back, Esc and a tap on
    // the dark area cannot close the dialog and hide the request.
    return PopScope(
      canPop: !_isLoading,
      child: _isCustomer ? _buildCustomer(context) : _buildAdmin(context),
    );
  }

  // ================================================================
  // ADMIN LOOK: unchanged from before
  // ================================================================
  Widget _buildAdmin(BuildContext context) {
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
                    ..._reasonList.map((String reason) {
                      final bool isSelected = _selectedReason == reason;
                      return GestureDetector(
                        onTap: () => _select(reason),
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
                      onTap: () => _select('Others'),
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
                        maxLength:  _maxOtherLength,
                        // The limit is enforced, but the admin look had no
                        // counter, so none is drawn here.
                        buildCounter: (
                          BuildContext context, {
                          required int currentLength,
                          required bool isFocused,
                          required int? maxLength,
                        }) =>
                            null,
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

  // ================================================================
  // CUSTOMER LOOK: DeeGee Kickz theme
  // ================================================================
  Widget _buildCustomer(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;
    final bool noReason = _finalReason.isEmpty;

    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  440,
          maxHeight: screen.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── FIXED HEADER ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title.toUpperCase(),
                    style: const TextStyle(
                      fontFamily:    'Archivo Narrow',
                      fontSize:      24,
                      fontWeight:    FontWeight.w700,
                      letterSpacing: 0.5,
                      color:         Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize:   14,
                      height:     1.5,
                      color:      Color(0xFF4C4546),
                    ),
                  ),
                ],
              ),
            ),

            // ── SCROLLABLE BODY ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._reasonList
                        .map((String reason) => _customerReasonRow(reason)),
                    _customerReasonRow('Others'),

                    if (_selectedReason == 'Others') ...[
                      const SizedBox(height: 12),
                      Semantics(
                        label: 'Reason for cancelling',
                        textField: true,
                        child: TextField(
                          controller: _otherController,
                          enabled:    !_isLoading,
                          maxLines:   3,
                          maxLength:  _maxOtherLength,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {
                            _errorMessage = null;
                          }),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize:   14,
                            color:      Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tell us the reason',
                            hintStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize:   14,
                              color:      Color(0xFF9CA3AF),
                            ),
                            counterStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize:   11,
                              color:      _muted,
                            ),
                            filled:    true,
                            fillColor: Colors.white,
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide:   BorderSide(color: _border),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide:   BorderSide(color: _border),
                            ),
                            disabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide:   BorderSide(color: _border),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide:
                                  BorderSide(color: Colors.black, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:  const Color(0xFFFEF2F2),
                            border: Border.all(
                                color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 16, color: _errorRed),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize:   12,
                                    height:     1.4,
                                    color:      Color(0xFF7A1212),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── FIXED FOOTER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Confirm: grey until a reason is chosen. Tapping the grey
                  // button still explains what is missing.
                  Semantics(
                    button: true,
                    enabled: !_isLoading,
                    label: _isLoading
                        ? 'Cancelling order'
                        : widget.confirmLabel,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _isLoading ? null : _handleConfirm,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: _isLoading
                            ? _muted
                            : (noReason ? _border : widget.confirmColor),
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Processing...',
                                    style: TextStyle(
                                      fontFamily:    'Inter',
                                      fontSize:      14,
                                      fontWeight:    FontWeight.w600,
                                      letterSpacing: 2.0,
                                      color:         Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                widget.confirmLabel.toUpperCase(),
                                style: TextStyle(
                                  fontFamily:    'Inter',
                                  fontSize:      14,
                                  fontWeight:    FontWeight.w600,
                                  letterSpacing: 2.0,
                                  color: noReason ? _muted : Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),

                  // Second button: go back without cancelling.
                  if (widget.dismissLabel != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      button: true,
                      enabled: !_isLoading,
                      label: widget.dismissLabel,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: _border),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.dismissLabel!.toUpperCase(),
                            style: TextStyle(
                              fontFamily:    'Inter',
                              fontSize:      14,
                              fontWeight:    FontWeight.w600,
                              letterSpacing: 2.0,
                              color: _isLoading ? _muted : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // One row of the customer reason list. A real radio-group row for screen
  // readers (selected / not selected), reachable with the keyboard, with a
  // filled radio, a bold label and a grey background when selected.
  Widget _customerReasonRow(String reason) {
    final bool isSelected = _selectedReason == reason;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: isSelected,
      button: true,
      label: reason,
      excludeSemantics: true,
      onTap: _isLoading ? null : () => _select(reason),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _border)),
        ),
        child: Material(
          color: isSelected ? const Color(0xFFF3F3F4) : Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : () => _select(reason),
            hoverColor:     const Color(0xFFF3F3F4),
            focusColor:     const Color(0xFFE7E7E8),
            splashColor:    Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.black : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? Colors.black
                            : const Color(0xFF7E7576),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.circle, size: 8, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize:   14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}