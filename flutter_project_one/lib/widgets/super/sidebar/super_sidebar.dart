import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/customer/customer_cart_provider.dart';
import '../../../screens/auth/login_screen.dart';
import '../../common/dialog/logout_confirm.dart';

// ================================================
// SUPER ADMIN SIDEBAR
//
// Left navigation panel for the super admin layout
//
// Sections:
//   Overview
//     0 = Dashboard
//   Account Management
//     1 = Admin        final cartNotifier = ref.read(customerCartProvider.notifier);
//     2 = Customer
//   Reports
//     3 = Sales Report
//   Feedback
//     4 = Feedback Management
//   Notifications
//     5 = Notification
//   Audit
//     6 = Activity Log
// ================================================
class SuperSidebar extends ConsumerWidget {

  final int currentIndex;
  final Function(int) onItemSelected;

  const SuperSidebar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 210,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
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
              padding: const EdgeInsets.only(top: 24, bottom: 8),
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

          // ── ACCOUNT MANAGEMENT SECTION ──
          _buildSectionLabel('Account Management'),

          _buildNavItem(
            index: 1,
            icon: Icons.admin_panel_settings_outlined,
            label: 'Admin',
          ),

          _buildNavItem(
            index: 2,
            icon: Icons.people_outline,
            label: 'Customer',
          ),

          // ── REPORTS SECTION ──
          _buildSectionLabel('Reports'),

          _buildNavItem(
            index: 3,
            icon: Icons.bar_chart_outlined,
            label: 'Sales Report',
          ),

          // ── FEEDBACK SECTION ──
          _buildSectionLabel('Feedback'),

          _buildNavItem(
            index: 4,
            icon: Icons.chat_bubble_outline,
            label: 'Feedback Management',
          ),
          // AUDIT REMOVE: Notifications is now accessed via the
          // top-bar bell (with a quick-preview popover) rather than
          // duplicated here. The screen itself (index 5) is untouched
          // and still reachable — "See All" in the popover navigates
          // to it directly, reusing the exact same route.

          // ── AUDIT SECTION ──
          _buildSectionLabel('Audit'),

          _buildNavItem(
            index: 6,
            icon: Icons.receipt_long_outlined,
            label: 'Activity Log',
          ),

          // ── SPACER — pushes logout to bottom ──
          const Spacer(),

          Divider(
            color: Colors.grey.shade200,
            height: 1,
            thickness: 1,
          ),

          // ── LOGOUT ──
          _buildLogoutItem(context, ref),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ================================================
  // BUILD SECTION LABEL
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
  // ================================================
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    bool isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onItemSelected(index),
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
          color: isSelected
              ? const Color(0xFFEFF6FF)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
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
            Icon(
              icon,
              size: 17,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // BUILD LOGOUT ITEM
  // ================================================
 Widget _buildLogoutItem(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        // Grab everything from `ref` BEFORE any `await` — once we cross
        // an async gap, this widget may have rebuilt/unmounted, making
        // `ref` unsafe to read again.
        final authService = ref.read(authServiceProvider);
                final cartNotifier = ref.read(customerCartProvider.notifier);

        // Ask for confirmation first. Cancel (or tapping outside the
        // dialog) stops here and the user stays logged in.
        if (!await confirmLogout(context)) return;

        try {
          await authService.logout();
          cartNotifier.clearLocalOnly();

          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        } catch (error) {
          print('Logout error: $error');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Logout failed. Please try again.')),
            );
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        child: Row(
          children: const [
            Icon(
              Icons.logout,
              size: 17,
              color: Color(0xFF6B7280),
            ),
            SizedBox(width: 10),
            Text(
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
    );
  }
}