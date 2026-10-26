import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/order.dart';
import '../../../services/customer/payment/payment_service.dart';
import '../../common/dialog/app_toast.dart';
import '../../common/dialog/cancel_reason_dialog.dart';
import '../checkout/checkout_order_summary.dart' show formatPeso;
import 'order_status_style.dart';

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

  /// Called after a cancellation succeeded, so the list can reload and show the
  /// real status. Optional: without it the tile still works, the list just
  /// stays as it was until it reloads.
  final VoidCallback? onCancelled;

  const OrderHistoryTile({
    super.key,
    required this.order,
    required this.onTrack,
    this.onCancelled,
  });

  // Same colours as the order details page: both read order_status_style.dart.
  Color get _statusColor => orderStatusColor(order.orderStatus);

  bool get _isShipped =>
      order.orderStatus.toLowerCase() == 'shipped' ||
      order.orderStatus.toLowerCase() == 'delivered';

  bool get _hasTrackingUrl =>
      order.trackingUrl != null && order.trackingUrl!.isNotEmpty;

  bool get _hasReceipt =>
      order.receiptUrl != null && order.receiptUrl!.isNotEmpty;

  bool get _isCancelled =>
      order.orderStatus.toLowerCase() == 'cancelled';

  // Opens a link only if it is a real http(s) address, and tells the customer
  // when it cannot be opened. The old code used Uri.parse (which throws on a bad
  // link) and ignored a failed launch silently.
  Future<void> _openWebLink(
      BuildContext context, String url, String what) async {
    final Uri? uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty) {
      AppToast.error(
        context,
        'The $what link for this order is not valid. Please contact support.',
        title: 'Cannot open $what',
      );
      return;
    }

    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      AppToast.error(
        context,
        'We could not open the $what page. Please try again.',
        title: 'Cannot open $what',
      );
    }
  }

  Future<void> _openLalamove(BuildContext context) async {
    if (!_hasTrackingUrl) return;
    await _openWebLink(context, order.trackingUrl!, 'tracking');
  }

  Future<void> _openReceipt(BuildContext context) async {
    if (!_hasReceipt) return;
    await _openWebLink(context, order.receiptUrl!, 'receipt');
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
                        formatPeso(order.totalAmount),
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
                  // The links WRAP onto a second line on narrow phones. A plain
                  // Row overflowed when Track, Receipt and Cancel all showed.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [

                      // Track Shipment / View Progress
                      // Shipped → open Lalamove URL
                      // Other statuses → open in-app tracking
                      if (!_isCancelled)
                        GestureDetector(
                          onTap: _isShipped && _hasTrackingUrl
                              ? () => _openLalamove(context)
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
                        GestureDetector(
                          onTap: () => _openReceipt(context),
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

                          ],
                        ),
                      ),

                      // Cancel button — Pending only
                      if (order.orderStatus.toLowerCase() == 'pending')
                        GestureDetector(
                          onTap: () {
                            showCancelReasonDialog(
                              context:      context,
                              style:        CancelDialogStyle.customer,
                              title:        'Cancel Order',
                              subtitle:
                                  'Tell us why you are cancelling. This cannot be undone.',
                              confirmLabel: 'Cancel Order',
                              dismissLabel: 'Keep Order',
                              confirmColor: const Color(0xFFBA1A1A),
                              reasons: const [
                                'Changed my mind',
                                'Ordered by mistake',
                                'Found a better price elsewhere',
                                'Delivery is taking too long',
                                'Item no longer needed',
                              ],
                              onConfirm: (String reason) async {
                              await PaymentService().cancelOrder(
                                orderId:     int.parse(order.orderId),
                                reason:      reason,
                                cancelledBy: 'customer',
                              );

                              // AUDIT FIX: customer-initiated cancellations
                              // should notify Admin only, never send the
                              // customer an SMS — sendOrderCancelled()
                              // stays in SmsService for a genuine future
                              // admin/system-initiated flow, just no
                              // longer called from this button.

                              // The dialog closes ITSELF after this returns.
                              // The old code also called Navigator.pop() here;
                              // together with the dialog's own pop that could
                              // close the Order History page under the dialog.
                              //
                              // This point is reached when cancelOrder returned
                              // WITHOUT throwing. cancelOrder must throw when
                              // the backend refuses (so the dialog shows the
                              // error); if it ever returns quietly on failure,
                              // this confirmation would be wrong.
                              if (context.mounted) {
                                AppToast.success(
                                  context,
                                  'Order #${order.orderId} was cancelled. If you '
                                  'already paid, our team will arrange your refund.',
                                  title: 'Order cancelled',
                                );
                              }
                              onCancelled?.call();
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical:   12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFFBA1A1A)),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize:   12,
                                fontWeight: FontWeight.w600,
                                color:      Color(0xFFBA1A1A),
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