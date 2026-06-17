import 'package:flutter/material.dart';
import '../../../models/notification_model.dart';
import '../../../models/order.dart';
import '../../../screens/customer/orders/order_tracking_screen.dart';

/// Notification card for [NotificationType.order].
/// Shows shipping icon, order title, body, and Track Shipment button.
class NotificationTileOrder extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onMarkRead;

  const NotificationTileOrder({
    super.key,
    required this.notification,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onMarkRead,
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
            // ── Icon ───────────────────────────────────────────
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                size: 22,
                color: Colors.black,
              ),
            ),

            const SizedBox(width: 16),

            // ── Content ─────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type label + time + unread dot
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ORDER UPDATE',
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
                          if (notification.isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            notification.timeAgo,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF656464),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontFamily: 'Archivo Narrow',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    notification.body,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF656464),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Track Shipment button
                  GestureDetector(
                    onTap: () {
                      // Find the matching order and navigate to tracking
                      final order = fakeOrders.firstWhere(
                        (o) => o.orderId == notification.orderId,
                        orElse: () => fakeOrders.last,
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(order: order),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      child: const Text(
                        'TRACK SHIPMENT',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: Colors.black,
                        ),
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