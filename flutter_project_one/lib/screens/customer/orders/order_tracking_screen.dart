import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/order.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/orders/order_tracking_timeline.dart';
import '../../customer/messages/customer_chat_screen.dart';

// ================================================
// ORDER TRACKING SCREEN
//
// FIX: "TRACK PACKAGE" button now opens the real
//      Lalamove URL stored in order.trackingUrl.
//      If no URL yet (not shipped), shows disabled
//      state with a helpful message.
// ================================================

class OrderTrackingScreen extends StatelessWidget {
  final Order order;

  const OrderTrackingScreen({super.key, required this.order});

  static const List<String> _steps = [
    'Pending',
    'Confirmed',
    'Preparing',
    'Shipped',
    'Delivered',
  ];

  int get _currentStep {
    switch (order.orderStatus.toLowerCase()) {
      case 'confirmed':  return 1;
      case 'preparing':  return 2;
      case 'shipped':    return 3;
      case 'delivered':  return 4;
      default:           return 0;
    }
  }

  List<String?> get _timestamps => [
        order.dateTime,
        _currentStep >= 1 ? order.dateTime : null,
        _currentStep >= 2 ? order.dateTime : null,
        _currentStep >= 3 ? order.dateTime : null,
        _currentStep >= 4 ? 'Delivered' : null,
      ];

  bool get _hasTrackingUrl =>
      order.trackingUrl != null && order.trackingUrl!.isNotEmpty;

  bool get _hasReceipt =>
      order.receiptUrl != null && order.receiptUrl!.isNotEmpty;

  Color get _statusBadgeColor {
    switch (order.orderStatus.toLowerCase()) {
      case 'shipped':    return const Color(0xFF1A5276);
      case 'delivered':  return const Color(0xFF1E8449);
      case 'preparing':  return const Color(0xFF7D6608);
      case 'cancelled':  return const Color(0xFF991B1B);
      default:           return Colors.black;
    }
  }

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

  Widget buildCancelReasonCard() {
  if (order.cancelReason == null || order.cancelReason!.isEmpty) {
    return const SizedBox.shrink();
  }
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5F5),
      border: Border.all(color: const Color(0xFFFCA5A5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cancel_outlined, 
            size: 18, color: Color(0xFF991B1B)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Order Cancelled',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF991B1B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reason: ${order.cancelReason}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF991B1B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final hPad      = isDesktop ? 48.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(activeRoute: 'orders'),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: 896),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              hPad, 32, hPad, 80),
                          child: isDesktop
                              ? _DesktopLayout(screen: this)
                              : _MobileLayout(screen: this),
                        ),
                      ),
                    ),
                    const AppFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }

  // ── Shared section builders ───────────────────────────────────────────────

  Widget buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.only(right: 12, top: 4),
                child: Icon(Icons.arrow_back,
                    size: 22, color: Colors.black),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.orderId}',
                    style: const TextStyle(
                      fontFamily:  'Archivo Narrow',
                      fontSize:    28,
                      fontWeight:  FontWeight.w700,
                      letterSpacing: -0.5,
                      color:       Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Placed on ${order.dateTime}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize:   13,
                      color:      Color(0xFF656464),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              color: _statusBadgeColor,
              child: Text(
                order.orderStatus.toUpperCase(),
                style: const TextStyle(
                  fontFamily:   'Inter',
                  fontSize:     11,
                  fontWeight:   FontWeight.w700,
                  letterSpacing: 0.5,
                  color:        Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Receipt link in header if available
        if (_hasReceipt)
          GestureDetector(
            onTap: _openReceipt,
            child: const Row(
              children: [
                Icon(Icons.receipt_outlined,
                    size: 14, color: Color(0xFF2563EB)),
                SizedBox(width: 4),
                Text(
                  'View Receipt',
                  style: TextStyle(
                    fontFamily:  'Inter',
                    fontSize:    12,
                    color:       Color(0xFF2563EB),
                    fontWeight:  FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget buildTimeline() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:  Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: OrderTrackingTimeline(
        steps:       _steps,
        currentStep: _currentStep,
        timestamps:  _timestamps,
      ),
    );
  }

  // FIX: "TRACK PACKAGE" opens real Lalamove URL.
  //      Shows disabled state if not shipped yet.
  Widget buildTrackingNumberRow() {
    final bool canTrack = _hasTrackingUrl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:  Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined,
              size: 22, color: Color(0xFF656464)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DELIVERY TRACKING',
                  style: TextStyle(
                    fontFamily:   'Inter',
                    fontSize:     10,
                    fontWeight:   FontWeight.w600,
                    letterSpacing: 1.0,
                    color:        Color(0xFF656464),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  canTrack
                      ? 'Lalamove — tap to track your delivery'
                      : 'Tracking link will appear once your order is shipped',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize:   13,
                    color: canTrack
                        ? Colors.black
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: canTrack ? _openLalamove : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              color: canTrack
                  ? Colors.black
                  : const Color(0xFFD1D5DB),
              child: Text(
                'TRACK PACKAGE',
                style: TextStyle(
                  fontFamily:   'Inter',
                  fontSize:     12,
                  fontWeight:   FontWeight.w600,
                  letterSpacing: 1.0,
                  color: canTrack
                      ? Colors.white
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:  Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize:   20,
              fontWeight: FontWeight.w700,
              color:      Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width:  64,
                      height: 64,
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
                            item.productName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize:   14,
                              fontWeight: FontWeight.w600,
                              color:      Colors.black,
                            ),
                          ),
                          Text(
                            'Size: ${item.size}  ·  Brand: ${item.brand}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize:   12,
                              color:      Color(0xFF656464),
                            ),
                          ),
                          Text(
                            'Qty: ${item.quantity}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize:   12,
                              color:      Color(0xFF656464),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₱${item.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize:   14,
                        fontWeight: FontWeight.w600,
                        color:      Colors.black,
                      ),
                    ),
                  ],
                ),
              )),

          const Divider(height: 24, color: Color(0xFFCFC4C5)),

        _TotalRow(
            label: 'Subtotal',
            value: order.subtotal > 0
                ? order.subtotal
                : order.items.fold<double>(0, (sum, item) => sum + item.total),
          ),
          if (order.discountAmount > 0) ...[
            const SizedBox(height: 6),
            _TotalRow(label: 'Discount', value: -order.discountAmount),
          ],
          const SizedBox(height: 6),
          _TotalRow(
            label: 'Shipping',
            value: order.shipping,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFCFC4C5)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize:   15,
                  fontWeight: FontWeight.w700,
                  color:      Colors.black,
                ),
              ),
              Text(
                '₱${order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize:   20,
                  fontWeight: FontWeight.w700,
                  color:      Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSupportCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:  Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Support',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize:   20,
              fontWeight: FontWeight.w700,
              color:      Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Having trouble with your order? Our team is available 24/7 to assist you.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize:   13,
              color:      Color(0xFF656464),
              height:     1.5,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const CustomerChatScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.black)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_outlined,
                      size: 16, color: Colors.black),
                  SizedBox(width: 8),
                  Text(
                    'CONTACT SELLER',
                    style: TextStyle(
                      fontFamily:   'Inter',
                      fontSize:     13,
                      fontWeight:   FontWeight.w600,
                      letterSpacing: 1.0,
                      color:        Colors.black,
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

  Widget buildShippingAddressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:  Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shipping Address',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize:   20,
              fontWeight: FontWeight.w700,
              color:      Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(order.customerName,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                  color:      Colors.black)),
          const SizedBox(height: 4),
          Text(order.address,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize:   14,
                  color:      Color(0xFF4C4546),
                  height:     1.5)),
          if (order.landmark.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(order.landmark,
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize:   13,
                    color:      Color(0xFF656464))),
          ],
          const SizedBox(height: 4),
          Text(order.contact,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize:   13,
                  color:      Color(0xFF656464))),
        ],
      ),
    );
  }

  Widget buildAdminNoteCard() {
    if (order.adminNote == null || order.adminNote!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Note from DeeGee Kickz',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.adminNote!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF1E40AF),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



// ─── Desktop layout ───────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final OrderTrackingScreen screen;
  const _DesktopLayout({required this.screen});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        screen.buildHeader(context),
        const SizedBox(height: 24),
        screen.buildCancelReasonCard(),
        screen.buildAdminNoteCard(),
        const SizedBox(height: 16),
        screen.buildTrackingNumberRow(),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: screen.buildOrderSummary()),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  screen.buildSupportCard(context),
                  const SizedBox(height: 16),
                  screen.buildShippingAddressCard(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}



// ─── Mobile layout ────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final OrderTrackingScreen screen;
  const _MobileLayout({required this.screen});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        screen.buildHeader(context),
        const SizedBox(height: 16),
        screen.buildCancelReasonCard(),
        screen.buildAdminNoteCard(),
        const SizedBox(height: 20),
        screen.buildTimeline(),
        const SizedBox(height: 12),
        screen.buildTrackingNumberRow(),
        const SizedBox(height: 12),
        screen.buildOrderSummary(),
        const SizedBox(height: 12),
        screen.buildSupportCard(context),
        const SizedBox(height: 12),
        screen.buildShippingAddressCard(),
      ],
    );
  }
}

// ─── Total row helper ─────────────────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  const _TotalRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Inter',
                fontSize:   13,
                color:      Color(0xFF656464))),
        Text('₱${value.toStringAsFixed(2)}',
            style: const TextStyle(
                fontFamily: 'Inter',
                fontSize:   13,
                color:      Colors.black)),
      ],
    );
  }
}