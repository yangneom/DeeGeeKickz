import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/admin/sidebar/admin_sidebar.dart';
import '../../widgets/admin/topbar/admin_top_bar.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'inventory/inventory_screen.dart';
import 'sales/sales_screen.dart';

// ================================================
// ADMIN LAYOUT
//
// This is the WRAPPER for every admin screen
//
// It now has 3 parts:
//   1. TOP BAR    — notification + profile
//   2. SIDEBAR    — navigation items on the left
//   3. CONTENT    — the actual screen on the right
//
// Layout looks like this:
//
// ┌─────────────────────────────────┐
// │         TOP BAR          🔔 👤 │
// ├─────────┬───────────────────────┤
// │         │                       │
// │ SIDEBAR │      CONTENT          │
// │         │                       │
// └─────────┴───────────────────────┘
// ================================================
class AdminLayout extends ConsumerStatefulWidget {
  const AdminLayout({super.key});

  @override
  ConsumerState<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends ConsumerState<AdminLayout> {

  // ================================================
  // CURRENT INDEX
  // tracks which sidebar item is selected
  //
  // 0 = Dashboard
  // 1 = Inventory
  // 2 = Sales
  // 3 = Feedback
  // 4 = Messages
  // 5 = Order Approval
  // 6 = Promotions
  // 7 = Notification
  // ================================================
  int _currentIndex = 0;

  // ================================================
  // GET CURRENT SCREEN
  // returns the correct screen based on
  // which sidebar item is selected
  // ================================================
  Widget _getCurrentScreen() {

    // check which index is selected
    if (_currentIndex == 0) {
      return const AdminDashboardScreen();
    }

    if (_currentIndex == 1) {
      return const InventoryScreen();
    }

    if (_currentIndex == 2) {
      return const SalesScreen();
    }

    if (_currentIndex == 3) {
      return _buildComingSoon('Feedback');
    }

    if (_currentIndex == 4) {
      return _buildComingSoon('Messages');
    }

    if (_currentIndex == 5) {
      return _buildComingSoon('Order Approval');
    }

    if (_currentIndex == 6) {
      return _buildComingSoon('Promotions');
    }

    if (_currentIndex == 7) {
      return _buildComingSoon('Notification');
    }

    // default — show dashboard
    return const AdminDashboardScreen();
  }

  // ================================================
  // BUILD COMING SOON
  // temporary placeholder for screens
  // that are not built yet
  // ================================================
  Widget _buildComingSoon(String screenName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // construction icon
          Icon(
            Icons.construction_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: 16),

          // screen name
          Text(
            screenName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 8),

          // coming soon message
          Text(
            'This screen is coming soon',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      // Column because we stack TOP BAR above
      // then SIDEBAR + CONTENT side by side below
      body: Column(
        children: [

          // ── TOP BAR ──
          // always visible at the very top
          const AdminTopBar(),

          // ── SIDEBAR + CONTENT ──
          // Expanded means it takes all remaining space
          // below the top bar
          Expanded(
            child: Row(
              children: [

                // sidebar on the LEFT
                AdminSidebar(
                  currentIndex: _currentIndex,
                  onItemSelected: (int index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                ),

                // content on the RIGHT
                // Expanded means it takes all remaining space
                // after the sidebar
                Expanded(
                  child: _getCurrentScreen(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}