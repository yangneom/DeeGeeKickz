import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/order.dart';
import '../../../services/admin/order/order_management_service.dart';
import '../../../services/customer/payment/payment_service.dart';
import '../../../services/customer/receipt/receipt_pdf_service.dart';
import '../../../services/customer/sms/sms_service.dart';
import '../../common/dialog/cancel_reason_dialog.dart';
import '../../common/dialog/confirm_dialog.dart';
import '../../../services/customer/delivery/lalamove_service.dart';
void showOrderDetailsDialog(
  BuildContext context,
  Order order,
  Function(String newStatus, String newPaymentStatus) onStatusUpdated,
) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return OrderDetailsDialog(
        order: order,
        onStatusUpdated: onStatusUpdated,
      );
    },
  );
}

class OrderDetailsDialog extends StatefulWidget {
  final Order order;
  final Function(String newStatus, String newPaymentStatus) onStatusUpdated;

  const OrderDetailsDialog({
    super.key,
    required this.order,
    required this.onStatusUpdated,
  });

  @override
  State<OrderDetailsDialog> createState() => _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends State<OrderDetailsDialog> {

  final OrderManagementService _orderService          = OrderManagementService();
  final TextEditingController  _adminNoteController   = TextEditingController();
  final TextEditingController  _lalamoveLinkController = TextEditingController();

  late String _currentStatus;
  String?              _paymentStatus;   // tracked so action buttons can react
  bool                 _isSavingLink  = false;

  // NEW — true while create-delivery-order is running (Mark Shipped tap)
  bool                 _isBookingDelivery = false;

  Map<String, dynamic>? _cachedPayment;
  bool                 _paymentLoaded = false;

  // Live-updated copies of order fields that can change mid-dialog
  // (i.e. after Mark Shipped books Lalamove). Everything in the UI
  // should read these, NOT widget.order.trackingUrl / .hasCoordinates
  // directly — widget.order is frozen at the moment the dialog opened.
  late String? _trackingUrl;
  late double? _lat;
  late double? _lng;
  bool get _hasCoordinates => _lat != null && _lng != null;

  final List<String> _steps = [
    'Pending',
    'Confirmed',
    'Preparing',
    'Shipped',
    'Completed',
  ];

  bool get _isReadOnly =>
      _currentStatus == 'Cancelled' || _currentStatus == 'Completed';

  // Manual tracking link only makes sense once an order has actually
  // reached the shipping stage — pasting a link on a still-Pending or
  // Confirmed order (before payment is even approved) would leave a
  // dangling tracking_url on an order that hasn't started shipping.
  bool get _canManageDelivery =>
      _currentStatus == 'Preparing' || _currentStatus == 'Shipped';

  bool get _isCod => widget.order.paymentMethod.toLowerCase() == 'cod';

 @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.orderStatus;
    _trackingUrl   = widget.order.trackingUrl;
    _lat           = widget.order.lat;
    _lng           = widget.order.lng;
    if (_trackingUrl != null) {
      _lalamoveLinkController.text = _trackingUrl!;
    }
  }

  @override
  void dispose() {
    _adminNoteController.dispose();
    _lalamoveLinkController.dispose();
    super.dispose();
  }

  // ================================================
  // STEP INDEX
  // ================================================
  int _getStepIndex(String status) {
    if (status == 'Cancelled') return 0;
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i] == status) return i;
    }
    return 0;
  }

  // ================================================
  // PROGRESS STEPPER
  // ================================================
  Widget _buildProgressStepper() {
    final int  currentIndex = _getStepIndex(_currentStatus);
    final bool isCancelled  = _currentStatus == 'Cancelled';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCancelled
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Order Progress',
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                  color: isCancelled
                      ? const Color(0xFF991B1B)
                      : const Color(0xFF374151),
                ),
              ),
              if (isCancelled) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: const Text(
                    'CANCELLED',
                    style: TextStyle(
                      fontSize:   10,
                      fontWeight: FontWeight.w700,
                      color:      Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(_steps.length, (int index) {
              final bool isDone    = !isCancelled && index < currentIndex;
              final bool isCurrent = !isCancelled && index == currentIndex;

              return Expanded(
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width:  28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCancelled
                                ? const Color(0xFFE5E7EB)
                                : isDone || isCurrent
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFE5E7EB),
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize:   11,
                                      fontWeight: FontWeight.w600,
                                      color: isCurrent && !isCancelled
                                          ? Colors.white
                                          : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _steps[index],
                          style: TextStyle(
                            fontSize: 10,
                            color: isCancelled
                                ? const Color(0xFF9CA3AF)
                                : isDone || isCurrent
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF9CA3AF),
                            fontWeight: isCurrent && !isCancelled
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    if (index < _steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 22),
                          color: isDone && !isCancelled
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ================================================
  // CUSTOMER INFO
  // ================================================
  Widget _buildCustomerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Information',
            style: TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w600,
              color:      Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Name', widget.order.customerName),
                    const SizedBox(height: 8),
                    _infoRow('Contact', widget.order.contact.isNotEmpty
                        ? widget.order.contact
                        : '—'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Landmark', widget.order.landmark.isNotEmpty
                        ? widget.order.landmark
                        : '—'),
                    const SizedBox(height: 8),
                    _infoRow('Address', widget.order.address.isNotEmpty
                        ? widget.order.address
                        : '—'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
      ],
    );
  }

// ================================================
  // ITEMS + SUMMARY — merged into one visual block
  //
  // Previously two separate boxes (Item Purchase table, then a
  // second Order Summary box below it with its own header/border).
  // Now a single container: items table on top, totals directly
  // below with no visual break — reads as one connected breakdown
  // instead of two disconnected cards.
  // ================================================
  Widget _buildItemsAndSummary() {
    final List<OrderItem> items = widget.order.items;

    final double displaySubtotal = widget.order.subtotal > 0
        ? widget.order.subtotal
        : widget.order.items.fold<double>(0, (sum, item) => sum + item.total);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Section title ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              'Order Details',
              style: const TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      Color(0xFF374151),
              ),
            ),
          ),

          // ── Items header row ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(
                top:    BorderSide(color: Color(0xFFE5E7EB)),
                bottom: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Product Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Text('Brand',        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                Expanded(flex: 1, child: Text('Size',         style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                Expanded(flex: 1, child: Text('Qty',          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Text('Price',        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Text('Total',        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
              ],
            ),
          ),

          // ── Item rows ──
          for (final OrderItem item in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(item.productName,                    style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                  Expanded(flex: 2, child: Text(item.brand,                          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                  Expanded(flex: 1, child: Text(item.size.toString(),                style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                  Expanded(flex: 1, child: Text(item.quantity.toString(),            style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                  Expanded(flex: 2, child: Text('₱${item.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                  Expanded(flex: 2, child: Text('₱${item.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                ],
              ),
            ),

          // ── Totals — directly below, same container, no gap ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow('Subtotal', '₱${displaySubtotal.toStringAsFixed(0)}'),
                if (widget.order.discountAmount > 0) ...[
                  const SizedBox(height: 8),
                  _summaryRow(
                    'Discount',
                    '-₱${widget.order.discountAmount.toStringAsFixed(0)}',
                    valueColor: const Color(0xFF16A34A),
                  ),
                ],
                const SizedBox(height: 8),
                _summaryRow(
                  'Shipping',
                  widget.order.shipping > 0
                      ? '₱${widget.order.shipping.toStringAsFixed(0)}'
                      : 'FREE',
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      Color(0xFF111827),
                      ),
                    ),
                    Text(
                      '₱${widget.order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.w700,
                        color:      Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Text(
          value,
          style: TextStyle(
            fontSize:   13,
            fontWeight: FontWeight.w600,
            color:      valueColor ?? const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  // ================================================
  // PAYMENT SECTION
  // ================================================
  Widget _buildPaymentSection() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _paymentLoaded
          ? Future.value(_cachedPayment)
          : PaymentService().getPaymentForOrder(
              int.parse(widget.order.orderId),
            ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child:   CircularProgressIndicator(),
          );
        }

        final Map<String, dynamic>? payment = snapshot.data;

        if (!_paymentLoaded) {
          _cachedPayment  = payment;
          _paymentLoaded  = true;
        }

        if (payment == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'No payment record found.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          );
        }

        final String  paymentStatus = payment['payment_status'] ?? 'Pending';
        final String? receiptUrl    = payment['receipt_url']    as String?;
        final String  method        = payment['payment_method'] ?? '—';

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _paymentStatus != paymentStatus) {
            setState(() => _paymentStatus = paymentStatus);
          }
        });

        final bool isRejected = paymentStatus == 'Rejected';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isRejected
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Payment',
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color:      Color(0xFF374151),
                    ),
                  ),
                  _paymentStatusBadge(paymentStatus),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Method: $method',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              if (widget.order.cancelReason != null &&
                  widget.order.cancelReason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: Color(0xFF991B1B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Cancel Reason: ${widget.order.cancelReason}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF991B1B),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final Uri uri = Uri.parse(receiptUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined,
                          size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 6),
                      Text(
                        'View PDF Receipt',
                        style: TextStyle(
                          fontSize:   12,
                          color:      Color(0xFF2563EB),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _paymentStatusBadge(String status) {
    Color bg     = Colors.grey.shade100;
    Color text   = Colors.grey;
    Color border = Colors.grey.shade300;

    if (status == 'Paid') {
      bg = const Color(0xFFD1FAE5); text = const Color(0xFF065F46); border = const Color(0xFF6EE7B7);
    }
    if (status == 'Verified') {
      bg = const Color(0xFFDBEAFE); text = const Color(0xFF1D4ED8); border = const Color(0xFF93C5FD);
    }
    if (status == 'Pending') {
      bg = const Color(0xFFFEF3C7); text = const Color(0xFF92400E); border = const Color(0xFFFCD34D);
    }
    if (status == 'Rejected') {
      bg = const Color(0xFFFEE2E2); text = const Color(0xFF991B1B); border = const Color(0xFFFCA5A5);
    }
    if (status == 'Refunded') {
      bg = const Color(0xFFE0E7FF); text = const Color(0xFF3730A3); border = const Color(0xFFA5B4FC);
    }
    if (status == 'Refund Failed') {
      bg = const Color(0xFFFEE2E2); text = const Color(0xFF991B1B); border = const Color(0xFFFCA5A5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: border),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: text),
      ),
    );
  }

  // ================================================
  // LALAMOVE LINK + ADMIN NOTE
  //
  // UPDATE: the Lalamove link field is now a FALLBACK, not the
  // normal path. Normally "Mark Shipped" books Lalamove itself
  // (see _buildActionButtons) and this field just displays the
  // resulting link read-only-ish. It's only meant to be typed
  // into if automatic booking fails (e.g. missing coordinates)
  // and admin needs to paste a link obtained some other way.
  // ================================================
  Widget _buildAdminFields() {
    if (_isReadOnly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_trackingUrl != null && _trackingUrl!.isNotEmpty) ...[
            const Text(
              'Lalamove Tracking Link',
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final Uri uri = Uri.parse(_trackingUrl!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Text(
                _trackingUrl!,
                style: const TextStyle(
                  fontSize:   12,
                  color:      Color(0xFF2563EB),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Admin Note
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin Note',
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                  color:      Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _adminNoteController,
                maxLines:   4,
                decoration: InputDecoration(
                  hintText:  'e.g., Your order will be shipped tomorrow',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Lalamove link — now a fallback/manual-override field
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Lalamove Tracking Link',
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color:      Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (!_hasCoordinates)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'MANUAL — no coordinates',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                !_canManageDelivery
                    ? 'Available once this order reaches Preparing status — '
                      'not yet relevant while it\'s still $_currentStatus.'
                    : _hasCoordinates
                        ? 'Filled automatically when you tap "Mark Shipped" below. Only edit this if you need to override it.'
                        : 'This order has no map coordinates, so automatic booking isn\'t available — paste a Lalamove link here manually instead.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _lalamoveLinkController,
                enabled: _canManageDelivery,
                decoration: InputDecoration(
                  hintText:  'https://www.lalamove.com/track/...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_isSavingLink || !_canManageDelivery)
                      ? null
                      : () async {
                          final String link = _lalamoveLinkController.text.trim();
                          if (link.isEmpty) return;

                          final Uri? parsed = Uri.tryParse(link);
                          final bool looksValid = parsed != null &&
                              (parsed.scheme == 'http' || parsed.scheme == 'https') &&
                              parsed.host.contains('lalamove.com');
                          if (!looksValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'That doesn\'t look like a valid Lalamove tracking link '
                                  '(expected https://www.lalamove.com/track/...).',
                                ),
                                backgroundColor: Color(0xFFDC2626),
                              ),
                            );
                            return;
                          }

                          final bool? confirmed = await showConfirmDialog(
                            context:      context,
                            title:        'Save this tracking link?',
                            message:      'This saves the link for the customer to view, but does NOT '
                                          'change the order status or notify them automatically — '
                                          'you\'ll still need to mark the order Shipped/Completed yourself.',
                            confirmLabel: 'Save Link',
                            confirmColor: const Color(0xFF374151),
                          );
                          if (confirmed != true) return;

                          setState(() => _isSavingLink = true);
                          try {
                            await _orderService.saveTrackingUrl(
                              orderId:     int.parse(widget.order.orderId),
                              trackingUrl: link,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:         Text('Tracking link saved.'),
                                  backgroundColor: Color(0xFF16A34A),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:         Text('Failed to save: $e'),
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isSavingLink = false);
                          }
                        },
                  icon: _isSavingLink
                      ? const SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 14),
                  label: Text(
                    _isSavingLink ? 'Saving…' : 'Save Link Manually',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================================================
  // ACTION BUTTONS
  //
  // UPDATE: "Preparing → Shipped" now calls
  // _orderService.markAsShipped(), which books the real Lalamove
  // order automatically (fresh quote + order placement) and
  // saves the resulting tracking link + lalamove_order_id —
  // no manual link typing required. Falls back to the manual
  // link field only if the order has no coordinates or the
  // Lalamove call fails.
  // ================================================
  Widget _buildActionButtons() {
    if (_isReadOnly) return const SizedBox.shrink();

    final bool paidOrCod = _paymentStatus == 'Paid' || _isCod;

    return Wrap(
      spacing:    8,
      runSpacing: 8,
      alignment:  WrapAlignment.end,
      children: [

        // ── Reject + Approve (payment Pending only) ──────────────────
       if (_currentStatus == 'Pending') ...[

          OutlinedButton(
            onPressed: () {
              showCancelReasonDialog(
                context:      context,
                title:        'Reject Order',
                subtitle:     'Select a reason to reject this order',
                confirmLabel: 'Reject Order',
                confirmColor: const Color(0xFFEF4444),
                onConfirm: (String reason) async {
                  await PaymentService().rejectPayment(
                    orderId: int.parse(widget.order.orderId),
                    reason:  reason,
                  );
                  if (widget.order.contact.isNotEmpty) {
                    await SmsService().sendOrderRejected(
                      phone:   widget.order.contact,
                      orderId: widget.order.orderId,
                      reason:  reason,
                    );
                  }
                  if (mounted) {
                    setState(() {
                      _currentStatus = 'Cancelled';
                      _paymentStatus = 'Rejected';
                      _cachedPayment = {...?_cachedPayment, 'payment_status': 'Rejected'};
                    });
                    widget.onStatusUpdated('Cancelled', 'Rejected');
                  }
                },
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFDC2626)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Reject Order', style: TextStyle(fontSize: 13)),
          ),

          ElevatedButton(
            onPressed: () async {
              final bool? confirmed = await showConfirmDialog(
                context:      context,
                title:        'Approve this payment?',
                message:      'This will mark the payment as Paid, confirm the order, and generate a PDF receipt for the customer.',
                confirmLabel: 'Approve',
                confirmColor: const Color(0xFF16A34A),
              );
              if (confirmed != true) return;

              try {
                await PaymentService().approvePayment(
                  orderId: int.parse(widget.order.orderId),
                );
              } on InsufficientStockException catch (stockErr) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(stockErr.message),
                      backgroundColor: const Color(0xFFDC2626),
                      duration: const Duration(seconds: 6),
                    ),
                  );
                }
                return;
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to approve payment: $e'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                }
                return;
              }

              try {
                final Order confirmedOrder = Order(
                  orderId:       widget.order.orderId,
                  customerName:  widget.order.customerName,
                  contact:       widget.order.contact,
                  landmark:      widget.order.landmark,
                  address:       widget.order.address,
                  totalAmount:   widget.order.totalAmount,
                  paymentMethod: widget.order.paymentMethod,
                  paymentStatus: 'Paid',
                  orderStatus:   'Confirmed',
                  dateTime:      widget.order.dateTime,
                  items:         widget.order.items,
                  subtotal:        widget.order.subtotal,
                  shipping:        widget.order.shipping,
                  discountAmount:  widget.order.discountAmount,
                );
                await ReceiptPdfService().generateAndUpload(confirmedOrder);
              } catch (receiptErr) {
                print('Receipt generation failed: $receiptErr');
                // TEMPORARY — surfacing this visibly so we can see the
                // real error instead of it vanishing into the console.
                // Revert to silent once the root cause is fixed, since
                // a receipt failure shouldn't normally block/alarm the
                // admin over an already-successful approval.
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Receipt generation failed: $receiptErr'),
                      backgroundColor: const Color(0xFFDC2626),
                      duration: const Duration(seconds: 10),
                    ),
                  );
                }
              }
              final String resultingPaymentStatus =
                  _isCod ? (_paymentStatus ?? widget.order.paymentStatus) : 'Paid';

              if (mounted) {
                setState(() {
                  _currentStatus = 'Confirmed';
                  _paymentStatus = resultingPaymentStatus;
                  _cachedPayment = {
                    ...?_cachedPayment,
                    'payment_status': resultingPaymentStatus,
                  };
                });
                widget.onStatusUpdated('Confirmed', resultingPaymentStatus);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: const Text('Approve Payment', style: TextStyle(fontSize: 13)),
          ),
        ],

        // ── Confirmed → Preparing ─────────────────────────────────────
        if (_currentStatus == 'Confirmed' && paidOrCod)
          ElevatedButton(
            onPressed: () async {
              final bool? confirmed = await showConfirmDialog(
                context:      context,
                title:        'Mark as Preparing?',
                message:      'This will move the order to Preparing status.',
                confirmLabel: 'Mark Preparing',
                confirmColor: const Color(0xFF8B5CF6),
              );
              if (confirmed != true) return;

              await _orderService.updateOrderStatus(
                orderId:   int.parse(widget.order.orderId),
                status:    'Preparing',
                adminNote: _adminNoteController.text,
              );
              if (mounted) {
                setState(() => _currentStatus = 'Preparing');
                widget.onStatusUpdated('Preparing', _paymentStatus ?? widget.order.paymentStatus);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: const Text('Mark Preparing', style: TextStyle(fontSize: 13)),
          ),

        // ── Preparing → Shipped ───────────────────────────────────────
        // NOW BOOKS LALAMOVE AUTOMATICALLY instead of requiring a
        // manually-typed link.
        if (_currentStatus == 'Preparing' && paidOrCod)
          ElevatedButton(
            onPressed: _isBookingDelivery
                ? null
                : () async {
                    final bool? confirmed = await showConfirmDialog(
                      context: context,
                      title:   'Mark as Shipped?',
                      message: widget.order.hasCoordinates
                          ? 'This will book a real Lalamove courier for this order and notify the customer.'
                          : 'This order has no map coordinates, so a courier can\'t be booked automatically — '
                            'make sure you\'ve pasted a tracking link in the field below before continuing.',
                      confirmLabel: 'Mark Shipped',
                      confirmColor: const Color(0xFF06B6D4),
                    );
                    if (confirmed != true) return;

                    setState(() => _isBookingDelivery = true);

                   try {
                      final LalamoveOrderResult result = await _orderService.markAsShipped(
                        order: widget.order,
                        adminNote: _adminNoteController.text,
                      );

                      if (mounted) {
                        setState(() {
                          _currentStatus = 'Shipped';
                          _isBookingDelivery = false;
                          _trackingUrl = result.trackingUrl;
                          _lalamoveLinkController.text = result.trackingUrl;
                        });
                        widget.onStatusUpdated('Shipped', _paymentStatus ?? widget.order.paymentStatus);
                      }
                    } on AlreadyBookedException catch (bookedErr) {
                      // Do NOT fall through to manual booking — a
                      // courier may genuinely already be en route.
                      if (mounted) {
                        setState(() => _isBookingDelivery = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(bookedErr.message),
                            backgroundColor: const Color(0xFFDC2626),
                            duration: const Duration(seconds: 8),
                          ),
                        );
                      }
                      return;
                    } on OrderMissingCoordinatesException catch (_) {
                      // Fall back to the manual link field.
                      final String link = _lalamoveLinkController.text.trim();
                      final Uri? parsedLink = Uri.tryParse(link);
                      final bool linkLooksValid = parsedLink != null &&
                          (parsedLink.scheme == 'http' || parsedLink.scheme == 'https') &&
                          parsedLink.host.contains('lalamove.com');

                      if (link.isEmpty || !linkLooksValid) {
                        if (mounted) {
                          setState(() => _isBookingDelivery = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                link.isEmpty
                                    ? 'No coordinates on file — please paste a Lalamove tracking link manually before marking as Shipped.'
                                    : 'That doesn\'t look like a valid Lalamove tracking link.',
                              ),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                        return;
                      }

                      await _orderService.updateOrderStatus(
                        orderId:     int.parse(widget.order.orderId),
                        status:      'Shipped',
                        adminNote:   _adminNoteController.text,
                        trackingUrl: link,
                      );

                      if (mounted) {
                        setState(() {
                          _currentStatus = 'Shipped';
                          _isBookingDelivery = false;
                          _trackingUrl = link;
                        });
                        widget.onStatusUpdated('Shipped', _paymentStatus ?? widget.order.paymentStatus);
                      }
                    } on DeliveryQuoteFailedException catch (quoteErr) {
                      // Same fallback as missing coordinates — automatic
                      // booking can't work for this address, whether or
                      // not it technically has lat/lng on file.
                      if (mounted) {
                        setState(() => _isBookingDelivery = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(quoteErr.message),
                            backgroundColor: const Color(0xFFDC2626),
                            duration: const Duration(seconds: 8),
                          ),
                        );
                      }
                      return;
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isBookingDelivery = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not book delivery: $e'),
                            backgroundColor: const Color(0xFFDC2626),
                            duration: const Duration(seconds: 6),
                          ),
                        );
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: _isBookingDelivery
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Mark Shipped', style: TextStyle(fontSize: 13)),
          ),

        // ── Shipped → Completed ───────────────────────────────────────
        if (_currentStatus == 'Shipped' && paidOrCod)
          ElevatedButton(
            onPressed: () async {
              final bool? confirmed = await showConfirmDialog(
                context:      context,
                title:        'Mark as Completed?',
                message: _isCod
                    ? 'This will close the order and mark the COD payment as collected. This action cannot be undone.'
                    : 'This will close the order. This action cannot be undone.',
                confirmLabel: 'Mark Completed',
                confirmColor: const Color(0xFF6B7280),
              );
              if (confirmed != true) return;

              await _orderService.updateOrderStatus(
                orderId:   int.parse(widget.order.orderId),
                status:    'Completed',
                adminNote: _adminNoteController.text,
              );

              final String resultingPaymentStatus =
                  _isCod ? 'Paid' : (_paymentStatus ?? widget.order.paymentStatus);

              if (mounted) {
                setState(() {
                  _currentStatus = 'Completed';
                  _paymentStatus = resultingPaymentStatus;
                  _cachedPayment = {
                    ...?_cachedPayment,
                    'payment_status': resultingPaymentStatus,
                  };
                });
                widget.onStatusUpdated('Completed', resultingPaymentStatus);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B7280),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: const Text('Mark Completed', style: TextStyle(fontSize: 13)),
          ),
      ],
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  800,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                borderRadius: BorderRadius.only(
                  topLeft:  Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Details',
                        style: TextStyle(
                          fontSize:   18,
                          fontWeight: FontWeight.bold,
                          color:      Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isReadOnly
                            ? 'This order is $_currentStatus — no further actions available.'
                            : 'Review order information and manage order status',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isReadOnly
                              ? const Color(0xFF991B1B)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                   _buildProgressStepper(),
                    const SizedBox(height: 16),
                    _buildCustomerInfo(),
                    const SizedBox(height: 16),
                    _buildItemsAndSummary(),
                    const SizedBox(height: 16),
                    _buildPaymentSection(),
                    const SizedBox(height: 16),
                    _buildAdminFields(),
                    const SizedBox(height: 24),
                    if (!_isReadOnly)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [_buildActionButtons()],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}