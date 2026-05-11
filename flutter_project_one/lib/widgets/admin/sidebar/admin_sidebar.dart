import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth/auth_provider.dart';

// ================================================
// ADMIN SIDEBAR
//
// Left sidebar that appears on every admin screen
// Contains navigation items only
// Profile and notification moved to top bar!
// ================================================
class AdminSidebar extends ConsumerStatefulWidget {

  // which sidebar item is currently selected
  final int currentIndex;

  // function that runs when user taps a sidebar item
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
      print('Logout error: $error');
    }
  }

  // ================================================
  // BUILD SECTION LABEL
  // small gray text above each group
  // example: "OVERVIEW", "MANAGEMENT"
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
          color: Color(0xFF9CA3AF),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ================================================
  // BUILD NAV ITEM
  // one clickable row in the sidebar
  // shows icon + label
  // blue when selected, gray when not selected
  // ================================================
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {

    // check if this item is currently selected
    bool isSelected = widget.currentIndex == index;

    return GestureDetector(

      // when user taps this item
      onTap: () {
        widget.onItemSelected(index);
      },

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
        decoration: BoxDecoration(

          // light blue background if selected
          // transparent if not selected
          color: isSelected == true
              ? const Color(0xFFEFF6FF)
              : Colors.transparent,

          borderRadius: BorderRadius.circular(6),

          // blue left border if selected
          // no border if not selected
          border: isSelected == true
              ? const Border(
                  left: BorderSide(
                    color: Color(0xFF2563EB),
                    width: 3,
                  ),
                )
              : null,
        ),

        child: Row(
          children: [

            // icon — blue if selected, gray if not
            Icon(
              icon,
              size: 17,
              color: isSelected == true
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF6B7280),
            ),

            const SizedBox(width: 10),

            // label — blue if selected, gray if not
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected == true
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: isSelected == true
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

    return Container(
      // fixed sidebar width
      width: 210,

      // full screen height
      height: double.infinity,

      // white background with right border
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

          // ── LOGO ──
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

          // ── OVERVIEW SECTION ──
          _buildSectionLabel('Overview'),

          _buildNavItem(
            index: 0,
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
          ),

          // ── MANAGEMENT SECTION ──
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
            icon: Icons.message_outlined,
            label: 'Messages',
          ),

          _buildNavItem(
            index: 5,
            icon: Icons.fact_check_outlined,
            label: 'Order Approval',
          ),

          _buildNavItem(
            index: 6,
            icon: Icons.local_offer_outlined,
            label: 'Promotions',
          ),

          // ── NOTIFICATIONS SECTION ──
          _buildSectionLabel('Notifications'),

          _buildNavItem(
            index: 7,
            icon: Icons.notifications_outlined,
            label: 'Notification',
          ),

          // ── SPACER ──
          // pushes logout to bottom but not too far
          const Spacer(),

          // ── DIVIDER above logout ──
          Divider(
            color: Colors.grey.shade200,
            height: 1,
            thickness: 1,
          ),

          // ── LOGOUT BUTTON ──
          GestureDetector(
            onTap: () {
              _handleLogout();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              child: Row(
                children: [

                  // logout icon
                  const Icon(
                    Icons.logout,
                    size: 17,
                    color: Color(0xFF6B7280),
                  ),

                  const SizedBox(width: 10),

                  // logout text
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

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}