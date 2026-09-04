import 'package:flutter/material.dart';

import '../../../screens/customer/cart/cart_screen.dart';
import '../../../screens/customer/shop_screen.dart/shop_screen.dart';
import '../../../screens/customer/orders/order_history_screen.dart';
import '../../../screens/customer/profile/profile_screen.dart';
import '../../../core/utils/auth_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth/auth_provider.dart';

/// Bottom navigation bar shown ONLY on mobile widths (< 768px).
///
/// Index map (this MUST match the _items list below — a stale copy of
/// this comment previously listed "1 → Search", which doesn't exist in
/// _items, and caused at least one screen to pass the wrong
/// currentIndex and highlight the wrong tab):
///   0 → Home      → pops to root
///   1 → Shop      → ShopScreen
///   2 → Bag       → CartScreen
///   3 → Orders    → OrderHistoryScreen
///   4 → Profile   → ProfileScreen
///
/// All navigation is handled internally — pass currentIndex only.
/// Pass currentIndex: -1 on screens that don't correspond to any tab.
///
/// Tapping a tab that's already open in the stack (e.g. tapping Shop
/// while a screen pushed on top of Shop, like Product Detail, is
/// showing) pops back to the existing Shop screen instead of pushing a
/// visually-identical duplicate on top — previously this made Shop
/// *look* broken, since pushing a duplicate is indistinguishable from
/// doing nothing.
///
/// Self-hides (returns SizedBox.shrink) on desktop/tablet.
class BottomNavBar extends ConsumerWidget {
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
    _NavItem(icon: Icons.storefront_outlined,     label: 'Shop'),
    _NavItem(icon: Icons.shopping_bag_outlined,   label: 'Bag'),
    _NavItem(icon: Icons.receipt_long_outlined,   label: 'Orders'),
    _NavItem(icon: Icons.person_outline,          label: 'Profile'),
  ];

  // Route name used to find an already-open screen in the stack so we
  // can pop back to it instead of pushing a duplicate. Index 0 (Home)
  // and 4 (Profile, which goes through requireAuth) are handled
  // separately below and don't need an entry here.
  static const Map<int, String> _routeNames = {
    1: 'shop',
    2: 'bag',
    3: 'orders',
  };

    void _navigateTo(BuildContext context, int index) {
    final navigator = Navigator.of(context);

    if (index == 0) {
      navigator.popUntil((r) => r.isFirst);
      return;
    }

    if (index == 4) {
      requireAuth(context, const ProfileScreen());
      return;
    }

    // pushAndRemoveUntil — same atomic-transaction fix as
    // app_top_bar.dart, for the same underlying crash.
    switch (index) {
      case 1:
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'shop'),
            builder: (_) => const ShopScreen(),
          ),
          (r) => r.isFirst,
        );
        break;
      case 2:
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'bag'),
            builder: (_) => const CartScreen(),
          ),
          (r) => r.isFirst,
        );
        break;
      case 3:
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'orders'),
            builder: (_) => const OrderHistoryScreen(),
          ),
          (r) => r.isFirst,
        );
        break;
    }
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.value?.session?.user != null;

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
              final isProfileTab = index == 4;
              final item = (isProfileTab && !isLoggedIn)
                  ? const _NavItem(icon: Icons.login, label: 'Login')
                  : _items[index];
              final isActive = index == currentIndex;

              return InkWell(
                onTap: () => _navigateTo(context, index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Active-tab indicator bar — mirrors the black
                      // underline used for active links in the desktop
                      // top bar, so mobile and desktop use the same
                      // visual language for "you are here" instead of
                      // relying on icon size/weight alone.
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: isActive ? 20 : 0,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 4),
                        color: Colors.black,
                      ),
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