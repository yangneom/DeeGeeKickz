import 'package:flutter/material.dart';

import '../../../models/order.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/orders/order_history_filter_chips.dart';
import '../../../widgets/customer/orders/order_history_tile.dart';
import 'order_tracking_screen.dart';
import '../../../services/customer/History/order_history_service.dart';

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

  final OrderHistoryService _service = OrderHistoryService();

  List<Order> _allOrders = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }
  
  // (A didChangeDependencies() reload used to be here. It ran on EVERY change of
  // the screen size, keyboard or theme, and replaced the page with a spinner each
  // time. The list now refreshes when a cancellation succeeds and when the
  // customer comes back from the order page, which is what it was meant to do.)


  // silent: true refreshes the list in place (no full-screen spinner).
  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    final orders = await _service.getMyOrders();

    if (mounted) {
      setState(() {
        // Extra safety — never show Awaiting Payment on customer side
        _allOrders = orders
            .where((o) => o.orderStatus.toLowerCase() != 'awaiting payment')
            .toList();
        _loading = false;
      });
    }
  }

  List<Order> get _filtered {
    if (_selectedFilter == 'All') return _allOrders;
    return _allOrders
        .where((o) =>
            o.orderStatus.toLowerCase() ==
            _selectedFilter.toLowerCase())
        .toList();
  }

  Future<void> _goToTracking(Order order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(order: order),
      ),
    );
    // The status may have changed while the customer was on the order page.
    if (mounted) _loadOrders(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
                                          onCancelled: _loadOrders,
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
          if (filter == 'All') ...[
            const SizedBox(height: 12),
            const Text(
              'If you just paid via GCash or Card, your order will '
              'appear here shortly once payment is confirmed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ],
      ),
    );
  }
}