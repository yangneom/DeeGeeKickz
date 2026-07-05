import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/login_screen.dart';

// ── Common nav widgets ────────────────────────────────────────────────────────
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';

// ── Profile widgets ───────────────────────────────────────────────────────────
import '../../../widgets/customer/profile/profile_header.dart';
import '../../../widgets/customer/profile/profile_info_section.dart';
import '../../../widgets/customer/profile/profile_address_section.dart';
import '../../../widgets/customer/profile/profile_orders_section.dart';
import '../../../widgets/customer/profile/profile_active_order_card.dart';

// ── Models / mock data ────────────────────────────────────────────────────────
import '../../../models/customer_account.dart';
import '../../../models/customer_address.dart';
import '../../../models/order.dart';

// ── Other screens ─────────────────────────────────────────────────────────────
import '../orders/order_history_screen.dart';
import '../orders/order_tracking_screen.dart';

/// Customer Profile screen.
///
/// Sections (top → bottom):
///   0. Active Order card   — only shown if user has a non-delivered order
///   1. Profile Information
///   2. Saved Addresses     — with add/edit bottom sheet
///   3. Order History       — 2-item preview + "View All" → OrderHistoryScreen
///   4. Logout button
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // ── Mock current user ───────────────────────────────────────────────────────
  static final CustomerAccount _mockUser = fakeCustomerAccounts.first;

  // ── Mock addresses ──────────────────────────────────────────────────────────
  static final List<CustomerAddress> _mockAddresses = mockSavedAddresses;

  // ── Orders — empty until real Supabase load is wired up ────────────────────
  static const List<Order> _allOrders = [];

  // Active order = first order that is NOT delivered or cancelled
  static Order? get _activeOrder {
    try {
      return _allOrders.firstWhere(
        (o) =>
            o.orderStatus.toLowerCase() != 'delivered' &&
            o.orderStatus.toLowerCase() != 'cancelled',
      );
    } catch (_) {
      return null;
    }
  }

  // Preview = first 2 orders for the mini history card
  static List<Order> get _previewOrders => _allOrders.take(2).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(activeRoute: 'profile'),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PageContent(
                      user: _mockUser,
                      addresses: _mockAddresses,
                      previewOrders: _previewOrders,
                      activeOrder: _activeOrder,
                    ),
                    const AppFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 4),
    );
  }
}

// ─── Page content ─────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final CustomerAccount user;
  final List<CustomerAddress> addresses;
  final List<Order> previewOrders;
  final Order? activeOrder;

  const _PageContent({
    required this.user,
    required this.addresses,
    required this.previewOrders,
    this.activeOrder,
  });

  void _goToOrderHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
    );
  }

  void _goToTracking(BuildContext context, Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final hPad      = isDesktop ? 48.0 : 16.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 896),
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 0. Profile header (avatar + name + tier) ───────
              Center(child: ProfileHeader(account: user)),

              const SizedBox(height: 48),

              // ── 1. Active Order (hidden when no active order) ───
              if (activeOrder != null) ...[
                ProfileActiveOrderCard(
                  order: activeOrder!,
                  onTrack: () => _goToTracking(context, activeOrder!),
                ),
                const SizedBox(height: 24),
              ],

              // ── 2. Profile Information ──────────────────────────
              ProfileInfoSection(account: user),

              const SizedBox(height: 24),

              // ── 3. Saved Addresses ──────────────────────────────
              ProfileAddressSection(addresses: addresses),

              const SizedBox(height: 24),

              // ── 4. Order History preview ────────────────────────
              _OrderHistoryPreview(
                orders: previewOrders,
                onViewAll: () => _goToOrderHistory(context),
                onTrack: (order) => _goToTracking(context, order),
              ),

              const SizedBox(height: 24),

              // ── 5. Logout ───────────────────────────────────────
              _LogoutButton(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Order history preview card ───────────────────────────────────────────────

class _OrderHistoryPreview extends StatelessWidget {
  final List<Order> orders;
  final VoidCallback onViewAll;
  final void Function(Order) onTrack;

  const _OrderHistoryPreview({
    required this.orders,
    required this.onViewAll,
    required this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final padding   = isDesktop ? 48.0 : 16.0;

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
          // Header
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
                onTap: onViewAll,
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
                final order  = orders[i];
                final isLast = i == orders.length - 1;
                return Column(
                  children: [
                    _PreviewOrderRow(
                      order: order,
                      onTrack: () => onTrack(order),
                    ),
                    if (!isLast)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                            height: 1, color: Color(0xFFCFC4C5)),
                      ),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _PreviewOrderRow extends StatelessWidget {
  final Order order;
  final VoidCallback onTrack;

  const _PreviewOrderRow({required this.order, required this.onTrack});

  @override
  Widget build(BuildContext context) {
    final firstItem = order.items.isNotEmpty ? order.items.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            color: const Color(0xFFEEEEEE),
            child: const Icon(Icons.shopping_bag_outlined,
                size: 28, color: Color(0xFF656464)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    Text(
                      order.orderStatus.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Order #${order.orderId.toUpperCase()}  ·  ${order.dateTime}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF656464),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '₱${order.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onTrack,
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
    );
  }
}

// ─── Logout button ────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFFF9F9F9),
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero),
            title: const Text(
              'LOGOUT',
              style: TextStyle(
                fontFamily: 'Archivo Narrow',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            content: const Text(
              'Are you sure you want to log out?',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: Color(0xFF4C4546),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF656464),
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                    Navigator.of(context).pop();

                    await Supabase.instance.client.auth.signOut();

                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                child: const Text(
                  'LOGOUT',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFBA1A1A),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          border: Border.all(color: const Color(0xFFBA1A1A), width: 1),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 20, color: Color(0xFFBA1A1A)),
            SizedBox(width: 12),
            Text(
              'LOGOUT',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Color(0xFFBA1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}