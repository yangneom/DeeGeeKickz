import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../screens/auth/login_screen.dart';

// ================================================
// CASHIER SIDEBAR
//
// Left navigation panel for the cashier layout
//
// Items:
//   0 = Cashier (POS)
//   1 = Inventory (view only)
//   Logout at the bottom
// ================================================
class CashierSidebar extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onItemSelected;

  const CashierSidebar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 200,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── LOGO ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Image.asset(
              'assets/images/logo.jpg',
              height: 60,
              width: 60,
            ),
          ),

          // ── SECTION LABEL: Cashier ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(
              'Cashier',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // ── POS NAV ITEM ──
          _buildNavItem(
            index: 0,
            icon: Icons.lock_outline,
            label: 'Cashier',
          ),

          // ── SECTION LABEL: Management ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Text(
              'Management',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // ── INVENTORY NAV ITEM ──
          _buildNavItem(
            index: 1,
            icon: Icons.inventory_2_outlined,
            label: 'Inventory',
          ),

          // Spacer pushes logout to the bottom
          const Spacer(),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 8),

          // ── LOGOUT ──
          _buildLogoutItem(context, ref),

          const SizedBox(height: 20),
        ],
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
    final bool isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onItemSelected(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF374151),
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
        final authService = ref.read(authServiceProvider);
        await authService.logout();
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: const [
            Icon(
              Icons.logout,
              size: 18,
              color: Color(0xFF6B7280),
            ),
            SizedBox(width: 10),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}