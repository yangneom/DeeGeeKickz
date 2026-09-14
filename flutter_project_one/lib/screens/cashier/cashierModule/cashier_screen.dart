import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../models/sale.dart';
import '../../../widgets/cashier/inventory/select_variant_dialog.dart';
import '../../../widgets/cashier/receipt/receipt_dialog.dart';
import '../../../providers/product/product_provider.dart';
import '../../../providers/cashier_provider/cashier_provider.dart';
import '../../../models/cart_item.dart';
import '../../../widgets/common/buttons/search_bar.dart';
import '../../../services/admin/cashier/cashier_sale_service.dart';
import '../../../models/order.dart';
import '../../../services/customer/receipt/receipt_pdf_service.dart';

import '../../../services/cashier/onlinepayment/cashier_online_payment_service.dart';
import '../../../widgets/cashier/receipt/qr_payment_dialog.dart';
import '../../../widgets/common/dialog/confirm_dialog.dart';
import '../../../widgets/cashier/receipt/reference_number_dialog.dart';
import '../../../models/order.dart';
import '../../../services/customer/receipt/receipt_pdf_service.dart';

// ================================================
// CASHIER SCREEN
//
// Layout:
//   LEFT  → Search bar + Product grid
//   RIGHT → Cart panel + Payment + Checkout
//
// PAYMENT FLOW:
//   Cash    → Print Receipt button
//              ↓
//             Save to fakeSales immediately
//              ↓
//             Show receipt dialog (Print / Save PDF / Close)
//
//   Online  → Checkout button → PayMongo placeholder
//              ↓ Mark Paid
//             Save to fakeSales immediately
//              ↓
//             Show receipt dialog (Print / Save PDF / Close)
//
// NOTE: Sale is ALWAYS saved on payment confirmation.
//       Printing is optional — closing receipt does
//       NOT cancel or undo the sale.
//
// RESERVATION FLOW:
//   Online order placed → reserved_quantity increases in DB
//   → SizeEntry.availableQty = stockQty - reservedQty drops
//   → _addToCart blocks if requestedQty > availableQty
//   → If ALL sizes of ALL variants are fully reserved,
//     product card goes grey + shows "Product Fully Reserved"
//     dialog before cashier can even pick a size.
//
// PRICING NOTE:
//   There is no manual/cashier-entered discount in this screen.
//   The admin-configured discount (from the Discounts table) is
//   the single source of truth for pricing — it is already baked
//   into item.retailPrice / item.subtotal at the moment an item
//   is added to the cart (see select_variant_dialog.dart's
//   _applyDiscount()). The cashier cannot override or add to it.
//
// CART STATE is managed by cashierProvider.
// Screen handles: checkout, payments, stock validation, totals.
// ================================================

enum PaymentMethod {
  cash,
  online,
}

class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {

  // ── SEARCH ──
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── PAYMENT ──
  // ── PAYMENT ──
  PaymentMethod _paymentMethod = PaymentMethod.online;
  final TextEditingController _cashPaidController = TextEditingController();
  bool _isCheckingOut = false;

  @override
  void dispose() {
    _searchController.dispose();
    _cashPaidController.dispose();
    super.dispose();
  }

  // ================================================
  // CART ITEMS — read from cashierProvider
  // ================================================
  List<CartItem> get _cartItems => ref.watch(cashierProvider);

  // ================================================
  // FILTERED PRODUCTS based on search
  // ================================================
  List<Product> _filterProducts(List<Product> products) {
    if (_searchQuery.isEmpty) return products;

    return products.where((p) {
      return p.productName.toLowerCase().contains(_searchQuery) ||
          p.brand.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  // ================================================
  // CART CALCULATIONS
  //
  // No manual discount — TOTAL is always equal to Subtotal.
  // Any discounting already happened per-item when it was added
  // to the cart (admin discount applied in select_variant_dialog.dart).
  // ================================================
  double get _subtotal {
    double total = 0;
    for (final CartItem item in _cartItems) {
      total += item.subtotal;
    }
    return total;
  }

  double get _total => _subtotal;

  double get _cashPaid =>
      double.tryParse(_cashPaidController.text) ?? 0;

  double get _change =>
      (_cashPaid - _total).clamp(0, double.infinity);

  bool get _isInsufficientAmount =>
      _cashPaid < _total && _cashPaid > 0;

  bool get _canCheckout {
    if (_cartItems.isEmpty) return false;
    if (_paymentMethod == PaymentMethod.cash) {
      return _cashPaid >= _total && _cashPaid > 0;
    }
    return true;
  }

  // True when cash paid is disproportionate to the total — likely a
  // typo (extra digit) rather than an intentionally large bill. Not
  // an outright block, since cashiers legitimately do accept large
  // bills sometimes — this just asks for a second confirmation.
  bool get _isSuspiciouslyLargeCash {
    if (_paymentMethod != PaymentMethod.cash) return false;
    if (_total <= 0) return false;
    return _cashPaid > _total * 20 && _cashPaid > 5000;
  }
  // ================================================
  // TOTAL ITEM COUNT in cart
  // ================================================
  int get _totalItemCount {
    int count = 0;
    for (final CartItem item in _cartItems) {
      count += item.quantity;
    }
    return count;
  }

  // ================================================
  // ADD TO CART
  //
  // Reservation enforcement:
  //   SizeEntry.availableQty = stockQty - reservedQty
  //   If an online order reserved this size,
  //   availableQty is already reduced.
  //   requestedQty > availableQty → blocked.
  // ================================================
void _addToCart({
    required Product product,
    required String color,
    required String size,
    required int quantity,
    required double price,
    double? originalPrice,
  }) {
    // Find the color variant
    final ProductVariant? selectedVariant =
        product.variants.cast<ProductVariant?>().firstWhere(
          (v) => v!.color == color,
          orElse: () => null,
        );

    if (selectedVariant == null) return;

    // Find the size entry inside that variant
    final SizeEntry? selectedSize =
        selectedVariant.sizes.cast<SizeEntry?>().firstWhere(
          (s) => s!.size == size,
          orElse: () => null,
        );

    if (selectedSize == null) return;

    // availableQty already accounts for reservations
    final int availableStock = selectedSize.availableQty;

    // Check how many of this exact variant+size are already in cart
    final CartItem? existing =
        _cartItems.cast<CartItem?>().firstWhere(
          (item) =>
              item!.productId == product.productId &&
              item.color == color &&
              item.size == size,
          orElse: () => null,
        );

    final int existingCartQty = existing?.quantity ?? 0;
    final int requestedQty = existingCartQty + quantity;

    // BLOCK if requested exceeds available (unreserved) stock
    if (requestedQty > availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only $availableStock items available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

   ref.read(cashierProvider.notifier).addToCart(
      productId:   product.productId,
      productName: product.productName,
      brand:       product.brand,
      color:       color,
      size:        size,
      sizeId:      selectedSize.sizeId,
      retailPrice: price,
      originalPrice: originalPrice ?? selectedVariant.retailPrice,
      quantity:    quantity,
    );
  }

  // ================================================
  // REMOVE FROM CART
  // ================================================
  void _removeFromCart(int index) {
    ref.read(cashierProvider.notifier).removeFromCart(index);
  }

  // ================================================
  // UPDATE QUANTITY
  //
  // Decrease → straight to provider (no stock check needed).
  // Increase → validate against SizeEntry.availableQty
  //            which already reflects reservations.
  // ================================================
  void _updateQuantity(int index, int delta) {
    final CartItem cartItem = _cartItems[index];

    // Decrease — no stock check needed
    if (delta < 0) {
      ref.read(cashierProvider.notifier).decreaseQuantity(index);
      return;
    }

    // Increase — validate stock
    final List<Product> products =
        ref.read(productsProvider).value ?? [];

    final Product? product =
        products.cast<Product?>().firstWhere(
          (p) => p!.productId == cartItem.productId,
          orElse: () => null,
        );

    if (product == null) return;

    // Find the color variant
    final ProductVariant? variant =
        product.variants.cast<ProductVariant?>().firstWhere(
          (v) => v!.color == cartItem.color,
          orElse: () => null,
        );

    if (variant == null) return;

    // Find the size entry — availableQty respects reservations
    final SizeEntry? sizeEntry =
        variant.sizes.cast<SizeEntry?>().firstWhere(
          (s) => s!.size == cartItem.size,
          orElse: () => null,
        );

    if (sizeEntry == null) return;

    final int availableStock = sizeEntry.availableQty;
    final int nextQty = cartItem.quantity + delta;

    if (nextQty > availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only $availableStock items available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ref.read(cashierProvider.notifier).increaseQuantity(index);
  }

  // ================================================
  // NEW TRANSACTION — clears everything
  // ================================================
// ================================================
  // FRIENDLY ERROR MESSAGE
  // Supabase RPC errors arrive wrapped as
  // "PostgrestException(message: ..., code: ..., ...)" — this pulls
  // out just the real message (e.g. "Only 1 unit(s) of Hello are
  // actually available right now.") so cashiers see plain English
  // instead of a raw exception dump.
  // ================================================
  String _friendlyErrorMessage(Object error) {
    final String raw = error.toString();
    final RegExp pattern = RegExp(r'message:\s*(.+?),\s*code:');
    final Match? match = pattern.firstMatch(raw);
    return match != null ? match.group(1)!.trim() : raw;
  }

  // ================================================
  // NEW TRANSACTION — clears everything
  // ================================================
  void _newTransaction() {
    ref.read(cashierProvider.notifier).clearCart();
    ref.invalidate(productsProvider);   // force a refetch — stock just changed server-side

    setState(() {
      _cashPaidController.clear();
      _paymentMethod = PaymentMethod.cash;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  // ================================================
  // GENERATE ORDER NUMBER
  // format: DG-YYYYMMDD-XXXX
  // ================================================
  String _generateOrderNumber() {
    final DateTime now = DateTime.now();
    final String year = now.year.toString();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    final int nextNumber = fakeSales.length + 1;
    final String orderSeq = nextNumber.toString().padLeft(4, '0');
    return 'DG-$year$month$day-$orderSeq';
  }

  // ================================================
  // SAVE SALE
  // Converts cart → Sale model → adds to fakeSales.
  // Called BEFORE showing receipt dialog.
  // Sale is saved regardless of whether cashier prints.
  //
  // discount is always 0 here — any admin discount is already
  // reflected in each item's retailPrice/subtotal.
  // ================================================
    Future<Sale> _saveSale({String? referenceNumber}) async {
    final List<SaleItem> saleItems =
        _cartItems.map((CartItem item) {
      return SaleItem(
        productName: item.productName,
        color:       item.color,
        size:        item.size,
        quantity:    item.quantity,
        retailPrice: item.retailPrice,
        originalPrice: item.originalPrice,
      );
    }).toList();

    // Snapshot every value BEFORE the async DB call below. Reading
    // _subtotal/_total live after an await is unsafe — if the cart
    // gets cleared (_newTransaction) by another in-flight checkout
    // before this call finishes, those getters would recompute
    // against an empty cart and silently return 0.
    final double subtotalSnapshot = _subtotal;
    final double totalDiscount =
        _cartItems.fold<double>(0, (sum, item) => sum + item.savings);
    final double totalSnapshot = _total;
    final double cashPaidSnapshot =
        _paymentMethod == PaymentMethod.cash ? _cashPaid : 0;
    final double changeSnapshot =
        _paymentMethod == PaymentMethod.cash ? _change : 0;
    final DateTime transactionDateSnapshot = DateTime.now();

    // Build cart items map for DB save
    final List<Map<String, dynamic>> cartItemsMap =
        _cartItems.map((CartItem item) => {
          'productId':   item.productId,
          'sizeId':      item.sizeId,
          'productName': item.productName,
          'brand':       item.brand,
          'color':       item.color,
          'size':        item.size,
          'quantity':    item.quantity,
          'retailPrice': item.retailPrice,
          'subtotal':    item.subtotal,
        }).toList();

        final Sale sale = Sale(
      orderNumber:     'pending',
      items:           saleItems,
      subtotal:        subtotalSnapshot,
      discount:        totalDiscount,
      total:           totalSnapshot,
      paymentMethod:   _paymentMethod == PaymentMethod.cash ? 'cash' : 'online',
      cashPaid:        cashPaidSnapshot,
      change:          changeSnapshot,
      cashierName:     'Cashier DeeGee',
      transactionDate: transactionDateSnapshot,
      referenceNumber: referenceNumber ?? '',
    );

       // Save to DB
    final String orderNumber = await CashierSaleService().saveSale(
      sale:            sale,
      cartItems:       cartItemsMap,
      referenceNumber: referenceNumber,
    );

    // Return sale with real order number — using the SAME snapshots
    // taken before the DB call, never re-reading live cart getters.
    return Sale(
      orderNumber:     orderNumber,
      items:           saleItems,
      subtotal:        subtotalSnapshot,
      discount:        totalDiscount,
      total:           totalSnapshot,
      paymentMethod:   sale.paymentMethod,
      cashPaid:        cashPaidSnapshot,
      change:          changeSnapshot,
      cashierName:     'Cashier DeeGee',
      transactionDate: transactionDateSnapshot,
      referenceNumber: referenceNumber ?? '',
    );
  }

  // ================================================
  // HANDLE CHECKOUT
  // cash   → save sale → clear cart → show receipt
  // online → cashier confirms payment, enters reference number,
  //          then saves through the exact same path as cash
  // ================================================
  Future<void> _handleCheckout() async {
    if (_cartItems.isEmpty) return;
    if (_isCheckingOut) return; // block double-submission from a fast double-tap

    if (_isSuspiciouslyLargeCash) {
      final bool? confirmed = await showConfirmDialog(
        context: context,
        title: 'Confirm cash amount',
        message: 'Cash paid is ₱${_cashPaid.toStringAsFixed(0)} for a '
            '₱${_total.toStringAsFixed(0)} total — that\'s a large '
            'amount compared to the sale. Please confirm this is correct '
            'before continuing.',
        confirmLabel: 'Yes, this is correct',
        confirmColor: const Color(0xFF2563EB),
      );
      if (confirmed != true) return;
    }

    setState(() => _isCheckingOut = true);

    if (_paymentMethod == PaymentMethod.cash) {
      try {
        final Sale sale = await _saveSale();
        _newTransaction();
        if (mounted) showReceiptDialog(context: context, sale: sale);
      } catch (e) {
        // Cart is deliberately NOT cleared here — the RPC now
        // guarantees an all-or-nothing sale, so nothing was actually
        // deducted on failure. Keeping the cart intact just lets the
        // cashier see what they were trying to sell and adjust the
        // quantity, rather than starting over from scratch.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_friendlyErrorMessage(e)),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isCheckingOut = false);
      }
      return;
    }

    // ── ONLINE (GCash/Maya/Card) — cashier confirms payment then
    // types in the reference number. No QR/webhook step needed for
    // an in-person sale; reuses the exact same save path as cash.
    final String? referenceNumber = await showReferenceNumberDialog(context);

    if (referenceNumber == null) {
      // Cashier cancelled the dialog.
      if (mounted) setState(() => _isCheckingOut = false);
      return;
    }

    try {
      final Sale sale = await _saveSale(referenceNumber: referenceNumber);
      _newTransaction();
      if (mounted) showReceiptDialog(context: context, sale: sale);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyErrorMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return productsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
      data: (products) {
        final List<Product> filteredProducts =
            _filterProducts(products);

        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          body: LayoutBuilder(
            builder: (context, constraints) {
              // Responsive column count — was hardcoded to 3
              // regardless of screen width, wasting a lot of space
              // on large desktop monitors and cramming cards together
              // on narrower ones.
              final double width = constraints.maxWidth;
              int crossAxisCount;
              if (width >= 1600) {
                crossAxisCount = 6;
              } else if (width >= 1300) {
                crossAxisCount = 5;
              } else if (width >= 1000) {
                crossAxisCount = 4;
              } else {
                crossAxisCount = 3;
              }

              return Row(
                children: [

                  // ── LEFT: product grid ──
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          const Text(
                            'Cashier',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),

                          const SizedBox(height: 16),

                          CommonSearchBar(
                            controller: _searchController,
                            hintText: 'Search Product',
                            onChanged: (value) {
                              setState(() {
                                _searchQuery =
                                    value.trim().toLowerCase();
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          Expanded(
                            child: filteredProducts.isEmpty
                                ? _buildEmptyState()
                                : GridView.builder(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  // Was 0.8 — mathematically too tight: the square
                  // image (AspectRatio 1.0) leaves only ~25% of cell
                  // width for text below, but the text needs a fixed
                  // ~48px regardless of cell width. 0.72 gives real
                  // margin at every column count our responsive grid
                  // can produce, not just a band-aid clip/scroll.
                  childAspectRatio: 0.72,
                ),                                    itemCount: filteredProducts.length,
                                    itemBuilder: (context, index) =>
                                        _buildProductCard(
                                            filteredProducts[index]),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── RIGHT: cart panel ──
                  _buildCartPanel(width: width),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ================================================
  // PRODUCT CARD
  //
  // isFullyReserved uses ProductVariant.isFullyReserved
  // which checks sizes.every((s) => s.availableQty == 0)
  // so a partially reserved product still shows as tappable.
  // ================================================
   Widget _buildProductCard(Product product) {
    final bool isFullyReserved = product.isFullyReserved;

    // Sum quantity across every variant/size of THIS product already
    // in the cart — the card is per-product, so a cashier scanning
    // the grid can see "already added 2" without opening the cart panel.
    final int cartQtyForThisProduct = _cartItems
        .where((item) => item.productId == product.productId)
        .fold(0, (int sum, CartItem item) => sum + item.quantity);

    return GestureDetector(
      onTap: () {
        // Fully reserved → show info dialog, block selection
        if (isFullyReserved) {
          showDialog(
            context: context,
            builder: (BuildContext ctx) {
              return Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: 420,
                  padding:
                      const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product Fully Reserved',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'All variants of ${product.productName} '
                        'are currently reserved for online orders.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF9C3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFFDE047)),
                        ),
                        child: const Text(
                          'This product will be available again once '
                          'the admin approves or declines the pending '
                          'online order.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 11),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'OK, Got It',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
          return;
        }

        showSelectVariantDialog(
          context: context,
          product: product,
          onAddToCart: (String color, String size, int quantity,
              double price) {
            _addToCart(
              product: product,
              color: color,
              size: size,
              quantity: quantity,
              price: price,
            );
          },
        );
        // NOTE: originalPrice isn't available from onAddToCart's
        // callback signature (it only passes the final discounted
        // price) — _addToCart already falls back to
        // selectedVariant.retailPrice internally, so this still
        // works correctly without changing SelectVariantDialog's
        // public callback signature.
      },

      child: Opacity(
        opacity: isFullyReserved ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: isFullyReserved
                ? const Color(0xFFF3F4F6)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isFullyReserved
                  ? const Color(0xFFD1D5DB)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [

              AspectRatio(
                aspectRatio: 1.0,
                child: Stack(
                  children: [
                    Builder(builder: (_) {
                      final String? imageUrl =
                          product.variants.isNotEmpty
                              ? product
                                  .variants.first.primaryImageUrl
                              : null;

                      if (imageUrl != null &&
                          imageUrl.isNotEmpty) {
                        return ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                                                    child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              // Logs the REAL url + error so you can
                              // check it directly — this only makes
                              // the failure display gracefully, it
                              // doesn't fix whatever is actually
                              // wrong with the stored file/URL.
                              print('Product image failed: $imageUrl — $error');
                              return Container(
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  size: 32,
                                  color: Color(0xFFD1D5DB),
                                ),
                              );
                            },
                          ),
                        );
                      }

                      return Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: const Icon(
                          Icons.image_outlined,
                          size: 36,
                          color: Color(0xFF9CA3AF),
                        ),
                      );
                    }),

                    // Diagonal ribbon — much faster to spot at a
                    // glance during a busy checkout line than the
                    // previous small pill badge + 0.5 opacity alone.
                    if (isFullyReserved)
                      Positioned(
                        top: 14,
                        right: -34,
                        child: Transform.rotate(
                          angle: 0.785398, // 45 degrees
                          child: Container(
                            width: 130,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            color: const Color(0xFFDC2626),
                            alignment: Alignment.center,
                            child: const Text(
                              'SOLD OUT',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Cart quantity badge — only when NOT fully
                    // reserved, so it never visually competes with
                    // the ribbon above.
                    if (!isFullyReserved && cartQtyForThisProduct > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '×$cartQtyForThisProduct',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isFullyReserved
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isFullyReserved
                          ? 'All reserved'
                          : '₱${product.averagePrice.toStringAsFixed(0)} +',
                      style: TextStyle(
                        fontSize: 12,
                        color: isFullyReserved
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================
  // CART PANEL (right side)
  // ================================================
    Widget _buildCartPanel({double width = 1200}) {
    // Slightly wider on very large screens so it doesn't look
    // disproportionately narrow next to a much bigger product grid —
    // capped, since a cart panel wider than ~360 stops being more
    // readable and just wastes horizontal space that the grid could
    // use for more columns instead.
    final double panelWidth = width >= 1600 ? 360 : (width >= 1300 ? 330 : 300);
    return Container(
      width: panelWidth,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Text(
                  'Cart',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 8),
                if (_totalItemCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      '$_totalItemCount item${_totalItemCount > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          Expanded(
            child: _cartItems.isEmpty
                ? _buildEmptyCart()
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cartItems.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildCartItem(index),
                  ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          _buildPaymentSection(),
        ],
      ),
    );
  }

  // ================================================
  // EMPTY CART STATE
  // ================================================
  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
              border:
                  Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 24,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No items yet',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Click a product to add it',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  // ================================================
  // CART ITEM ROW
  // ================================================
  Widget _buildCartItem(int index) {
    final CartItem item = _cartItems[index];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [

          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.image_outlined,
              size: 20,
              color: Color(0xFF9CA3AF),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  'Size ${item.size}  ·  ${item.color}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₱${item.retailPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Row(
                      children: [
                        _buildSmallQtyButton(
                          icon: Icons.remove,
                          onTap: () =>
                              _updateQuantity(index, -1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8),
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        _buildSmallQtyButton(
                          icon: Icons.add,
                          onTap: () =>
                              _updateQuantity(index, 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          GestureDetector(
            onTap: () => _removeFromCart(index),
            child: const Icon(
              Icons.delete_outline,
              size: 18,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================
  // PAYMENT SECTION
  // ================================================
  Widget _buildPaymentSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          _buildSummaryRow(
              'Subtotal', '₱${_subtotal.toStringAsFixed(0)}'),

          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 8),

          // ── Total ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                '₱${_total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildPaymentMethodChip(
                  label: 'GCash / Maya / Card',
                  value: PaymentMethod.online,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPaymentMethodChip(
                  label: 'Cash',
                  value: PaymentMethod.cash,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Cash fields ──
          if (_paymentMethod == PaymentMethod.cash) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cash Paid',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280)),
                ),
                SizedBox(
                  width: 100,
                  height: 30,
                  child: TextField(
                    controller: _cashPaidController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(7),
                    ],
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF111827)),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: _isInsufficientAmount
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF9CA3AF),
                      ),
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                      filled: true,
                      fillColor: _isInsufficientAmount
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFF9FAFB),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: _isInsufficientAmount
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: _isInsufficientAmount
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF2563EB),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_isInsufficientAmount) ...[
              const SizedBox(height: 4),
              const Text(
                'Insufficient amount',
                style: TextStyle(
                    fontSize: 11, color: Color(0xFFEF4444)),
              ),
            ],

            const SizedBox(height: 8),

            _buildSummaryRow(
                'Change', '₱${_change.toStringAsFixed(0)}'),

            const SizedBox(height: 12),
          ],

          // ── Action buttons ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _newTransaction,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(
                        color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'New Transaction',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      (_canCheckout && !_isCheckingOut) ? _handleCheckout : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _paymentMethod == PaymentMethod.online
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF9CA3AF),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: Text(
                    _paymentMethod == PaymentMethod.online
                        ? 'Checkout'
                        : 'Print Receipt',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================
  // PAYMENT METHOD CHIP
  // ================================================
  Widget _buildPaymentMethodChip({
    required String label,
    required PaymentMethod value,
  }) {
    final bool isSelected = _paymentMethod == value;

    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFD1D5DB),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? Colors.white
                : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  // ================================================
  // SUMMARY ROW
  // ================================================
  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF6B7280))),
        Text(value,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF111827))),
      ],
    );
  }

  // ================================================
  // SMALL QUANTITY BUTTON (inside cart items)
  // ================================================
  Widget _buildSmallQtyButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD1D5DB)),
          color: Colors.white,
        ),
        child: Icon(icon,
            size: 12, color: const Color(0xFF374151)),
      ),
    );
  }

  // ================================================
  // EMPTY STATE (no products found in search)
  // ================================================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No products found',
            style: TextStyle(
                fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}