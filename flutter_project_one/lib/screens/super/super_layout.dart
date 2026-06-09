import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/super/sidebar/super_sidebar.dart';
import '../../widgets/super/topbar/super_top_bar.dart';
import 'dashboard/super_dashboard_screen.dart';
import 'admin_management/admin_management_screen.dart';
import 'admin_management/customer_management_screen.dart';
import '../super/sales/sales_report_screen.dart';                  // ← FIXED
import 'activity_log/activity_log_screen.dart';
import '../../screens/admin/feedback/feedback_screen.dart';


// ================================================
// SUPER ADMIN LAYOUT
//
// Wrapper for the super admin role
// Same structure as AdminLayout and CashierLayout
//
// ┌─────────────────────────────────┐
// │         TOP BAR          🔔 👤 │
// ├─────────┬───────────────────────┤
// │         │                       │
// │ SIDEBAR │      CONTENT          │
// │         │                       │
// └─────────┴───────────────────────┘
//
// Indexes:
//   0 = Dashboard
//   1 = Admin Accounts
//   2 = Customer Accounts  ← NOW WIRED
//   3 = Sales Report
//   4 = Feedback Management
//   5 = Notification
//   6 = Activity Log
// ================================================
class SuperLayout extends ConsumerStatefulWidget {
  const SuperLayout({super.key});

  @override
  ConsumerState<SuperLayout> createState() => _SuperLayoutState();
}

class _SuperLayoutState extends ConsumerState<SuperLayout> {

  // tracks which sidebar item is selected
  int _currentIndex = 0;

  // ================================================
  // GET CURRENT SCREEN
  // ================================================
  Widget _getCurrentScreen() {

    if (_currentIndex == 0) {
      return const SuperDashboardScreen();
    }

    if (_currentIndex == 1) {
      return const AdminManagementScreen();
    }

    // customer accounts — now wired!
    if (_currentIndex == 2) {
      return const CustomerManagementScreen();
    }

    if (_currentIndex == 3) {
      return const SalesReportScreen();
    }

    if (_currentIndex == 4) {
      return const FeedbackScreen();    
    }

    if (_currentIndex == 5) {
      return _buildComingSoon('Notification');
    }

    if (_currentIndex == 6) {
       return const ActivityLogScreen();
    }

    // default
    return const SuperDashboardScreen();
  }

  // ================================================
  // BUILD COMING SOON
  // ================================================
  Widget _buildComingSoon(String screenName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            screenName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
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
      body: Row(
        children: [

          // ── SIDEBAR on the LEFT ──
          SuperSidebar(
            currentIndex: _currentIndex,
            onItemSelected: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),

          // ── RIGHT SIDE — TOP BAR + CONTENT ──
          Expanded(
            child: Column(
              children: [

                // top bar
                const SuperTopBar(),

                // content
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