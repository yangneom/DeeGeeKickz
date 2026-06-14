import 'package:flutter/material.dart';

import '../../../models/order.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/orders/order_tracking_timeline.dart';
import '../../customer/messages/customer_chat_screen.dart';

/// Full order tracking detail screen.
/// Matches the mockup:
///   - Header: order # + date + status badge + courier
///   - Horizontal timeline with timestamps
///   - Tracking number row + "Track Package" button
///   - Order Summary card (items + subtotal/shipping/tax/total)
///   - Support card (Contact Seller + Report Issue)
///   - Shipping Address card
class OrderTrackingScreen extends StatelessWidget {
  final Order order;

  const OrderTrackingScreen({super.key, required this.order});

  // ── Step config ───────────────────────────────────────────────────────────
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

  // Mock timestamps — replace with real Supabase order event log
  List<String?> get _timestamps => [
        order.dateTime,
        _currentStep >= 1 ? order.dateTime : null,
        _currentStep >= 2 ? order.dateTime : null,
        _currentStep >= 3 ? order.dateTime : null,
        _currentStep >= 4 ? 'Estimated soon' : null,
      ];

  // Mock tracking number — replace with Supabase field
  String get _trackingNumber =>
      'DGK-${order.orderId.toUpperCase().replaceAll('_', '')}-X';

  // Mock courier
  String get _courier => 'LBC Express';

  Color get _statusBadgeColor {
    switch (order.orderStatus.toLowerCase()) {
      case 'shipped':   return const Color(0xFF1A5276);
      case 'delivered': return const Color(0xFF1E8449);
      case 'preparing': return const Color(0xFF7D6608);
      default:          return Colors.black;
    }
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

  // ── Shared section builders (used by both layouts) ────────────────────────

  Widget buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.only(right: 12, top: 4),
                child: Icon(Icons.arrow_back, size: 22, color: Colors.black),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${_trackingNumber}',
                    style: const TextStyle(
                      fontFamily: 'Archivo Narrow',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Placed on ${order.dateTime}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF656464),
                    ),
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              color: _statusBadgeColor,
              child: Text(
                order.orderStatus.toUpperCase(),
                style: const TextStyle(
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
        const SizedBox(height: 4),
        Text(
          'Courier: $_courier',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Color(0xFF656464),
          ),
        ),
      ],
    );
  }

  Widget buildTimeline() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: OrderTrackingTimeline(
        steps: _steps,
        currentStep: _currentStep,
        timestamps: _timestamps,
      ),
    );
  }

  Widget buildTrackingNumberRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 22, color: Color(0xFF656464)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TRACKING NUMBER',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: Color(0xFF656464),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _trackingNumber,
                  style: const TextStyle(
                    fontFamily: 'Archivo Narrow',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              // TODO: open courier tracking URL
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              color: Colors.black,
              child: const Text(
                'TRACK PACKAGE',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: Colors.white,
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
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          // Items
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 64,
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
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            'Size: ${item.size}  ·  Brand: ${item.brand}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF656464),
                            ),
                          ),
                          Text(
                            'Qty: ${item.quantity}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF656464),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₱${item.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              )),

          const Divider(height: 24, color: Color(0xFFCFC4C5)),

          // Totals
          _TotalRow(label: 'Subtotal', value: order.totalAmount),
          const SizedBox(height: 6),
          _TotalRow(label: 'Shipping', value: 80),
          const SizedBox(height: 6),
          _TotalRow(label: 'Tax', value: order.totalAmount * 0.05),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Text(
                '₱${(order.totalAmount + 80 + order.totalAmount * 0.05).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
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
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Support',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Having trouble with your order? Our team is available 24/7 to assist you with tracking or delivery concerns.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF656464),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Contact Seller
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const CustomerChatScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_outlined, size: 16, color: Colors.black),
                  SizedBox(width: 8),
                  Text(
                    'CONTACT SELLER',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Report Issue
          GestureDetector(
            onTap: () {
              // TODO: open report issue form
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFBA1A1A)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag_outlined,
                      size: 16, color: Color(0xFFBA1A1A)),
                  SizedBox(width: 8),
                  Text(
                    'REPORT ISSUE',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: Color(0xFFBA1A1A),
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
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shipping Address',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            order.customerName,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            order.address,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF4C4546),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            order.landmark,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF656464),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            order.contact,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF656464),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Desktop layout (2-column) ────────────────────────────────────────────────

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
        screen.buildTimeline(),
        const SizedBox(height: 16),
        screen.buildTrackingNumberRow(),
        const SizedBox(height: 24),

        // Two-column: Order Summary (left) + Support & Address (right)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: screen.buildOrderSummary(),
            ),
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

// ─── Mobile layout (single column) ───────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final OrderTrackingScreen screen;
  const _MobileLayout({required this.screen});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        screen.buildHeader(context),
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
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Color(0xFF656464),
          ),
        ),
        Text(
          '₱${value.toStringAsFixed(2)}',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}