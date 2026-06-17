import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/customer_cart_item.dart';
import '../../../models/product_model.dart';
import '../../../providers/customer/customer_cart_provider.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/cart/cart_item_tile.dart';
import '../../../widgets/customer/cart/cart_summary_card.dart';

/// Shopping Bag / Cart screen.
/// Matches the HTML mockup: item list (left/full) + summary sidebar (right on desktop).
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  // Mock "You May Also Like" products pulled from existing mock data
  static final List<ProductModel> _suggested = [
    mockShopProducts[0],
    mockShopProducts[3],
    mockShopProducts[6],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(customerCartProvider);

    final subtotal =
        cartItems.fold(0.0, (sum, item) => sum + item.subtotal);

    final tax = subtotal * 0.08;

    final shipping = subtotal >= 150 ? 0.0 : 10.0;

    final total = subtotal + tax + shipping;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      appBar: const AppTopBar(activeRoute: 'shop'),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        onTap: (i) {
          if (i == 0) Navigator.of(context).popUntil((r) => r.isFirst);
        },
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 48 : 16,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: isDesktop
                        ? _DesktopLayout(
                            cartItems: cartItems,
                            suggested: _suggested,
                            subtotal: subtotal,
                            tax: tax,
                            shipping: shipping,
                            total: total,
                            onIncrement: (index) {
                              ref
                                  .read(customerCartProvider.notifier)
                                  .increment(index);
                            },
                            onDecrement: (index) {
                              ref
                                  .read(customerCartProvider.notifier)
                                  .decrement(index);
                            },
                            onRemove: (index) {
                              ref
                                  .read(customerCartProvider.notifier)
                                  .removeItem(index);
                            },
                          )
                        : _MobileLayout(
                            cartItems: cartItems,
                            suggested: _suggested,
                            subtotal: subtotal,
                            tax: tax,
                            shipping: shipping,
                            total: total,
                            onIncrement: (index) {
                              ref
                                  .read(customerCartProvider.notifier)
                                  .increment(index);
                            },
                            onDecrement: (index) {
                              ref
                                  .read(customerCartProvider.notifier)
                                  .decrement(index);
                            },
                            onRemove: (index) {
                              ref
                                  .read(customerCartProvider.notifier)
                                  .removeItem(index);
                            },
                          ),
                  ),
                ),
                const AppFooter(),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Desktop: two-column grid ─────────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final List<CustomerCartItem> cartItems;
  final List<ProductModel> suggested;
  final double subtotal, tax, shipping, total;
  final void Function(int) onIncrement, onDecrement, onRemove;

  const _DesktopLayout({
    required this.cartItems,
    required this.suggested,
    required this.subtotal,
    required this.tax,
    required this.shipping,
    required this.total,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: item list + suggestions (8/12 cols)
        Expanded(
          flex: 8,
          child: _CartItemList(
            cartItems: cartItems,
            suggested: suggested,
            onIncrement: onIncrement,
            onDecrement: onDecrement,
            onRemove: onRemove,
            showSuggested: true,
          ),
        ),
        const SizedBox(width: 80),
        // Right: summary (4/12 cols)
        Expanded(
          flex: 4,
          child: CartSummaryCard(
            subtotal: subtotal,
            shipping: shipping,
            tax: tax,
            total: total,
          ),
        ),
      ],
    );
  }
}

// ── Mobile: stacked ──────────────────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final List<CustomerCartItem> cartItems;
  final List<ProductModel> suggested;
  final double subtotal, tax, shipping, total;
  final void Function(int) onIncrement, onDecrement, onRemove;

  const _MobileLayout({
    required this.cartItems,
    required this.suggested,
    required this.subtotal,
    required this.tax,
    required this.shipping,
    required this.total,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CartItemList(
          cartItems: cartItems,
          suggested: suggested,
          onIncrement: onIncrement,
          onDecrement: onDecrement,
          onRemove: onRemove,
          showSuggested: false,
        ),
        const SizedBox(height: 32),
        CartSummaryCard(
          subtotal: subtotal,
          shipping: shipping,
          tax: tax,
          total: total,
        ),
      ],
    );
  }
}

// ── Shared item list + suggestions ───────────────────────────────────────────
class _CartItemList extends StatelessWidget {
  final List<CustomerCartItem> cartItems;
  final List<ProductModel> suggested;
  final void Function(int) onIncrement, onDecrement, onRemove;
  final bool showSuggested;

  const _CartItemList({
    required this.cartItems,
    required this.suggested,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.showSuggested,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page title
        const Text(
          'YOUR BAG',
          style: TextStyle(
            fontFamily: 'Archivo Narrow',
            fontSize: 48,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 32),

        // Empty state
        if (cartItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                'YOUR BAG IS EMPTY',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                  color: Color(0xFF656464),
                ),
              ),
            ),
          ),

        // Item tiles
        ...List.generate(
          cartItems.length,
          (i) => CartItemTile(
            item: cartItems[i],
            onRemove: () => onRemove(i),
            onIncrement: () => onIncrement(i),
            onDecrement: () => onDecrement(i),
          ),
        ),

        // You May Also Like (desktop only)
        if (showSuggested && suggested.isNotEmpty) ...[
          const SizedBox(height: 80),
          const Text(
            'YOU MAY ALSO LIKE',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggested.length,
              separatorBuilder: (_, __) => const SizedBox(width: 24),
              itemBuilder: (context, i) {
                final p = suggested[i];
                return SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          color: const Color(0xFFEEEEEE),
                          child: Image.network(
                            p.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.image_not_supported_outlined,
                                  color: Color(0xFF9E9E9E)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.name.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.7,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.formattedPrice,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF656464),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}