import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/notification_model.dart';
import '../../../providers/product/product_provider.dart';
import '../../../services/customer/review/review_service.dart';
import '../../../screens/customer/product_detail/product_detail.dart';

/// Notification card for [NotificationType.newFeedback] on the
/// customer side — fires when an admin replies to the customer's
/// own review. Fetches the review (to get its product), then the
/// product itself, before deep-linking into Product Detail scrolled
/// to the Reviews section.
class NotificationTileReviewReply extends ConsumerStatefulWidget {
  final AppNotification notification;
  final VoidCallback onMarkRead;

  const NotificationTileReviewReply({
    super.key,
    required this.notification,
    required this.onMarkRead,
  });

  @override
  ConsumerState<NotificationTileReviewReply> createState() =>
      _NotificationTileReviewReplyState();
}

class _NotificationTileReviewReplyState
    extends ConsumerState<NotificationTileReviewReply> {
  bool _isLoading = false;

  Future<void> _goToReview() async {
        final String? feedbackId = widget.notification.referenceId;
    widget.onMarkRead();
    if (feedbackId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This notification is too old to link directly, check your reviews on the product page.'),
            backgroundColor: Colors.black,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final review = await ReviewService().fetchReviewById(int.parse(feedbackId));
      print('🔍 fetched review: $review, productId on review: ${review?.productId}');

      if (!mounted) return;
      if (review == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load this review. It may have been removed.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final products = await ref.read(productsProvider.future);
      final product = products.cast<dynamic>().firstWhere(
            (p) => p.productId == review.productId.toString(),
            orElse: () => null,
          );

      if (!mounted) return;
      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This product is no longer available.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: product,
            scrollToReviews: true,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _goToReview,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCFC4C5), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFEEEEEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rate_review_outlined, size: 22, color: Colors.black),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'REVIEW UPDATE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Color(0xFF656464),
                        ),
                      ),
                      Row(
                        children: [
                          if (widget.notification.isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                            ),
                          Text(
                            widget.notification.timeAgo,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF656464)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.notification.title,
                    style: const TextStyle(
                      fontFamily: 'Archivo Narrow',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.notification.body,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF656464), height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
                    child: _isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text(
                            'VIEW REVIEW',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              color: Colors.black,
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