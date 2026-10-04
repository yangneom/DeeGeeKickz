import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/admin/dashboard/stats_card.dart';
import '../../../widgets/admin/dashboard/inventory_summary_card.dart';
import '../../../widgets/admin/dashboard/order_status_card.dart';
import '../../../widgets/admin/dashboard/recent_feedback_card.dart';
import '../../../providers/admin_provider/admin_dashboard_provider.dart';
import '../../../providers/customer/notification_provider.dart';
import '../../../providers/customer/review_providers.dart';
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
    // Make sure the ADMIN inbox is fresh when the dashboard opens.
    // (This used to refresh the Customer notifier, `notificationProvider`,
    // which is a different inbox from the one the Admin bell and the
    // Admin notifications page read — so the card could disagree with
    // the bell.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminNotificationProvider.notifier).loadNotifications();
    });
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(adminDashboardDataProvider);
    // Same provider as the top-bar bell and the Admin notifications
    // page, so all three always show the same unread number.
    final unreadNotifications =
        ref.watch(adminNotificationProvider).unreadCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminDashboardDataProvider);
          ref.invalidate(recentFeedbackProvider);
          await ref.read(adminNotificationProvider.notifier).loadNotifications();
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
                  final int pending = data.pendingOrders;
                  final int outOfStock = data.outOfStockProducts;
                  final int lowStock = data.lowStockProducts;
                  final int feedback = data.flaggedFeedback;

                  // A number only takes its warning color when there is
                  // something to act on; at zero it stays neutral so the
                  // dashboard doesn't shout about nothing.
                  const Color neutral = Color(0xFF111827);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── 5 STATS CARDS — ordered by urgency ──
                      Row(
                        children: [

                          // 1. pending orders — operational / action item
                          Expanded(
                            child: StatsCard(
                              icon: Icons.shopping_cart_outlined,
                              iconBackgroundColor:
                                  const Color(0xFFEFF6FF),
                              iconColor: const Color(0xFF2563EB),
                              title: 'Pending Orders',
                              count: pending,
                              countColor: pending > 0
                                  ? const Color(0xFF2563EB)
                                  : neutral,
                              caption: pending > 0
                                  ? 'Awaiting your action'
                                  : 'All clear',
                              onTap: () => widget.onNavigate?.call(5),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // 2. low stock — warning
                          Expanded(
                            child: StatsCard(
                              icon: Icons.warning_amber_outlined,
                              iconBackgroundColor:
                                  const Color(0xFFFFFBEB),
                              iconColor: const Color(0xFFF59E0B),
                              title: 'Low Stock Items',
                              count: lowStock,
                              countColor: lowStock > 0
                                  ? const Color(0xFFD97706)
                                  : neutral,
                              caption: lowStock > 0
                                  ? 'Running low'
                                  : 'All clear',
                              onTap: () => widget.onNavigate?.call(1),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // 3. out of stock — critical
                          Expanded(
                            child: StatsCard(
                              icon: Icons.remove_shopping_cart_outlined,
                              iconBackgroundColor:
                                  const Color(0xFFFEF2F2),
                              iconColor: const Color(0xFFDC2626),
                              title: 'Out of Stock Items',
                              count: outOfStock,
                              countColor: outOfStock > 0
                                  ? const Color(0xFFDC2626)
                                  : neutral,
                              caption: outOfStock > 0
                                  ? 'Needs restocking'
                                  : 'All clear',
                              onTap: () => widget.onNavigate?.call(1),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // 4. new feedback — customer-related
                          Expanded(
                            child: StatsCard(
                              icon: Icons.chat_bubble_outline,
                              iconBackgroundColor:
                                  const Color(0xFFF5F3FF),
                              iconColor: const Color(0xFF7C3AED),
                              title: 'New Feedback',
                              count: feedback,
                              countColor: feedback > 0
                                  ? const Color(0xFF7C3AED)
                                  : neutral,
                                                          caption: feedback > 0
                                  ? 'Awaiting your reply'
                                  : 'All replied',
                              onTap: () => widget.onNavigate?.call(3),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // 5. unread notifications — neutral
                          Expanded(
                            child: StatsCard(
                              icon: Icons.notifications_outlined,
                              iconBackgroundColor:
                                  const Color(0xFFF3F4F6),
                              iconColor: const Color(0xFF6B7280),
                              title: 'Unread Notifications',
                              count: unreadNotifications,
                              countColor: const Color(0xFF374151),
                              caption: unreadNotifications > 0
                                  ? 'Waiting for you'
                                  : 'All caught up',
                              onTap: () => widget.onNavigate?.call(7),
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