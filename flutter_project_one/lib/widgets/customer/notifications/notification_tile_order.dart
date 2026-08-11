// lib/widgets/customer/notifications/notification_tile_order.dart

import 'package:flutter/material.dart';
import '../../../models/notification_model.dart';
import '../../../models/order.dart';
import '../../../screens/customer/orders/order_tracking_screen.dart';
import '../../../services/customer/History/order_history_service.dart';

/// Notification card for [NotificationType.order].
///
/// FIX: previously expected an `order` parameter that was NEVER
/// actually passed in from notifications_screen.dart, so the
/// "TRACK SHIPMENT" button never rendered for any order notification.
/// Now fetches the order by ID (carried on the notification itself)
/// only when tapped, instead of requiring it upfront.
class NotificationTileOrder extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onMarkRead;

  const NotificationTileOrder({
    super.key,
    required this.notification,
    required this.onMarkRead,
  });

  @override
  State<NotificationTileOrder> createState() => _NotificationTileOrderState();
}

class _NotificationTileOrderState extends State<NotificationTileOrder> {
  bool _isLoadingOrder = false;

  Future<void> _goToOrder() async {
    final String? orderId = widget.notification.orderId;
    if (orderId == null) return;

    widget.onMarkRead();
    setState(() => _isLoadingOrder = true);

    final Order? order =
        await OrderHistoryService().fetchOrderById(orderId);

    if (!mounted) return;
    setState(() => _isLoadingOrder = false);

    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load this order. It may have been removed.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasOrderId = widget.notification.orderId != null;

    return GestureDetector(
      onTap: hasOrderId ? _goToOrder : widget.onMarkRead,
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
              child: const Icon(
                Icons.local_shipping_outlined,
                size: 22,
                color: Colors.black,
              ),
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
                          if (widget.notification.isUnread)
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
                            widget.notification.timeAgo,
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
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF656464),
                      height: 1.5,
                    ),
                  ),

                  if (hasOrderId) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _goToOrder,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: _isLoadingOrder
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}