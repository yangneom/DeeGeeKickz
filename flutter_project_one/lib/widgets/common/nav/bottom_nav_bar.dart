import 'package:flutter/material.dart';

import '../../../screens/customer/cart/cart_screen.dart';
import '../../../screens/customer/search/search_screen.dart';
import '../../../screens/customer/orders/order_history_screen.dart';
import '../../../screens/customer/profile/profile_screen.dart';
import '../../../core/utils/auth_gate.dart';

/// Bottom navigation bar shown ONLY on mobile widths (< 768px).
///
/// Index map:
///   0 → Home      → pops to root
///   1 → Search    → SearchScreen
///   2 → Bag       → CartScreen
///   3 → Orders    → OrderHistoryScreen
///   4 → Profile   → ProfileScreen
///
/// All navigation is now handled internally — pass currentIndex only.
/// Pass currentIndex: -1 on screens that don't correspond to any tab
/// (e.g. ShopScreen) so nothing is falsely highlighted.
///
/// Self-hides (returns SizedBox.shrink) on desktop/tablet.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const BottomNavBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  static const double _mdBreakpoint = 768;

  static bool shouldShow(BuildContext context) =>
      MediaQuery.of(context).size.width < _mdBreakpoint;

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_outlined,           label: 'Home'),
    _NavItem(icon: Icons.search,                  label: 'Search'),
    _NavItem(icon: Icons.shopping_bag_outlined,   label: 'Bag'),
    _NavItem(icon: Icons.receipt_long_outlined,   label: 'Orders'),
    _NavItem(icon: Icons.person_outline,          label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _mdBreakpoint) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFFF9F9F9),
            border: Border(
              top: BorderSide(color: Color(0xFFCFC4C5), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final item     = _items[index];
              final isActive = index == currentIndex;

              return InkWell(
                onTap: () {
                  switch (index) {
                    case 0: // Home
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      break;
                    case 1: // Search
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SearchScreen()),
                      );
                      break;
                    case 2: // Bag
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const CartScreen()),
                      );
                      break;
                    case 3: // Orders
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const OrderHistoryScreen()),
                      );
                      break;
                    case 4: // Profile
                      requireAuth(context, const ProfileScreen());
                      break;
                    default:
                      onTap?.call(index);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: isActive ? 26 : 24,
                        color: isActive
                            ? Colors.black
                            : const Color(0xFF656464),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isActive
                              ? Colors.black
                              : const Color(0xFF656464),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}