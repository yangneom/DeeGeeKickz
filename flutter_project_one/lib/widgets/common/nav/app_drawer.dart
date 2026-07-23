import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../screens/customer/promo/promo_screen.dart';
import '../../../screens/customer/messages/customer_chat_screen.dart';
import '../../../screens/customer/notifications/notifications_screen.dart';
import '../../../screens/auth/login_screen.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/customer/notification_provider.dart';
import '../../../providers/customer/customer_cart_provider.dart';

/// Shared navigation drawer shown on mobile widths.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationProvider).unreadCount;

    return Drawer(
      backgroundColor: const Color(0xFFF9F9F9),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'DEEGEEKICKZ',
                    style: TextStyle(
                      fontFamily: 'Archivo Narrow',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFCFC4C5)),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Promo — navigates to PromoScreen
                  _DrawerItem(
                    icon: Icons.local_offer_outlined,
                    label: 'Promo',
                    onTap: () {
                      Navigator.of(context).pop(); // close drawer first
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PromoScreen()),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    showBadge: unreadCount > 0,
                    onTap: () {
                      Navigator.of(context).pop(); // close drawer first
                      requireAuth(context, const NotificationsScreen());
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.support_agent_outlined,
                    label: 'Contact Us',
                    onTap: () {
                      Navigator.of(context).pop(); // close drawer first
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CustomerChatScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFCFC4C5)),

            _DrawerItem(
              icon: Icons.logout,
              label: 'Logout',
              onTap: () async {
                Navigator.of(context).pop(); // close drawer first
                await ref.read(authServiceProvider).logout();
                // Clear any locally-held guest cart so a fresh guest
                // session doesn't inherit the previous account's cart.
                await ref.read(customerCartProvider.notifier).clearLocalOnly();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showBadge;
  final VoidCallback? onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.showBadge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Stack(
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
      title: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.7,
          color: Colors.black,
        ),
      ),
    );
  }
}