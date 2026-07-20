import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/login_screen.dart';
import '../../../providers/customer/customer_cart_provider.dart';
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

// ── Models ───────────────────────────────────────────────────────────────────
import '../../../models/customer_account.dart';
import '../../../models/customer_address.dart';
import '../../../models/order.dart';

// ── Services ─────────────────────────────────────────────────────────────────
import '../../../services/customer/address/address_service.dart';
import '../../../services/customer/History/order_history_service.dart';
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
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  late Future<CustomerAccount?> _userFuture;
  late Future<List<CustomerAddress>> _addressesFuture;
  late Future<List<Order>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _fetchCurrentUser();
    _addressesFuture = AddressService().getMyAddresses();
    _ordersFuture = OrderHistoryService().getMyOrders();
  }

  // ── Fetch the logged-in customer's own row, joined with address ────────────
  Future<CustomerAccount?> _fetchCurrentUser() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) return null;

    try {
      final response = await _supabase
          .from('users')
          .select('*, address(*)')
          .eq('id', authUser.id)
          .single();

      return CustomerAccount.fromJson(response);
    } catch (error) {
      print('ProfileScreen _fetchCurrentUser error: $error');
      return null;
    }
  }

  // Active order = first order that is NOT delivered or cancelled
// Active order = first order that is NOT delivered or cancelled
  Order? _activeOrderFrom(List<Order> orders) {
    try {
      return orders.firstWhere(
        (o) =>
            o.orderStatus.toLowerCase() != 'delivered' &&
            o.orderStatus.toLowerCase() != 'cancelled',
      );
    } catch (_) {
      return null;
    }
  }

  // Preview = first 2 orders for the mini history card
  List<Order> _previewOrdersFrom(List<Order> orders) => orders.take(2).toList();
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
            child: FutureBuilder<List<dynamic>>(
                future: Future.wait([_userFuture, _addressesFuture, _ordersFuture]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final user = snapshot.data?[0] as CustomerAccount?;
                  final addresses = (snapshot.data?[1] as List<CustomerAddress>?) ?? [];
                  final orders = (snapshot.data?[2] as List<Order>?) ?? [];

                  if (user == null) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Could not load your profile. Please try logging in again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Color(0xFF656464),
                          ),
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PageContent(
                          user: user,
                          addresses: addresses,
                          previewOrders: _previewOrdersFrom(orders),
                          activeOrder: _activeOrderFrom(orders),
                          onAddressesChanged: () {
                            setState(() {
                              _addressesFuture = AddressService().getMyAddresses();
                            });
                          },
                        ),
                        const AppFooter(),
                    ],
                    ),
                  );
                },
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
  final VoidCallback onAddressesChanged;

  const _PageContent({
    required this.user,
    required this.addresses,
    required this.previewOrders,
    required this.onAddressesChanged,
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
              // ── 3. Saved Addresses ──────────────────────────────
              ProfileAddressSection(
                addresses: addresses,
                onChanged: onAddressesChanged,
              ),

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

class _LogoutButton extends ConsumerWidget {                    // ← 1. StatelessWidget → ConsumerWidget
  @override
  Widget build(BuildContext context, WidgetRef ref) {            
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
                    ref.read(customerCartProvider.notifier).clearLocalOnly();   // ← 3. add this line


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