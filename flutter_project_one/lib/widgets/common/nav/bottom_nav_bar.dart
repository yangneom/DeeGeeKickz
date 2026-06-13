import 'package:flutter/material.dart';
import '../../../screens/customer/cart/cart_screen.dart';
import '../../../screens/customer/messages/customer_chat_screen.dart';

/// Bottom navigation bar shown ONLY on mobile widths.
///
/// Matches HTML:
/// <nav class="fixed bottom-0 w-full z-50 md:hidden bg-surface
///   border-t border-outline-variant flex justify-around items-center h-16 ...">
///   home / search / shopping_bag / chat / person
/// </nav>
///
/// This widget self-hides (returns SizedBox.shrink) when the available
/// width is >= the md breakpoint (768px), matching `md:hidden`.
/// Each screen should still wrap this in a way that doesn't reserve
/// space on desktop -- e.g. place it in a `bottomNavigationBar:` slot
/// with a LayoutBuilder, or use [BottomNavBar.shouldShow] to decide.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const BottomNavBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  static const double _mdBreakpoint = 768;

  /// Helper for screens to decide whether to even build this widget.
  static bool shouldShow(BuildContext context) {
    return MediaQuery.of(context).size.width < _mdBreakpoint;
  }

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home, label: 'Home'),
    _NavItem(icon: Icons.search, label: 'Search'),
    _NavItem(icon: Icons.shopping_bag_outlined, label: 'Bag'),
    _NavItem(icon: Icons.chat_bubble_outline, label: 'Chat'),
    _NavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _mdBreakpoint) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 64, // h-16
          decoration: const BoxDecoration(
            color: Color(0xFFF9F9F9), 
            border: Border(
              top: BorderSide(color: Color(0xFFCFC4C5), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isActive = index == currentIndex;

              return InkWell(
                onTap: () {
                  if (index == 2) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  } else if (index == 3) {  
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CustomerChatScreen()),
                    );
                  } else {
                    onTap?.call(index);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Icon(
                    item.icon,
                    size: isActive ? 26 : 24, // scale-110 on active item
                    color: isActive
                        ? Colors.black // text-primary
                        : const Color(0xFF656464), // on-secondary-container
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