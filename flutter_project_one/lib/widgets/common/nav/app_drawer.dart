import 'package:flutter/material.dart';

import '../../../screens/customer/promo/promo_screen.dart';
import '../../../screens/customer/messages/customer_chat_screen.dart';

/// Shared navigation drawer shown on mobile widths.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
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
                    showBadge: true,
                    onTap: () => Navigator.of(context).pop(),
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
              onTap: () => Navigator.of(context).pop(),
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