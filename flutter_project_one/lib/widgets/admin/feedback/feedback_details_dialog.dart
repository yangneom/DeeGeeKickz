  import 'package:flutter/material.dart';
import '../../../widgets/common/confirm_dialog.dart';

// ================================================
// FEEDBACK DETAILS DIALOG
// shows full feedback info when View is clicked
// admin can change status and add a reply here
// ================================================
class FeedbackDetailsDialog extends StatefulWidget {

  // the feedback data passed in from the table row
  final Map<String, dynamic> feedback;

  // called when admin saves changes
  // passes back the new status and reply
  final Function(String newStatus, String adminReply) onSave;

  const FeedbackDetailsDialog({
    super.key,
    required this.feedback,
    required this.onSave,
  });

  @override
  State<FeedbackDetailsDialog> createState() => _FeedbackDetailsDialogState();
}

class _FeedbackDetailsDialogState extends State<FeedbackDetailsDialog> {

  // controls the admin reply text field
  final TextEditingController _replyController = TextEditingController();

  // currently selected status in the dropdown
  // starts as the current status of the feedback
  String? _selectedStatus;

  // list of status options in the dropdown
  final List<String> _statusOptions = [
    'Visible',
    'Flagged',
    'Hidden',
  ];

  // ================================================
  // INIT STATE — set initial values from feedback data
  // ================================================
  @override
  void initState() {
    super.initState();

    // set dropdown to current status
    _selectedStatus = widget.feedback['status'];

    // set reply box to existing reply if there is one
    // if no reply yet just leave it empty
    _replyController.text = widget.feedback['adminReply'] ?? '';
  }

  // ================================================
  // DISPOSE — clean up controller
  // ================================================
  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  // ================================================
  // GET BADGE COLORS
  // returns colors based on status string
  // ================================================
  Map<String, Color> _getBadgeColors(String status) {

    if (status == 'Flagged') {
      return {
        'bg': const Color(0xFFFEE2E2),
        'text': const Color(0xFFDC2626),
        'border': const Color(0xFFFCA5A5),
      };
    }

    if (status == 'Hidden') {
      return {
        'bg': const Color(0xFFF3F4F6),
        'text': const Color(0xFF6B7280),
        'border': const Color(0xFFD1D5DB),
      };
    }

    // default — Visible
    return {
      'bg': const Color(0xFFEFF6FF),
      'text': const Color(0xFF2563EB),
      'border': const Color(0xFFBFDBFE),
    };
  }

  // ================================================
  // HANDLE SAVE
  // shows confirm dialog before saving
  // ================================================
  Future<void> _handleSave() async {

  String currentStatus = widget.feedback['status'];
  String existingReply = widget.feedback['adminReply'] ?? '';
  String newReply = _replyController.text.trim();
  bool statusChanged = _selectedStatus != currentStatus;

  // ------------------------------------------------
  // STEP 1 — confirm if status changed
  // only ask if the status actually changed
  // ------------------------------------------------
  if (statusChanged == true) {

    // build title and message based on new status
    String title = '';
    String message = '';
    Color confirmColor = const Color(0xFF2563EB);

    if (_selectedStatus == 'Flagged') {
      title = 'Flag this feedback?';
      message = 'This will mark the comment as flagged '
          'and remove it from public view.';
      confirmColor = const Color(0xFFDC2626); // red
    }

    if (_selectedStatus == 'Hidden') {
      title = 'Hide this feedback?';
      message = 'This feedback will be hidden from '
          'customers and will not appear publicly.';
      confirmColor = const Color(0xFF6B7280); // gray
    }

    if (_selectedStatus == 'Visible') {
      title = 'Make this feedback visible?';
      message = 'This feedback will be shown publicly '
          'to all customers.';
      confirmColor = const Color(0xFF16A34A); // green
    }

    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: title,
      message: message,
      confirmLabel: 'Confirm',
      confirmColor: confirmColor,
    );

    // user cancelled — stop here
    if (confirmed != true) {
      return;
    }
  }

  // ------------------------------------------------
  // STEP 2 — confirm if overwriting an existing reply
  // only ask if there was already a reply saved
  // and the admin typed something different
  // ------------------------------------------------
  bool replyChanged = newReply != existingReply;
  bool hadExistingReply = existingReply.isNotEmpty;

  if (replyChanged == true && hadExistingReply == true) {

    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Overwrite existing reply?',
      message: 'You already have a saved reply. '
          'This will replace it with your new message.',
      confirmLabel: 'Overwrite',
      confirmColor: const Color(0xFF2563EB),
    );

    // user cancelled — stop here
    if (confirmed != true) {
      return;
    }
  }

  // ------------------------------------------------
  // STEP 3 — all confirmed, save everything
  // ------------------------------------------------
  widget.onSave(
    _selectedStatus ?? currentStatus,
    newReply,
  );

  if (mounted) {
    Navigator.pop(context);
  }
}

  // ================================================
  // BUILD STAR RATING
  // shows filled and empty stars
  // ================================================
  Widget _buildStarRating(int rating) {

    int totalStars = 5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalStars, (int index) {

        if (index < rating) {
          return const Icon(
            Icons.star,
            size: 18,
            color: Color(0xFFF59E0B),
          );
        } else {
          return const Icon(
            Icons.star_border,
            size: 18,
            color: Color(0xFFD1D5DB),
          );
        }
      }),
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {

    // get screen size for dialog sizing
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    // get badge colors for current status
    Map<String, Color> badgeColors =
        _getBadgeColors(widget.feedback['status']);

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: screenWidth < 700 ? screenWidth * 0.95 : 500,
        height: screenHeight * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),

        // same 3-part structure as other dialogs:
        // fixed header + scrollable content + fixed footer
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ================================================
            // PART 1 — FIXED HEADER
            // ================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // title
                  const Text(
                    'Feedback Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // subtitle
                  const Text(
                    'View comment and manage moderation',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ---- CUSTOMER ROW ----
                  // avatar + name + date + status badge
                  Row(
                    children: [

                      // gray circle avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE5E7EB),
                        child: Text(

                          // first letter of customer name
                          widget.feedback['customerName']
                              .toString()
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

                      // name and date stacked
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // customer name
                            Text(
                              widget.feedback['customerName'],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),

                            const SizedBox(height: 2),

                            // date posted
                            Text(
                              widget.feedback['datePosted'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // status badge on the right
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColors['bg'],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: badgeColors['border']!,
                          ),
                        ),
                        child: Text(
                          widget.feedback['status'],
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

                  // divider under header
                  const Divider(color: Color(0xFFE5E7EB), height: 1),
                ],
              ),
            ),

            // ================================================
            // PART 2 — SCROLLABLE CONTENT
            // ================================================
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ---- PRODUCT NAME ----
                    const Text(
                      'Product Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      widget.feedback['productReviewed'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ---- RATING ----
                    const Text(
                      'Rating',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // star rating widget
                    _buildStarRating(widget.feedback['rating']),

                    const SizedBox(height: 16),

                    // ---- FULL FEEDBACK ----
                    const Text(
                      'Full Feedback',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // read-only box showing the comment
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        widget.feedback['comment'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ---- STATUS DROPDOWN ----
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // dropdown to change the status
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      hint: const Text(
                        'Select Status',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF374151),
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFD1D5DB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFD1D5DB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),

                      // build each dropdown option
                      items: _statusOptions.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),

                      // update selected status when user picks one
                      onChanged: (String? value) {
                        setState(() {
                          _selectedStatus = value;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // ---- ADMIN REPLY ----
                    const Text(
                      'Admin Reply',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // text box for admin to type a reply
                    TextField(
                      controller: _replyController,

                      // allow multiple lines
                      maxLines: 4,

                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Write a reply...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFD1D5DB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFD1D5DB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ================================================
            // PART 3 — FIXED FOOTER
            // Cancel + Save Reply buttons
            // ================================================
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

                  // Cancel button — just closes dialog
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
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

                  // Save Reply button — triggers _handleSave
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
                      'Save Reply',
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