import 'package:flutter/material.dart';
import '../../../models/order.dart';

/// Shown on the Profile screen when the user has a non-delivered active order.
/// Displays order ID, status badge, a mini horizontal timeline, and
/// a "Track Shipment" button that navigates to OrderTrackingScreen.
class ProfileActiveOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTrack;

  const ProfileActiveOrderCard({
    super.key,
    required this.order,
    required this.onTrack,
  });

  // Steps in order — matches tracking screen
  static const List<String> _steps = [
    'Pending',
    'Confirmed',
    'Preparing',
    'Shipped',
    'Delivered',
  ];

  int get _currentStep {
    final s = order.orderStatus.toLowerCase();
    switch (s) {
      case 'confirmed':  return 1;
      case 'preparing':  return 2;
      case 'shipped':    return 3;
      case 'delivered':  return 4;
      default:           return 0; // pending
    }
  }

  Color get _statusColor {
    switch (order.orderStatus.toLowerCase()) {
      case 'shipped':   return const Color(0xFF1A5276);
      case 'delivered': return const Color(0xFF1E8449);
      case 'preparing': return const Color(0xFF7D6608);
      default:          return const Color(0xFF656464);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final padding   = isDesktop ? 48.0 : 16.0;
    final firstItem = order.items.isNotEmpty ? order.items.first : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1.5),
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
                'ACTIVE ORDER',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                  color: Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                color: Colors.black,
                child: Text(
                  order.orderStatus.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 16),
            child: Divider(height: 1, color: Color(0xFFCFC4C5)),
          ),

          // ── Order meta ──────────────────────────────────────────
          Row(
            children: [
              // Product placeholder
              Container(
                width: 56,
                height: 56,
                color: const Color(0xFFEEEEEE),
                child: const Icon(Icons.shopping_bag_outlined,
                    size: 28, color: Color(0xFF656464)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstItem?.productName ?? 'Order',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order #${order.orderId.toUpperCase()}  ·  ${order.dateTime}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF656464),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₱${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Mini horizontal timeline ────────────────────────────
          _MiniTimeline(currentStep: _currentStep, steps: _steps),

          const SizedBox(height: 20),

          // ── Track button ────────────────────────────────────────
          GestureDetector(
            onTap: onTrack,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: Colors.black,
              alignment: Alignment.center,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'TRACK SHIPMENT',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mini timeline widget ─────────────────────────────────────────────────────

class _MiniTimeline extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const _MiniTimeline({
    required this.currentStep,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        // Even indices = step dots, odd indices = connector lines
        if (i.isOdd) {
          final stepIndex = (i - 1) ~/ 2;
          final isDone = stepIndex < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: isDone ? Colors.black : const Color(0xFFCFC4C5),
            ),
          );
        }

        final stepIndex = i ~/ 2;
        final isDone    = stepIndex <= currentStep;
        final isCurrent = stepIndex == currentStep;

        return Column(
          children: [
            // Dot
            Container(
              width: isCurrent ? 14 : 10,
              height: isCurrent ? 14 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? Colors.black : Colors.white,
                border: Border.all(
                  color: isDone ? Colors.black : const Color(0xFFCFC4C5),
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Label
            Text(
              steps[stepIndex].toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                color: isDone ? Colors.black : const Color(0xFF656464),
                letterSpacing: 0.3,
              ),
            ),
          ],
        );
      }),
    );
  }
}