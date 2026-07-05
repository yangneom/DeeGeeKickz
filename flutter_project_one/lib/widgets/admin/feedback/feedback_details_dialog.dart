// ================================================
// feedback_details_dialog.dart  (UPDATED)
//
// Changes from fake-data version:
//  1. onSave callback is now async (awaits provider call)
//  2. feedbackId is read from item['_feedbackId']
//     (set by FeedbackModel.toAdminMap())
//  3. 'Hidden' status option added to _statusOptions
//  4. UI structure, confirm dialog flow: UNCHANGED
// ================================================

import 'package:flutter/material.dart';
import '../../common/dialog/confirm_dialog.dart';

class FeedbackDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> feedback;

  // Now async — delegates real save to the provider via FeedbackScreen
  final Future<void> Function(String newStatus, String adminReply) onSave;

  const FeedbackDetailsDialog({
    super.key,
    required this.feedback,
    required this.onSave,
  });

  @override
  State<FeedbackDetailsDialog> createState() => _FeedbackDetailsDialogState();
}

class _FeedbackDetailsDialogState extends State<FeedbackDetailsDialog> {
  final TextEditingController _replyController = TextEditingController();
  String? _selectedStatus;
  bool _saving = false;

  // Hidden status now included
  final List<String> _statusOptions = ['Visible', 'Flagged', 'Hidden'];

  @override
  void initState() {
    super.initState();
    _selectedStatus       = widget.feedback['status'];
    _replyController.text = widget.feedback['adminReply'] ?? '';
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Map<String, Color> _getBadgeColors(String status) {
    if (status == 'Flagged') {
      return {
        'bg':     const Color(0xFFFEE2E2),
        'text':   const Color(0xFFDC2626),
        'border': const Color(0xFFFCA5A5),
      };
    }
    if (status == 'Hidden') {
      return {
        'bg':     const Color(0xFFF3F4F6),
        'text':   const Color(0xFF6B7280),
        'border': const Color(0xFFD1D5DB),
      };
    }
    return {
      'bg':     const Color(0xFFEFF6FF),
      'text':   const Color(0xFF2563EB),
      'border': const Color(0xFFBFDBFE),
    };
  }

  Future<void> _handleSave() async {
    final String currentStatus = widget.feedback['status'] as String;
    final String existingReply = widget.feedback['adminReply'] as String? ?? '';
    final String newReply      = _replyController.text.trim();
    final bool   statusChanged = _selectedStatus != currentStatus;

    // ── Confirm status change ──
    if (statusChanged) {
      String title        = '';
      String message      = '';
      Color  confirmColor = const Color(0xFF2563EB);

      if (_selectedStatus == 'Flagged') {
        title        = 'Flag this feedback?';
        message      = 'This will mark the comment as flagged and remove it from public view.';
        confirmColor = const Color(0xFFDC2626);
      } else if (_selectedStatus == 'Hidden') {
        title        = 'Hide this feedback?';
        message      = 'This feedback will be hidden from customers and will not appear publicly.';
        confirmColor = const Color(0xFF6B7280);
      } else if (_selectedStatus == 'Visible') {
        title        = 'Make this feedback visible?';
        message      = 'This feedback will be shown publicly to all customers.';
        confirmColor = const Color(0xFF16A34A);
      }

      final bool? confirmed = await showConfirmDialog(
        context:      context,
        title:        title,
        message:      message,
        confirmLabel: 'Confirm',
        confirmColor: confirmColor,
      );
      if (confirmed != true) return;
    }

    // ── Confirm overwrite existing reply ──
    final bool replyChanged      = newReply != existingReply;
    final bool hadExistingReply  = existingReply.isNotEmpty;

    if (replyChanged && hadExistingReply) {
      final bool? confirmed = await showConfirmDialog(
        context:      context,
        title:        'Overwrite existing reply?',
        message:      'You already have a saved reply. This will replace it with your new message.',
        confirmLabel: 'Overwrite',
        confirmColor: const Color(0xFF2563EB),
      );
      if (confirmed != true) return;
    }

    // ── Save via callback (async Supabase call in FeedbackScreen) ──
    setState(() => _saving = true);

    await widget.onSave(
      _selectedStatus ?? currentStatus,
      newReply,
    );

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }

  Widget _buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (int index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          size: 18,
          color: index < rating
              ? const Color(0xFFF59E0B)
              : const Color(0xFFD1D5DB),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth  = MediaQuery.of(context).size.width;

    final Map<String, Color> badgeColors =
        _getBadgeColors(widget.feedback['status'] as String);

    return Dialog(
      insetPadding:    EdgeInsets.zero,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width:  screenWidth < 700 ? screenWidth * 0.95 : 500,
        height: screenHeight * 0.85,
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize:      MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── FIXED HEADER — UNCHANGED ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Feedback Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'View comment and manage moderation',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE5E7EB),
                        child: Text(
                          (widget.feedback['customerName'] as String)
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.feedback['customerName'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.feedback['datePosted'] as String,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color:        badgeColors['bg'],
                          borderRadius: BorderRadius.circular(20),
                          border:       Border.all(color: badgeColors['border']!),
                        ),
                        child: Text(
                          widget.feedback['status'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: badgeColors['text'],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE5E7EB), height: 1),
                ],
              ),
            ),

            // ── SCROLLABLE CONTENT — UNCHANGED ──
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text('Product Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 4),
                    Text(widget.feedback['productReviewed'] as String, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    const SizedBox(height: 16),

                    const Text('Rating', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 4),
                    _buildStarRating(widget.feedback['rating'] as int),
                    const SizedBox(height: 16),

                    const Text('Full Feedback', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:        const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border:       Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        widget.feedback['comment'] as String,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      hint: const Text('Select Status', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                      decoration: InputDecoration(
                        filled:    true,
                        fillColor: const Color(0xFFF9FAFB),
                        border:       OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _statusOptions.map((String status) {
                        return DropdownMenuItem<String>(value: status, child: Text(status));
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() => _selectedStatus = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text('Admin Reply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _replyController,
                      maxLines:   4,
                      style:      const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText:  'Write a reply...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                        filled:    true,
                        fillColor: const Color(0xFFF9FAFB),
                        border:       OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB))),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── FIXED FOOTER ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side:   const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Reply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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