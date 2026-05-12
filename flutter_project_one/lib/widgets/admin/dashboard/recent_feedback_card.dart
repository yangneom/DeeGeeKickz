import 'package:flutter/material.dart';

// ================================================
// RECENT FEEDBACK CARD
//
// Shows a table of recent customer feedback
//
// ┌──────────────────────────────────────────┐
// │ Recent Feedback              View all →  │
// │                                          │
// │ Customer | Product | Rating | Status |Date│
// │ Angel    | Nike... | ★★★☆☆ |Flagged |May6│
// └──────────────────────────────────────────┘
// ================================================

// this is the data model for one feedback row
// think of it like a form template for feedback
class FeedbackItem {
  String customerName;
  String productName;
  int rating;          // 1 to 5
  String status;       // 'Flagged' or 'Visible'
  String date;

  FeedbackItem({
    required this.customerName,
    required this.productName,
    required this.rating,
    required this.status,
    required this.date,
  });
}

class RecentFeedbackCard extends StatelessWidget {

  // list of feedback items to show
  final List<FeedbackItem> feedbackItems;

  // what happens when user clicks view all
  final VoidCallback onViewAll;

  const RecentFeedbackCard({
    super.key,
    required this.feedbackItems,
    required this.onViewAll,
  });

  // ================================================
  // BUILD STAR RATING
  // shows filled and empty stars
  // example: ★★★☆☆ for rating 3
  // ================================================
  Widget _buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (int index) {

        // if index is less than rating show filled star
        // otherwise show empty star
        if (index < rating) {
          return const Icon(
            Icons.star,
            size: 12,
            color: Color(0xFFF59E0B),
          );
        } else {
          return const Icon(
            Icons.star_border,
            size: 12,
            color: Color(0xFFD1D5DB),
          );
        }
      }),
    );
  }

  // ================================================
  // BUILD STATUS BADGE
  // Flagged = red, Visible = green
  // ================================================
  Widget _buildStatusBadge(String status) {

    // pick colors based on status
    Color backgroundColor = Colors.grey.shade100;
    Color textColor = Colors.grey;

    if (status == 'Flagged') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFDC2626);
    }

    if (status == 'Visible') {
      backgroundColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF16A34A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  // ================================================
  // BUILD TABLE HEADER
  // ================================================
  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Customer Name',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Product',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Rating',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Status',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Date',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================
  // BUILD ONE FEEDBACK ROW
  // ================================================
  Widget _buildFeedbackRow(FeedbackItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [

          // customer name
          Expanded(
            flex: 2,
            child: Text(
              item.customerName,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF111827),
              ),
            ),
          ),

          // product name
          Expanded(
            flex: 2,
            child: Text(
              item.productName,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF111827),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // star rating
          Expanded(
            flex: 2,
            child: _buildStarRating(item.rating),
          ),

          // status badge
          Expanded(
            flex: 1,
            child: _buildStatusBadge(item.status),
          ),

          // date
          Expanded(
            flex: 1,
            child: Text(
              item.date,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── HEADER ROW ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              // title with icon
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recent Feedback',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),

              // view all link
              GestureDetector(
                onTap: onViewAll,
                child: Row(
                  children: const [
                    Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── DIVIDER ──
          Divider(
            color: Colors.grey.shade200,
            height: 1,
          ),

          const SizedBox(height: 8),

          // ── TABLE HEADER ──
          _buildTableHeader(),

          // ── DIVIDER ──
          Divider(
            color: Colors.grey.shade200,
            height: 1,
          ),

          // ── FEEDBACK ROWS ──
          for (int i = 0; i < feedbackItems.length; i = i + 1)
            Column(
              children: [
                _buildFeedbackRow(feedbackItems[i]),
                if (i < feedbackItems.length - 1)
                  Divider(
                    color: Colors.grey.shade100,
                    height: 1,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}