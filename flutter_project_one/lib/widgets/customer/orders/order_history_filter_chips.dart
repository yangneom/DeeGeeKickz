import 'package:flutter/material.dart';
import '../../../models/order.dart';

/// Single order row used in [OrderHistoryScreen].
/// Tapping "Track Shipment" calls [onTrack].
class OrderHistoryTile extends StatelessWidget {
  final Order order;
  final VoidCallback onTrack;

  const OrderHistoryTile({
    super.key,
    required this.order,
    required this.onTrack,
  });

  Color get _statusColor {
    switch (order.orderStatus.toLowerCase()) {
      case 'delivered': return const Color(0xFF1E8449);
      case 'shipped':   return const Color(0xFF1A5276);
      case 'preparing': return const Color(0xFF7D6608);
      case 'confirmed': return const Color(0xFF4C4546);
      default:          return const Color(0xFF656464);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstItem = order.items.isNotEmpty ? order.items.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product image placeholder ───────────────────────
            Container(
              width: 72,
              height: 72,
              color: const Color(0xFFEEEEEE),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 32,
                color: Color(0xFF656464),
              ),
            ),

            const SizedBox(width: 14),

            // ── Order details ───────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name + status badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          firstItem?.productName ?? 'Order',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: _statusColor),
                        ),
                        child: Text(
                          order.orderStatus.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: _statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Order ID + date
                  Text(
                    'Order #${order.orderId.toUpperCase()}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF656464),
                    ),
                  ),
                  Text(
                    order.dateTime,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF656464),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Payment method + total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.paymentMethod,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF656464),
                        ),
                      ),
                      Text(
                        '₱${order.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Track Shipment link
                  GestureDetector(
                    onTap: onTrack,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.local_shipping_outlined,
                            size: 14, color: Colors.black),
                        SizedBox(width: 4),
                        Text(
                          'Track Shipment',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            color: Colors.black,
                          ),
                        ),
                      ],
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