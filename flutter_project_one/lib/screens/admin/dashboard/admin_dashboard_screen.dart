import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/admin/dashboard/stats_card.dart';
import '../../../widgets/admin/dashboard/inventory_summary_card.dart';
import '../../../widgets/admin/dashboard/order_status_card.dart';
import '../../../widgets/admin/dashboard/recent_feedback_card.dart';
import '../../../widgets/common/common_table.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends ConsumerState<AdminDashboardScreen> {

  // ================================================
  // FAKE DATA — for testing only
  // later this will come from Firebase
  // ================================================

  // stats card data
  final int _pendingOrders = 5;
  final int _lowStockItems = 12;
  final int _newFeedback = 4;
  final int _unreadNotifications = 3;
  final int _outOfStockItems = 3;

  // order status data
  final int _pending = 5;
  final int _confirmed = 3;
  final int _preparing = 4;
  final int _shipped = 6;
  final int _completed = 18;
  final int _cancelled = 2;

  // recent feedback data
  final List<FeedbackItem> _recentFeedback = [
    FeedbackItem(
      customerName: 'Angel Tuazon',
      productName: 'Nike Air Force 1',
      rating: 3,
      status: 'Flagged',
      date: 'May 6, 2025',
    ),
    FeedbackItem(
      customerName: 'Jay Galang',
      productName: 'Adidas Samba',
      rating: 4,
      status: 'Visible',
      date: 'May 6, 2025',
    ),
    FeedbackItem(
      customerName: 'John Dela Cruz',
      productName: 'New Balance 550',
      rating: 5,
      status: 'Visible',
      date: 'May 5, 2025',
    ),
    FeedbackItem(
      customerName: 'Maria Santos',
      productName: 'Nike Dunk Low',
      rating: 2,
      status: 'Flagged',
      date: 'May 5, 2025',
    ),
    FeedbackItem(
      customerName: 'Kevin Reyes',
      productName: 'Puma RS-X',
      rating: 3,
      status: 'Visible',
      date: 'May 4, 2025',
    ),
  ];

  // ================================================
  // BUILD PRIORITY BADGE
  // High = red, Medium = yellow, Low = green
  // ================================================
  Widget _buildPriorityBadge(String priority) {

    Color backgroundColor = Colors.grey.shade100;
    Color textColor = Colors.grey;

    if (priority == 'High') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFDC2626);
    }

    if (priority == 'Medium') {
      backgroundColor = const Color(0xFFFEF9C3);
      textColor = const Color(0xFFCA8A04);
    }

    if (priority == 'Low') {
      backgroundColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF16A34A);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          priority,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // ================================================
  // BUILD PRIORITY TASKS ROWS
  // ================================================
  List<List<Widget>> _buildPriorityTaskRows() {

    // list of tasks
    List<Map<String, String>> tasks = [
      {
        'icon': 'orders',
        'task': 'Orders waiting for approval',
        'details': 'Review and approve customer orders.',
        'description': '5 orders are pending your approval.',
        'priority': 'High',
        'due': 'Due today',
        'action': 'Review Orders',
      },
      {
        'icon': 'inventory',
        'task': 'Low stock items',
        'details': 'Items that needs restocking soon.',
        'description': '12 products are running low on stock.',
        'priority': 'Medium',
        'due': 'Within 2 days',
        'action': 'View Inventory',
      },
      {
        'icon': 'feedback',
        'task': 'Flagged feedback',
        'details': 'Feedback that needs your review.',
        'description': '4 feedbacks are flagged for review.',
        'priority': 'High',
        'due': 'Due today',
        'action': 'Review Feedback',
      },
      {
        'icon': 'shipment',
        'task': 'Pending shipments update',
        'details': 'Update shipment status of orders.',
        'description': '6 orders are ready for shipment update.',
        'priority': 'Medium',
        'due': 'Within 2 days',
        'action': 'Update Shipments',
      },
      {
        'icon': 'accounts',
        'task': 'Customer accounts for verification',
        'details': 'Verify new or suspicious accounts.',
        'description': '3 accounts need verification.',
        'priority': 'Low',
        'due': 'Within 3 days',
        'action': 'Verify Accounts',
      },
    ];

    // this will hold all our rows
    List<List<Widget>> tableRows = [];

    // loop through each task
    for (int i = 0; i < tasks.length; i = i + 1) {

      // get current task
      Map<String, String> task = tasks[i];

      // build one row
      List<Widget> oneRow = [

        // column 1 — task name + details
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task['task']!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              task['details']!,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),

        // column 2 — description
        Text(
          task['description']!,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF374151),
          ),
        ),

        // column 3 — priority badge
        _buildPriorityBadge(task['priority']!),

        // column 4 — due date
        Text(
          task['due']!,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF374151),
          ),
        ),

        // column 5 — action button
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              print('Action: ${task['action']}');
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              padding: EdgeInsets.zero,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task['action']!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: Color(0xFF2563EB),
                ),
              ],
            ),
          ),
        ),
      ];

      tableRows.add(oneRow);
    }

    return tableRows;
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
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
              'Welcome back, Angel Tuazon! Here\'s what needs your attention today.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),

            const SizedBox(height: 24),

            // ── 5 STATS CARDS ──
            Row(
              children: [

                // pending orders
                Expanded(
                  child: StatsCard(
                    icon: Icons.shopping_cart_outlined,
                    iconBackgroundColor: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                    title: 'Pending Orders',
                    count: _pendingOrders,
                    countColor: const Color(0xFF111827),
                    onTap: () {
                      print('View pending orders');
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // low stock items
                Expanded(
                  child: StatsCard(
                    icon: Icons.warning_amber_outlined,
                    iconBackgroundColor: const Color(0xFFFFFBEB),
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Low Stock Items',
                    count: _lowStockItems,
                    countColor: const Color(0xFFF59E0B),
                    onTap: () {
                      print('View low stock');
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // new feedback
                Expanded(
                  child: StatsCard(
                    icon: Icons.chat_bubble_outline,
                    iconBackgroundColor: const Color(0xFFFFF7ED),
                    iconColor: const Color(0xFFF97316),
                    title: 'New Feedback',
                    count: _newFeedback,
                    countColor: const Color(0xFFF97316),
                    onTap: () {
                      print('View feedback');
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // unread notifications
                Expanded(
                  child: StatsCard(
                    icon: Icons.notifications_outlined,
                    iconBackgroundColor: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF16A34A),
                    title: 'Unread Notifications',
                    count: _unreadNotifications,
                    countColor: const Color(0xFF16A34A),
                    onTap: () {
                      print('View notifications');
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // out of stock
                Expanded(
                  child: StatsCard(
                    icon: Icons.inventory_2_outlined,
                    iconBackgroundColor: const Color(0xFFF5F3FF),
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Out of Stock Items',
                    count: _outOfStockItems,
                    countColor: const Color(0xFF7C3AED),
                    onTap: () {
                      print('View out of stock');
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── 3 MIDDLE CARDS ──
            // ── 3 MIDDLE CARDS ──
IntrinsicHeight(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [

      // inventory summary
      Expanded(
        child: InventorySummaryCard(
          totalProducts: 120,
          inStock: 97,
          lowStock: 12,
          outOfStock: 3,
          onViewAll: () {
            print('View inventory');
          },
        ),
      ),

      const SizedBox(width: 16),

      // order status chart
      Expanded(
        child: OrderStatusCard(
          pending: _pending,
          confirmed: _confirmed,
          preparing: _preparing,
          shipped: _shipped,
          completed: _completed,
          cancelled: _cancelled,
          onViewAll: () {
            print('View orders');
          },
        ),
      ),

      const SizedBox(width: 16),

      // recent feedback
      Expanded(
        flex: 2,
        child: RecentFeedbackCard(
          feedbackItems: _recentFeedback,
          onViewAll: () {
            print('View feedback');
          },
        ),
      ),
    ],
  ),
),

            const SizedBox(height: 24),

            // ── PRIORITY TASKS ──
            const Text(
              'Priority Tasks',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),

            const SizedBox(height: 12),

            // priority tasks table
            CommonTable(
              headers: const [
                'Task',
                'Details',
                'Priority',
                'Due / Time',
                'Action',
              ],
              rows: _buildPriorityTaskRows(),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}