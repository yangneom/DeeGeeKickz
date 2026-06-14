import 'package:flutter/material.dart';
import '../../../models/order.dart';

/// "Order History" card — shows recent [Order] entries for the logged-in customer.
/// Each row has a product placeholder image, name, order ID, date, status, and
/// a "Track Shipment" link.
class ProfileOrdersSection extends StatelessWidget {
  final List<Order> orders;

  const ProfileOrdersSection({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final padding = isDesktop ? 48.0 : 16.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5), width: 1),
      ),
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ORDER HISTORY',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                  color: Colors.black,
                ),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: navigate to full order history screen
                },
                child: const Text(
                  'VIEW ALL',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 16),
            child: Divider(height: 1, color: Color(0xFFCFC4C5)),
          ),

          // ── Order list ──────────────────────────────────────────
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No orders yet.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF656464),
                  ),
                ),
              ),
            )
          else
            Column(
              children: List.generate(orders.length, (i) {
                final order = orders[i];
                final isLast = i == orders.length - 1;
                return _OrderTile(order: order, isLast: isLast);
              }),
            ),
        ],
      ),
    );
  }
}

// ─── Single order row ─────────────────────────────────────────────────────────

class _OrderTile extends StatelessWidget {
  final Order order;
  final bool isLast;

  const _OrderTile({required this.order, required this.isLast});

  /// Maps [order.orderStatus] → display color (monochrome with a hint).
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.black;
      case 'shipped':
        return const Color(0xFF4C4546);
      case 'preparing':
        return const Color(0xFF656464);
      case 'confirmed':
        return const Color(0xFF7E7576);
      case 'pending':
      default:
        return const Color(0xFF7E7576);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show only the first item name as the "product title" in the card
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    final productName = firstItem?.productName ?? 'Order';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Product image placeholder ─────────────────────
              Container(
                width: 80,
                height: 80,
                color: const Color(0xFFEEEEEE), // surface-container
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 32,
                  color: Color(0xFF656464),
                ),
              ),

              const SizedBox(width: 16), // gap-md

              // ── Order details ─────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: product name + status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          order.orderStatus.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: _statusColor(order.orderStatus),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Order ID + date
                    Text(
                      'Order #${order.orderId.toUpperCase()} | ${order.dateTime}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF656464),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Total amount
                    Text(
                      '₱${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Track Shipment link
                    GestureDetector(
                      onTap: () {
                        // TODO: navigate to order tracking screen
                      },
                      child: const Text(
                        'Track Shipment',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
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

        // Divider between rows (skip after last)
        if (!isLast)
          const Divider(height: 1, color: Color(0xFFCFC4C5)),
      ],
    );
  }
}