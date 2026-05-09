// Basic Flutter import
import 'package:flutter/material.dart';

// Riverpod import
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import our sidebar widget
import '../../widgets/admin/sidebar/admin_sidebar.dart';
// Import all admin screens
// These are the screens that will show
// on the right side when user clicks sidebar items
import 'dashboard/admin_dashboard_screen.dart';
import 'inventory/inventory_screen.dart';
//Sales
import 'sales/sales_screen.dart';

// ================================================
// ADMIN LAYOUT
//
// This is the WRAPPER for every admin screen
// Think of it as the "frame" of the admin panel
//
// It contains:
//   - Sidebar on the LEFT (always visible)
//   - Content on the RIGHT (changes based on
//     which sidebar item is selected)
//
// Every admin screen uses this layout
// So the sidebar is always there no matter
// which screen the admin is on
// ================================================
class AdminLayout extends ConsumerStatefulWidget {
  const AdminLayout({super.key});

  @override
  ConsumerState<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends ConsumerState<AdminLayout> {

  // ================================================
  // CURRENT INDEX
  // Tracks which sidebar item is selected
  //
  // 0 = Dashboard
  // 1 = Inventory
  // 2 = Sales
  // 3 = Feedback
  // 4 = Order Approval
  // 5 = Promotions
  // 6 = Notification
  // ================================================
  int _currentIndex = 0;

  // ================================================
  // GET CURRENT SCREEN
  // Returns the correct screen based on
  // which sidebar item is selected
  //
  // Think of this like a switch statement
  // If index is 0 → show Dashboard
  // If index is 1 → show Inventory
  // etc.
  // ================================================
  Widget _getCurrentScreen() {

    // Check which index is selected
    // and return the matching screen
    if (_currentIndex == 0) {
      return const AdminDashboardScreen();
    } else if (_currentIndex == 1) {
      return const InventoryScreen();
    } else if (_currentIndex == 2) {
      return const SalesScreen();
      return _buildComingSoon('Sales');
    } else if (_currentIndex == 3) {
      // TODO: Build Feedback screen later
      return _buildComingSoon('Feedback');
    } else if (_currentIndex == 4) {
      // TODO: Build Order Approval screen later
      return _buildComingSoon('Order Approval');
    } else if (_currentIndex == 5) {
      // TODO: Build Promotions screen later
      return _buildComingSoon('Promotions');
    } else if (_currentIndex == 6) {
      // TODO: Build Notification screen later
      return _buildComingSoon('Notification');
    } else {
      return const AdminDashboardScreen();
    }
  }

  // ================================================
  // BUILD COMING SOON
  // Temporary placeholder for screens
  // that are not built yet
  // Shows a simple "Coming Soon" message
  // so the app doesn't crash when user
  // clicks unbuilt sidebar items
  // ================================================
  Widget _buildComingSoon(String screenName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // Icon
          Icon(
            Icons.construction_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: 16),

          // Screen name
          Text(
            screenName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 8),

          // Coming soon message
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

      // Light grey background for the content area
      backgroundColor: Colors.grey.shade100,

      body: Row(
        children: [

          // ================================================
          // LEFT SIDE — SIDEBAR
          // Always visible on every admin screen
          // ================================================
          AdminSidebar(
            // Tell sidebar which item is currently selected
            currentIndex: _currentIndex,

            // When user taps a sidebar item
            // update _currentIndex to show the right screen
            onItemSelected: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),

          // ================================================
          // RIGHT SIDE — CONTENT AREA
          // Changes based on which sidebar item
          // is selected
          //
          // Expanded means it takes ALL remaining space
          // after the sidebar takes its 200px
          // ================================================
          Expanded(
            child: _getCurrentScreen(),
          ),

        ],
      ),
    );
  }
}