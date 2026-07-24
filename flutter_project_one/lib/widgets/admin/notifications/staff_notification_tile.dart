import 'package:flutter/material.dart';
import '../../../models/notification_model.dart';

/// Single notification row for staff (Admin/Super Admin) screens.
/// Unlike the customer tiles (order/promotion, two separate widgets),
/// staff notifications share one look — differentiated by icon/color.
class StaffNotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const StaffNotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  IconData get _icon {
    switch (notification.type) {
      case NotificationType.order:
        return Icons.receipt_long_outlined;
      case NotificationType.lowStock:
        return Icons.warning_amber_outlined;
      case NotificationType.outOfStock:
        return Icons.remove_shopping_cart_outlined;
      case NotificationType.newFeedback:
        return Icons.rate_review_outlined;
      case NotificationType.newMessage:
        return Icons.chat_bubble_outline;
      case NotificationType.orderCancellation:
        return Icons.cancel_outlined;
      case NotificationType.adminActivity:
        return Icons.admin_panel_settings_outlined;
      case NotificationType.salesAlert:
        return Icons.trending_up_outlined;
      case NotificationType.promotion:
        return Icons.local_offer_outlined;
      case NotificationType.adminReply:
        return Icons.chat_bubble_outline;
    }
  }
  
  Color get _iconColor {
    switch (notification.type) {
      case NotificationType.outOfStock:
      case NotificationType.orderCancellation:
        return const Color(0xFFDC2626);
      case NotificationType.lowStock:
        return const Color(0xFFD97706);
      case NotificationType.salesAlert:
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF2563EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isUnread = notification.isUnread;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread ? const Color(0xFFF8FAFF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isUnread ? const Color(0xFFDCE7FF) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(_icon, size: 18, color: _iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 8, top: 4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.timeAgo,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
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