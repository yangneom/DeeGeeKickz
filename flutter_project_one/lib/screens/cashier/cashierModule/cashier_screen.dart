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
import '../../../widgets/common/search_bar.dart';
import '../../../widgets/common/confirm_dialog.dart';



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
// CART STATE is now managed by cashierProvider.
// Screen handles: checkout, payments, sales, stock validation, totals.
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
  // 'cash' or 'online'
  PaymentMethod _paymentMethod = PaymentMethod.online;
  final TextEditingController _cashPaidController = TextEditingController();
  double _discountAmount = 0;
  final TextEditingController _discountController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _cashPaidController.dispose();
    _discountController.dispose();
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
    if (_searchQuery.isEmpty) {
      return products;
    }

    return products.where((p) {
      return p.productName.toLowerCase().contains(_searchQuery) ||
          p.brand.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  // ================================================
  // CART CALCULATIONS
  // ================================================
  double get _subtotal {
    double total = 0;
    for (CartItem item in _cartItems) {
      total += item.subtotal;
    }
    return total;
  }

  double get _total => (_subtotal - _discountAmount).clamp(0, double.infinity);

    double get _discountPercent {
    if (_subtotal <= 0) return 0;
    return (_discountAmount / _subtotal) * 100;
  }

  bool get _isDiscountTooLarge {
    return _discountPercent > 50;
  }

  bool get _requiresDiscountConfirmation {
    return _discountPercent >= 20 &&
          _discountPercent <= 50;
  }

  double get _cashPaid {
    return double.tryParse(_cashPaidController.text) ?? 0;
  }

  double get _change {
    return (_cashPaid - _total).clamp(0, double.infinity);
  }

  bool get _isInsufficientAmount {
    return _cashPaid < _total && _cashPaid > 0;
  }

    bool get _canCheckout {
    if (_cartItems.isEmpty) return false;

    if (_paymentMethod == PaymentMethod.cash) {
      return _cashPaid >= _total && _cashPaid > 0;
    }

    return true;
  }

  // ================================================
  // TOTAL ITEM COUNT in cart
  // ================================================
  int get _totalItemCount {
    int count = 0;
    for (CartItem item in _cartItems) {
      count += item.quantity;
    }
    return count;
  }

  // ================================================
  // ADD TO CART
  // Stock validation stays here — provider only
  // manages cart state, not product data.
  // ================================================
  void _addToCart({
    required Product product,
    required String color,
    required String size,
    required int quantity,
    required double price,
  }) {

    // FIND SELECTED VARIANT
    final ProductVariant selectedVariant = product.variants.firstWhere(
      (variant) => variant.color == color && variant.size == size,
    );

    // AVAILABLE STOCK
    final int availableStock =
        selectedVariant.stockQty - selectedVariant.reservedQty;

    // CHECK EXISTING CART QTY for this variant
    final CartItem? existing = _cartItems.cast<CartItem?>().firstWhere(
      (CartItem? item) =>
          item!.productId == product.productId &&
          item.color == color &&
          item.size == size,
      orElse: () => null,
    );

    final int existingCartQty = existing?.quantity ?? 0;

    // TOTAL REQUESTED QUANTITY
    final int requestedQty = existingCartQty + quantity;

    // BLOCK IF EXCEEDS STOCK
    if (requestedQty > availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only $availableStock items available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // DELEGATE TO PROVIDER
    ref.read(cashierProvider.notifier).addToCart(
      productId: product.productId,
      productName: product.productName,
      color: color,
      size: size,
      retailPrice: price,
      quantity: quantity,
    );
  }

  // ================================================
  // REMOVE FROM CART — delegates to provider
  // ================================================
  void _removeFromCart(int index) {
    ref.read(cashierProvider.notifier).removeFromCart(index);
  }

  // ================================================
  // UPDATE QUANTITY
  // Stock validation stays here for increases.
  // Decreases go straight to provider.
  // ================================================
  void _updateQuantity(int index, int delta) {

    final CartItem cartItem = _cartItems[index];

    // DECREASE — provider handles removal if qty hits 0
    if (delta < 0) {
      ref.read(cashierProvider.notifier).decreaseQuantity(index);
      return;
    }

    // INCREASE — validate stock first
    final List<Product> products = ref.read(productsProvider).value ?? [];

    final Product product = products.firstWhere(
      (Product p) => p.productId == cartItem.productId,
    );

    final ProductVariant variant = product.variants.firstWhere(
      (ProductVariant v) =>
          v.color == cartItem.color && v.size == cartItem.size,
    );

    final int availableStock = variant.stockQty - variant.reservedQty;
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
  void _newTransaction() {
    ref.read(cashierProvider.notifier).clearCart();

    setState(() {
      _cashPaidController.clear();
      _discountController.clear();
      _discountAmount = 0;
      _paymentMethod = PaymentMethod.cash;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  // ================================================
  // GENERATE ORDER NUMBER
  // format: DG-YYYYMMDD-XXXX
  // uses fakeSales length to get next number
  // replace with Supabase query later
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
  // converts cart items → Sale model
  // adds to fakeSales list
  // called BEFORE showing receipt dialog
  // sale is saved regardless of whether cashier prints
  // replace fakeSales.add() with Supabase insert later
  // ================================================
  Sale _saveSale() {

    final List<SaleItem> saleItems = _cartItems.map((CartItem item) {
      return SaleItem(
        productName: item.productName,
        color: item.color,
        size: item.size,
        quantity: item.quantity,
        retailPrice: item.retailPrice,
      );
    }).toList();

    final Sale sale = Sale(
        orderNumber: _generateOrderNumber(),
        items: saleItems,
        subtotal: _subtotal,
        discount: _discountAmount,
        total: _total,
        paymentMethod: _paymentMethod == PaymentMethod.cash
            ? 'cash'
            : 'online',
        cashPaid: _paymentMethod == PaymentMethod.cash
            ? _cashPaid
            : 0,
        change: _paymentMethod == PaymentMethod.cash
            ? _change
            : 0,
        cashierName: 'Cashier DeeGee',
        transactionDate: DateTime.now(),
      );
    fakeSales.add(sale);

    return sale;
  }

  // ================================================
  // HANDLE CHECKOUT
  // cash    → save sale → clear cart → show receipt
  // online  → show PayMongo placeholder
  // ================================================
    Future<void> _handleCheckout() async {
    if (_cartItems.isEmpty) return;

    if (_isDiscountTooLarge) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Discount cannot exceed 50% of subtotal.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_requiresDiscountConfirmation) {
      final bool? confirmed = await showConfirmDialog(
        context: context,
        title: 'Large Discount Applied',
        message:
            'A discount of ${_discountPercent.toStringAsFixed(0)}% '
            'has been applied to this transaction.\n\n'
            'Are you sure you want to continue?',
        confirmLabel: 'Continue',
        confirmColor: const Color(0xFF2563EB),
      );

      if (confirmed != true) {
        return;
      }
    }

    if (_paymentMethod == PaymentMethod.cash) {
      final Sale sale = _saveSale();

      _newTransaction();

      showReceiptDialog(
        context: context,
        sale: sale,
      );
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
        final filteredProducts = _filterProducts(products);

        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),

          body: Row(
            children: [

              // LEFT SIDE
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
                            _searchQuery = value.trim().toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filteredProducts.isEmpty
                            ? _buildEmptyState()
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.8,
                                ),
                                itemCount: filteredProducts.length,
                                itemBuilder: (context, index) {
                                  return _buildProductCard(
                                    filteredProducts[index],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // RIGHT SIDE CART
              _buildCartPanel(),
            ],
          ),
        );
      },
    );
  }

  // ================================================
  // PRODUCT CARD
  // ================================================
  Widget _buildProductCard(Product product) {

    final bool isFullyReserved = product.isFullyReserved;

    return GestureDetector(
      onTap: () {

        if (isFullyReserved == true) {
          showDialog(
            context: context,
            builder: (BuildContext ctx) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: 420,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
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
                        'All variants of ${product.productName} are currently reserved for online orders.',
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
                          border: Border.all(color: const Color(0xFFFDE047)),
                        ),
                        child: const Text(
                          'This product will be available again once the admin approves or declines the pending online order.',
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
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 11,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
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
          onAddToCart: (String color, String size, int quantity, double price) {
            _addToCart(
              product: product,
              color: color,
              size: size,
              quantity: quantity,
              price: price,
            );
          },
        );
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
                    Builder(
                      builder: (_) {
                        final String? imageUrl =
                            product.variants.isNotEmpty
                                ? product.variants.first.primaryImageUrl
                                : null;
                        if (imageUrl != null && imageUrl.isNotEmpty) {
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
                      },
                    ),

                    if (isFullyReserved == true)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, size: 10, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Reserved',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
  Widget _buildCartPanel() {
    return Container(
      width: 300,
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
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
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
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      return _buildCartItem(index);
                    },
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
              border: Border.all(color: const Color(0xFFE5E7EB)),
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
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF9CA3AF),
            ),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          onTap: () => _updateQuantity(index, -1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
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
                          onTap: () => _updateQuantity(index, 1),
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

          _buildSummaryRow('Subtotal', '₱${_subtotal.toStringAsFixed(0)}'),

          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Discount',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              SizedBox(
                width: 70,
                height: 28,
                child: TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                    ],
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF111827),
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                  ),
                  onChanged: (String value) {
                    final double entered =
                        double.tryParse(value) ?? 0;

                    if (entered > _subtotal) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Discount cannot exceed the subtotal.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );

                      _discountController.text =
                          _subtotal.toStringAsFixed(0);

                      _discountController.selection =
                          TextSelection.fromPosition(
                        TextPosition(
                          offset: _discountController.text.length,
                        ),
                      );
                    }

                    setState(() {
                      _discountAmount = entered
                          .clamp(0, _subtotal)
                          .toDouble();
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          const SizedBox(height: 8),

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
          if (_paymentMethod == PaymentMethod.cash) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cash Paid',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                SizedBox(
                  width: 100,
                  height: 30,
                  child: TextField(
                    controller: _cashPaidController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF111827),
                    ),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
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
                  fontSize: 11,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],

            const SizedBox(height: 8),

            _buildSummaryRow('Change', '₱${_change.toStringAsFixed(0)}'),

            const SizedBox(height: 12),
          ],

          Row(
            children: [

              Expanded(
                child: OutlinedButton(
                  onPressed: _newTransaction,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'New Transaction',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: ElevatedButton(
                  onPressed: _canCheckout ? _handleCheckout : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _paymentMethod == PaymentMethod.online
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF9CA3AF),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _paymentMethod == PaymentMethod.online ? 'Checkout' : 'Print Receipt',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
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
            color: isSelected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  // ================================================
  // SUMMARY ROW (label + value)
  // ================================================
  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
        ),
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
        child: Icon(icon, size: 12, color: const Color(0xFF374151)),
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
          Icon(Icons.search_off, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No products found',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}