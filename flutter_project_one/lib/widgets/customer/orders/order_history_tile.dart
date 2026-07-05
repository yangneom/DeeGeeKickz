import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/order.dart';
import '../../../services/customer/payment/payment_service.dart';
import '../../../services/customer/sms/sms_service.dart';
import '../../common/dialog/cancel_reason_dialog.dart';

// ================================================
// ORDER HISTORY TILE
//
// FIXES:
//   1. "Track Shipment" only shows when order is
//      Shipped+ AND a trackingUrl exists.
//      For Shipped — opens Lalamove URL in browser.
//      For other statuses — opens in-app tracking.
//   2. Receipt button shows when receiptUrl exists.
//   3. Cancel only shows when status is Pending.
// ================================================

class OrderHistoryTile extends StatelessWidget {
  final Order       order;
  final VoidCallback onTrack;  // opens in-app OrderTrackingScreen

  const OrderHistoryTile({
    super.key,
    required this.order,
    required this.onTrack,
  });

  Color get _statusColor {
  switch (order.orderStatus.toLowerCase()) {
    case 'completed':
    case 'delivered':   return const Color(0xFF1E8449);
    case 'shipped':     return const Color(0xFF1A5276);
    case 'preparing':   return const Color(0xFF7D6608);
    case 'confirmed':   return const Color(0xFF1D4ED8);
    case 'pending':     return const Color(0xFF92400E);
    case 'cancelled':   return const Color(0xFF991B1B);
    default:            return const Color(0xFF656464);
  }
}

  bool get _isShipped =>
      order.orderStatus.toLowerCase() == 'shipped' ||
      order.orderStatus.toLowerCase() == 'delivered';

  bool get _hasTrackingUrl =>
      order.trackingUrl != null && order.trackingUrl!.isNotEmpty;

  bool get _hasReceipt =>
      order.receiptUrl != null && order.receiptUrl!.isNotEmpty;

  bool get _isCancelled =>
      order.orderStatus.toLowerCase() == 'cancelled';

  Future<void> _openLalamove() async {
    if (!_hasTrackingUrl) return;
    final Uri uri = Uri.parse(order.trackingUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openReceipt() async {
    if (!_hasReceipt) return;
    final Uri uri = Uri.parse(order.receiptUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstItem = order.items.isNotEmpty ? order.items.first : null;

    return GestureDetector(
      onTap: onTrack,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
        color: _isCancelled
            ? const Color(0xFFFFF5F5)
            : Colors.white,
        border: Border.all(
          color: _isCancelled
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFCFC4C5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Product image placeholder
            Container(
              width:  72,
              height: 72,
              color: const Color(0xFFEEEEEE),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size:  32,
                color: Color(0xFF656464),
              ),
            ),

            const SizedBox(width: 14),

            // Order details
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
                            fontFamily:  'Inter',
                            fontSize:    15,
                            fontWeight:  FontWeight.w700,
                            color:       Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _isCancelled
                              ? const Color(0xFFFEE2E2)
                              : null,
                          border: Border.all(color: _statusColor),
                        ),
                        child: Text(
                          order.orderStatus.toUpperCase(),
                          style: TextStyle(
                            fontFamily:  'Inter',
                            fontSize:    10,
                            fontWeight:  FontWeight.w700,
                            letterSpacing: 0.4,
                            color:       _statusColor,
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
                      fontSize:   12,
                      color:      Color(0xFF656464),
                    ),
                  ),
                  Text(
                    order.dateTime,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize:   12,
                      color:      Color(0xFF656464),
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
                          fontSize:   12,
                          color:      Color(0xFF656464),
                        ),
                      ),
                      Text(
                        '₱${order.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize:   14,
                          fontWeight: FontWeight.w700,
                          color:      Colors.black,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Bottom action row ──────────────────────────
                  Row(
                    children: [

                      // Track Shipment / View Progress
                      // Shipped → open Lalamove URL
                      // Other statuses → open in-app tracking
                      if (!_isCancelled)
                        GestureDetector(
                          onTap: _isShipped && _hasTrackingUrl
                              ? _openLalamove
                              : onTrack,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isShipped && _hasTrackingUrl
                                    ? Icons.open_in_new
                                    : Icons.local_shipping_outlined,
                                size:  14,
                                color: Colors.black,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isShipped && _hasTrackingUrl
                                    ? 'Track on Lalamove'
                                    : 'Track Shipment',
                                style: const TextStyle(
                                  fontFamily:  'Inter',
                                  fontSize:    12,
                                  fontWeight:  FontWeight.w600,
                                  decoration:  TextDecoration.underline,
                                  color:       Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Receipt link — shown when payment approved
                      if (_hasReceipt) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _openReceipt,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_outlined,
                                size:  14,
                                color: Color(0xFF2563EB),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'View Receipt',
                                style: TextStyle(
                                  fontFamily:  'Inter',
                                  fontSize:    12,
                                  fontWeight:  FontWeight.w600,
                                  decoration:  TextDecoration.underline,
                                  color:       Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Cancel button — Pending only
                      if (order.orderStatus.toLowerCase() == 'pending')
                        GestureDetector(
                          onTap: () {
                            showCancelReasonDialog(
                              context:      context,
                              title:        'Cancel Order',
                              subtitle:
                                  'Select a reason to cancel your order',
                              confirmLabel: 'Cancel Order',
                              confirmColor: const Color(0xFFEF4444),
                              onConfirm: (String reason) async {
                              await PaymentService().cancelOrder(
                                orderId:     int.parse(order.orderId),
                                reason:      reason,
                                cancelledBy: 'customer',
                              );

                              if (order.contact.isNotEmpty) {
                                await SmsService().sendOrderCancelled(
                                  phone:   order.contact,
                                  orderId: order.orderId,
                                  reason:  reason,
                                );
                              }

                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical:   8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFFEF4444)),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize:   12,
                                fontWeight: FontWeight.w600,
                                color:      Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
          ), // closes GestureDetector

    );
  }
}