import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/customer_cart_item.dart';
import '../../../models/product.dart';
import '../../../models/product_model.dart';
import '../../../providers/customer/customer_cart_provider.dart';
import '../../../providers/product/product_provider.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/cart/cart_item_tile.dart';
import '../../../widgets/customer/cart/cart_summary_card.dart';

/// Shopping Bag / Cart screen.
/// Matches the HTML mockup: item list (left/full) + summary sidebar (right on desktop).
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  // Mock "You May Also Like" products pulled from existing mock data
  static final List<ProductModel> _suggested = [
    mockShopProducts[0],
    mockShopProducts[3],
    mockShopProducts[6],
  ];

  @override
  void initState() {
    super.initState();
    // Stock may have changed since these items were added (another
    // order approved, a cashier sale, etc.) — refresh on open so the
    // per-item stock cap enforced below is never stale.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(productsProvider);
    });
  }

  /// Looks up the real, current available stock for a cart item by
  /// matching productId + sizeId against live product data. Returns
  /// null if the product/size can no longer be found at all (e.g.
  /// archived) — callers should treat null as "can't verify, block
  /// increment" rather than assuming unlimited stock.
  int? _availableQtyFor(CustomerCartItem item, List<Product> products) {
    final Product? product = products.cast<Product?>().firstWhere(
          (p) => p!.productId == item.productId.toString(),
          orElse: () => null,
        );
    if (product == null) return null;

    final ProductVariant? variant = product.variants.cast<ProductVariant?>().firstWhere(
          (v) => v!.color == item.color,
          orElse: () => null,
        );
    if (variant == null) return null;

    final SizeEntry? sizeEntry = variant.sizes.cast<SizeEntry?>().firstWhere(
          (s) => s!.sizeId == item.sizeId,
          orElse: () => null,
        );
    if (sizeEntry == null) return null;

    return sizeEntry.availableQty;
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(customerCartProvider);
    final productsAsync = ref.watch(productsProvider);
    final List<Product> products = productsAsync.value ?? [];

    final subtotal =
        cartItems.fold(0.0, (sum, item) => sum + item.subtotal);

    // NOTE: shipping/total are no longer calculated on this screen.
    // Real shipping fee is only known at checkout (once an address
    // is picked), so this screen only ever shows the subtotal.

    void handleIncrement(int index) {
      final CustomerCartItem item = cartItems[index];
      final int? available = _availableQtyFor(item, products);

      // null = couldn't verify (product/size not found) — block
      // rather than silently allowing an unlimited increase.
      final int cap = available ?? item.quantity;

      if (item.quantity >= cap) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              available == null
                  ? 'Unable to verify stock for this item right now.'
                  : 'Only $available available for this size.',
            ),
            backgroundColor: Colors.black,
          ),
        );
        return;
      }

      ref.read(customerCartProvider.notifier).increment(index);
    }

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
                            onIncrement: handleIncrement,
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
                            onIncrement: handleIncrement,
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
  final double subtotal;
  final void Function(int) onIncrement, onDecrement, onRemove;

  const _DesktopLayout({
    required this.cartItems,
    required this.suggested,
    required this.subtotal,
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
            isCartEmpty: cartItems.isEmpty,
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
  final double subtotal;
  final void Function(int) onIncrement, onDecrement, onRemove;

  const _MobileLayout({
    required this.cartItems,
    required this.suggested,
    required this.subtotal,
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
          isCartEmpty: cartItems.isEmpty,
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