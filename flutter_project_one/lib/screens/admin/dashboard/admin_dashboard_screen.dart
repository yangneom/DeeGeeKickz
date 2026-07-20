import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/admin/dashboard/stats_card.dart';
import '../../../widgets/admin/dashboard/inventory_summary_card.dart';
import '../../../widgets/admin/dashboard/order_status_card.dart';
import '../../../widgets/admin/dashboard/recent_feedback_card.dart';
import '../../../providers/admin_provider/admin_dashboard_provider.dart';
import '../../../providers/customer/notification_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  // Called with the sidebar index to jump to (see AdminLayout's
  // _currentIndex mapping: 0=Dashboard,1=Inventory,2=Sales,
  // 3=Feedback,4=Messages,5=Order Approval,6=Promotions,7=Notification)
  final void Function(int index)? onNavigate;

  const AdminDashboardScreen({super.key, this.onNavigate});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends ConsumerState<AdminDashboardScreen> {

  @override
  void initState() {
    super.initState();
    // notificationProvider (used elsewhere for the bell icon /
    // notifications screen) only loads once by default — make sure
    // it's fresh when the dashboard is opened, same as
    // AdminNotificationsScreen already does.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).loadNotifications();
    });
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(adminDashboardDataProvider);
    final unreadNotifications = ref.watch(notificationProvider).unreadCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminDashboardDataProvider);
          await ref.read(notificationProvider.notifier).loadNotifications();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── TITLE ──
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'Welcome back! Here\'s what needs your attention today.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),

              const SizedBox(height: 24),

              dashboardAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 40, color: Color(0xFF9CA3AF)),
                        const SizedBox(height: 12),
                        const Text(
                          'Could not load dashboard data.',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(adminDashboardDataProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (data) {
                  final int outOfStock = data.outOfStockProducts;
                  final int lowStock = data.lowStockProducts;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── 5 STATS CARDS ──
                      Row(
                        children: [

                          // pending orders
                          Expanded(
                            child: StatsCard(
                              icon: Icons.shopping_cart_outlined,
                              iconBackgroundColor:
                                  const Color(0xFFEFF6FF),
                              iconColor: const Color(0xFF2563EB),
                              title: 'Pending Orders',
                              count: data.pendingOrders,
                              countColor: const Color(0xFF111827),
                              onTap: () => widget.onNavigate?.call(5),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // low stock items
                          Expanded(
                            child: StatsCard(
                              icon: Icons.warning_amber_outlined,
                              iconBackgroundColor:
                                  const Color(0xFFFFFBEB),
                              iconColor: const Color(0xFFF59E0B),
                              title: 'Low Stock Items',
                              count: lowStock,
                              countColor: const Color(0xFFF59E0B),
                              onTap: () => widget.onNavigate?.call(1),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // new feedback (flagged)
                          Expanded(
                            child: StatsCard(
                              icon: Icons.chat_bubble_outline,
                              iconBackgroundColor:
                                  const Color(0xFFFFF7ED),
                              iconColor: const Color(0xFFF97316),
                              title: 'New Feedback',
                              count: data.flaggedFeedback,
                              countColor: const Color(0xFFF97316),
                              onTap: () => widget.onNavigate?.call(3),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // unread notifications
                          Expanded(
                            child: StatsCard(
                              icon: Icons.notifications_outlined,
                              iconBackgroundColor:
                                  const Color(0xFFF0FDF4),
                              iconColor: const Color(0xFF16A34A),
                              title: 'Unread Notifications',
                              count: unreadNotifications,
                              countColor: const Color(0xFF16A34A),
                              onTap: () => widget.onNavigate?.call(7),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // out of stock
                          Expanded(
                            child: StatsCard(
                              icon: Icons.inventory_2_outlined,
                              iconBackgroundColor:
                                  const Color(0xFFF5F3FF),
                              iconColor: const Color(0xFF7C3AED),
                              title: 'Out of Stock Items',
                              count: outOfStock,
                              countColor: const Color(0xFF7C3AED),
                              onTap: () => widget.onNavigate?.call(1),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── 3 MIDDLE CARDS ──
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [

                            // inventory summary
                            Expanded(
                              child: InventorySummaryCard(
                                totalProducts: data.totalProducts,
                                inStock: data.inStockProducts,
                                lowStock: data.lowStockProducts,
                                outOfStock: data.outOfStockProducts,
                                onViewAll: () => widget.onNavigate?.call(1),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // order status chart
                            Expanded(
                              child: OrderStatusCard(
                                pending:
                                    data.orderStatusCounts['Pending'] ?? 0,
                                confirmed: data
                                        .orderStatusCounts['Confirmed'] ??
                                    0,
                                preparing: data
                                        .orderStatusCounts['Preparing'] ??
                                    0,
                                shipped:
                                    data.orderStatusCounts['Shipped'] ?? 0,
                                completed: data
                                        .orderStatusCounts['Completed'] ??
                                    0,
                                cancelled: data
                                        .orderStatusCounts['Cancelled'] ??
                                    0,
                                onViewAll: () => widget.onNavigate?.call(5),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // recent feedback
                            Expanded(
                              flex: 2,
                              child: RecentFeedbackCard(
                                onViewAll: () => widget.onNavigate?.call(3),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}