import 'package:flutter/material.dart';

import '../../../models/order.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/orders/order_history_filter_chips.dart';
import '../../../widgets/customer/orders/order_history_tile.dart';
import 'order_tracking_screen.dart';

/// Full order history for the logged-in customer.
/// Accessible via:
///   - BottomNavBar index 3 (Orders icon)
///   - Profile screen "View All" button
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String _selectedFilter = 'All';

  // Mock: all orders for the logged-in customer
  // Replace with Supabase query filtered by auth user ID when ready
  final List<Order> _allOrders = fakeOrders;

  List<Order> get _filtered {
    if (_selectedFilter == 'All') return _allOrders;
    return _allOrders
        .where((o) =>
            o.orderStatus.toLowerCase() ==
            _selectedFilter.toLowerCase())
        .toList();
  }

  void _goToTracking(Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(order: order),
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
                        constraints: const BoxConstraints(maxWidth: 896),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              hPad, 32, hPad, 80),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // ── Page title ──────────────────
                              const Text(
                                'MY ORDERS',
                                style: TextStyle(
                                  fontFamily: 'Archivo Narrow',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  color: Colors.black,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                '${_allOrders.length} order${_allOrders.length != 1 ? 's' : ''} total',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: Color(0xFF656464),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Filter chips ────────────────
                              OrderHistoryFilterChips(
                                selectedFilter: _selectedFilter,
                                onFilterChanged: (f) =>
                                    setState(() => _selectedFilter = f),
                              ),

                              const SizedBox(height: 20),

                              const Divider(
                                  height: 1,
                                  color: Color(0xFFCFC4C5)),

                              const SizedBox(height: 20),

                              // ── Order list ──────────────────
                              if (_filtered.isEmpty)
                                _EmptyState(filter: _selectedFilter)
                              else
                                Column(
                                  children: _filtered
                                      .map(
                                        (order) => OrderHistoryTile(
                                          order: order,
                                          onTrack: () =>
                                              _goToTracking(order),
                                        ),
                                      )
                                      .toList(),
                                ),
                            ],
                          ),
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
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 48, color: Color(0xFFCFC4C5)),
          const SizedBox(height: 16),
          Text(
            filter == 'All'
                ? 'No orders yet.'
                : 'No $filter orders.',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: Color(0xFF656464),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your orders will appear here once you place one.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFFCFC4C5),
            ),
          ),
        ],
      ),
    );
  }
}