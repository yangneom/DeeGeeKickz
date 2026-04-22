// Basic Flutter import
import 'package:flutter/material.dart';

// Riverpod import
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Auth providers
import '../../../providers/auth/auth_provider.dart';

// ================================================
// ADMIN SIDEBAR WIDGET
//
// Left sidebar that appears on every admin screen
//
// Colors used:
//   #FFFFFF - white background
//   #9CA3AF - section label text
//   #6B7280 - nav item text + icons
//   #6F7680 - subtle text
//   Blue    - selected item highlight
// ================================================
class AdminSidebar extends ConsumerStatefulWidget {

  // Which sidebar item is currently selected
  final int currentIndex;

  // Function that runs when user taps a sidebar item
  final Function(int) onItemSelected;

  const AdminSidebar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  ConsumerState<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends ConsumerState<AdminSidebar> {

  // ================================================
  // HANDLE LOGOUT
  // ================================================
  Future<void> _handleLogout() async {

    try {

      final authService = ref.read(authServiceProvider);
      await authService.logout();

    } catch (error) {

      // If logout fails print the error
      // We still want to handle this gracefully
      print('Logout error: $error');

    }
  }

  // ================================================
  // BUILD SECTION LABEL
  // Small uppercase grey text above each group
  // Example: "OVERVIEW", "MANAGEMENT"
  // ================================================
  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 20,
        top: 24,
        bottom: 4,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          // #9CA3AF - light grey for section labels
          color: Color(0xFF9CA3AF),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ================================================
  // BUILD NAV ITEM
  // One clickable row in the sidebar
  // Shows icon + label
  // Blue left border + blue text when selected
  // Grey icon + grey text when not selected
  // ================================================
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {

    // Is this item currently selected?
    bool isSelected = widget.currentIndex == index;

    return GestureDetector(

      onTap: () {
        widget.onItemSelected(index);
      },

      child: Container(
        // Full width of sidebar
        width: double.infinity,

        margin: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 1,
        ),

        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),

        decoration: BoxDecoration(
          // Very light blue background when selected
          // Transparent when not selected
          color: isSelected
              ? const Color(0xFFEFF6FF)
              : Colors.transparent,

          borderRadius: BorderRadius.circular(6),

          // Blue left border when selected
          border: isSelected
              ? const Border(
                  left: BorderSide(
                    // Blue border
                    color: Color(0xFF2563EB),
                    width: 3,
                  ),
                )
              : null,
        ),

        child: Row(
          children: [

            // Icon
            Icon(
              icon,
              size: 17,
              // Blue when selected, #6B7280 grey when not
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF6B7280),
            ),

            const SizedBox(width: 10),

            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                // Semibold when selected, normal when not
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.w400,
                // Blue when selected, #6B7280 grey when not
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {

    // Get current logged in user for bottom user info
    final authState = ref.watch(authStateProvider);

    // Get user's email and display name
    String userEmail = '';
    String userName = '';

    authState.whenData((user) {
      if (user != null) {
        userEmail = user.email ?? '';
        // Display name if set, otherwise show email
        userName = user.displayName ?? userEmail;
      }
    });

    return Container(
      // Fixed sidebar width
      width: 210,

      // Full screen height
      height: double.infinity,

      // White background + right border
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ================================================
          // LOGO
          // Centered at the top with padding
          // ================================================
          Center(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 24,
                bottom: 8,
              ),
              child: Image.asset(
                'assets/images/logo.jpg',
                height: 64,
                width: 64,
              ),
            ),
          ),

          // ================================================
          // OVERVIEW SECTION
          // ================================================
          _buildSectionLabel('Overview'),

          _buildNavItem(
            index: 0,
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
          ),

          // ================================================
          // MANAGEMENT SECTION
          // ================================================
          _buildSectionLabel('Management'),

          _buildNavItem(
            index: 1,
            icon: Icons.inventory_2_outlined,
            label: 'Inventory',
          ),

          _buildNavItem(
            index: 2,
            icon: Icons.point_of_sale_outlined,
            label: 'Sales',
          ),

          _buildNavItem(
            index: 3,
            icon: Icons.chat_bubble_outline,
            label: 'Feedback',
          ),

          _buildNavItem(
            index: 4,
            icon: Icons.fact_check_outlined,
            label: 'Order Approval',
          ),

          _buildNavItem(
            index: 5,
            icon: Icons.local_offer_outlined,
            label: 'Promotions',
          ),

          // ================================================
          // NOTIFICATIONS SECTION
          // ================================================
          _buildSectionLabel('Notifications'),

          _buildNavItem(
            index: 6,
            icon: Icons.notifications_outlined,
            label: 'Notification',
          ),

          // ================================================
          // SPACER
          // Pushes logout + user info to the bottom
          // ================================================
          const Spacer(),

          // ================================================
          // LOGOUT BUTTON
          // Same style as nav items but no selection state
          // ================================================
          GestureDetector(
            onTap: _handleLogout,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 1,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    size: 17,
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ================================================
          // DIVIDER ABOVE USER INFO
          // ================================================
          Divider(
            color: Colors.grey.shade200,
            height: 1,
            thickness: 1,
          ),

          // ================================================
          // USER INFO AT THE BOTTOM
          // Avatar + "Hello" + user name
          // ================================================
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Row(
              children: [

                // Grey circle avatar with person icon
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(
                    Icons.person,
                    size: 18,
                    color: const Color(0xFF6B7280),
                  ),
                ),

                const SizedBox(width: 10),

                // Hello + name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // "Hello" label
                      const Text(
                        'Hello',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),

                      const SizedBox(height: 2),

                      // User name or email
                      // overflow means if too long show "..."
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
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