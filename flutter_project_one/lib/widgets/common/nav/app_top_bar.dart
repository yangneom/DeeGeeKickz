import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../screens/auth/login_screen.dart';
import '../../../core/utils/auth_gate.dart';

import '../../../screens/customer/shop_screen.dart/shop_screen.dart';
import '../../../screens/customer/promo/promo_screen.dart';
import '../../../screens/customer/cart/cart_screen.dart';
import '../../../screens/customer/profile/profile_screen.dart';
import '../../../screens/customer/search/search_screen.dart';
import '../../../screens/customer/notifications/notifications_screen.dart';
import '../../../providers/customer/customer_cart_provider.dart';
import '../../../providers/customer/notification_provider.dart';

/// Responsive top navigation bar shared across all customer-web screens.
///
/// Mobile layout is now: hamburger — logo — (nothing on the right).
/// Search, Bag, Orders, and Profile all live in BottomNavBar on mobile,
/// so duplicating Search/Bag icons here was redundant and has been removed.
/// Desktop keeps its full icon row since there's no bottom nav there.
class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final String activeRoute;
  final VoidCallback? onMenuTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onBagTap;
  final VoidCallback? onPersonTap;
  final VoidCallback? onNotificationsTap;

  const AppTopBar({
    super.key,
    this.activeRoute = 'home',
    this.onMenuTap,
    this.onSearchTap,
    this.onBagTap,
    this.onPersonTap,
    this.onNotificationsTap,
  });

  static const double _navHeight    = 64;
  static const double _mdBreakpoint = 768;

  @override
  Size get preferredSize => const Size.fromHeight(_navHeight);

  void _onNavTap(BuildContext context, String route) {
    if (route == activeRoute) return;
    switch (route) {
      case 'shop':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ShopScreen()),
        );
        break;
      case 'promo':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PromoScreen()),
        );
        break;
      case 'home':
        Navigator.of(context).popUntil((r) => r.isFirst);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(customerCartProvider.select(
      (items) => items.fold<int>(0, (sum, i) => sum + i.quantity),
    ));
    final unreadCount = ref.watch(notificationProvider).unreadCount;

    return Container(
      height: _navHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9).withOpacity(0.9),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFCFC4C5), width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= _mdBreakpoint;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 48 : 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ── Left ──────────────────────────────────
                    Row(
                      children: [
                        if (!isDesktop)
                          _IconButton(
                            icon: Icons.menu,
                            onTap: onMenuTap ??
                                () => Scaffold.of(context).openDrawer(),
                          ),
                        if (isDesktop) ...[
                          _NavLink(
                            label: 'Home',
                            isActive: activeRoute == 'home',
                            onTap: () => _onNavTap(context, 'home'),
                          ),
                          const SizedBox(width: 24),
                          _NavLink(
                            label: 'Shop',
                            isActive: activeRoute == 'shop',
                            onTap: () => _onNavTap(context, 'shop'),
                          ),
                          const SizedBox(width: 24),
                          _NavLink(
                            label: 'Promo',
                            isActive: activeRoute == 'promo',
                            onTap: () => _onNavTap(context, 'promo'),
                          ),
                        ],
                      ],
                    ),

                    // ── Logo ──────────────────────────────────
                    const Text(
                      'DEEGEEKICKZ',
                      style: TextStyle(
                        fontFamily: 'Archivo Narrow',
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        color: Colors.black,
                      ),
                    ),

                    // ── Right ─────────────────────────────────
                    // Desktop only: mobile gets Search/Bag/Orders/Profile
                    // from BottomNavBar, so nothing is duplicated here.
                    Row(
                      children: [
                        if (isDesktop) ...[
                          _IconButton(
                            icon: Icons.notifications_outlined,
                            showBadge: unreadCount > 0,
                            onTap: onNotificationsTap ??
                                () => requireAuth(
                                      context,
                                      const NotificationsScreen(),
                                    ),
                          ),
                          const SizedBox(width: 24),

                          _IconButton(
                            icon: Icons.search,
                            onTap: onSearchTap ??
                                () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const SearchScreen(),
                                      ),
                                    ),
                          ),
                          const SizedBox(width: 24),

                          _IconButton(
                            icon: Icons.shopping_bag_outlined,
                            showBadge: cartCount > 0,
                            onTap: onBagTap ??
                                () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const CartScreen(),
                                      ),
                                    ),
                          ),
                          const SizedBox(width: 24),

                          _IconButton(
                            icon: Icons.person_outline,
                            onTap: onPersonTap ??
                                () => requireAuth(
                                      context,
                                      const ProfileScreen(),
                                    ),
                          ),
                        ],
                        // Mobile: intentionally empty. Search, Bag, Orders,
                        // and Profile all live in BottomNavBar already.
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Nav link ─────────────────────────────────────────────────────────────────

class _NavLink extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavLink({
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 2),
        decoration: isActive
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.black, width: 2),
                ),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
            color: isActive ? Colors.black : const Color(0xFF656464),
          ),
        ),
      ),
    );
  }
}

// ─── Icon button ──────────────────────────────────────────────────────────────

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool showBadge;

  const _IconButton({
    required this.icon,
    this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: Colors.black, size: 24),
            if (showBadge)
              Positioned(
                top: -1,
                right: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBA1A1A),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF9F9F9),
                      width: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}