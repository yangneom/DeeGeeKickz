import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../../../widgets/cashier/inventory/select_variant_dialog.dart';
// ================================================
// CART ITEM MODEL
// One item in the cashier's cart
// ================================================
class CartItem {
  final String productId;
  final String productName;
  final String color;
  final String size;
  final double retailPrice;
  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    required this.color,
    required this.size,
    required this.retailPrice,
    this.quantity = 1,
  });

  double get subtotal => retailPrice * quantity;
}

// ================================================
// CASHIER SCREEN
//
// Layout:
//   LEFT  → Search bar + Product grid
//   RIGHT → Cart panel + Payment + Checkout
// ================================================
class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {

  // ── SEARCH ──
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── CART ──
  final List<CartItem> _cartItems = [];

  // ── PAYMENT ──
  // 'cash' or 'online'
  String _paymentMethod = 'cash';
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
  // FILTERED PRODUCTS based on search
  // ================================================
  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return fakeProducts;
    return fakeProducts.where((p) {
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

  double get _cashPaid {
    return double.tryParse(_cashPaidController.text) ?? 0;
  }

  double get _change {
    return (_cashPaid - _total).clamp(0, double.infinity);
  }

  bool get _isInsufficientAmount {
    return _cashPaid < _total && _cashPaid > 0;
  }

  // ================================================
  // ADD TO CART
  // ================================================
  void _addToCart({
    required Product product,
    required String color,
    required String size,
    required int quantity,
    required double price,
  }) {
    setState(() {
      // Check if same item already in cart
      final existingIndex = _cartItems.indexWhere(
        (item) =>
            item.productId == product.productId &&
            item.color == color &&
            item.size == size,
      );

      if (existingIndex >= 0) {
        // Just increase quantity
        _cartItems[existingIndex].quantity += quantity;
      } else {
        // Add new cart item
        _cartItems.add(CartItem(
          productId: product.productId,
          productName: product.productName,
          color: color,
          size: size,
          retailPrice: price,
          quantity: quantity,
        ));
      }
    });
  }

  // ================================================
  // REMOVE FROM CART
  // ================================================
  void _removeFromCart(int index) {
    setState(() => _cartItems.removeAt(index));
  }

  // ================================================
  // UPDATE QUANTITY in cart
  // ================================================
  void _updateQuantity(int index, int delta) {
    setState(() {
      _cartItems[index].quantity += delta;
      if (_cartItems[index].quantity <= 0) {
        _cartItems.removeAt(index);
      }
    });
  }

  // ================================================
  // NEW TRANSACTION — clears everything
  // ================================================
  void _newTransaction() {
    setState(() {
      _cartItems.clear();
      _cashPaidController.clear();
      _discountController.clear();
      _discountAmount = 0;
      _paymentMethod = 'cash';
      _searchController.clear();
      _searchQuery = '';
    });
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Row(
        children: [

          // ── LEFT: PRODUCT GRID ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Title
                  const Text(
                    'Cashier',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Search bar
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => _searchQuery = value.toLowerCase());
                      },
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search Product',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 18,
                          color: Color(0xFF9CA3AF),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF2563EB)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── PRODUCT GRID ──
                  Expanded(
                    child: _filteredProducts.isEmpty
                        ? _buildEmptyState()
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              return _buildProductCard(
                                  _filteredProducts[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // ── RIGHT: CART PANEL ──
          _buildCartPanel(),
        ],
      ),
    );
  }

  // ================================================
  // PRODUCT CARD
  // ================================================
  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () {
        showSelectVariantDialog(
          context: context,
          product: product,
          onAddToCart: (color, size, quantity, price) {
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Image placeholder
            Expanded(
              child: Container(
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
              ),
            ),

            // Product info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₱${product.averagePrice.toStringAsFixed(0)} +',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

          // Cart title
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Cart',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Cart items list
          Expanded(
            child: _cartItems.isEmpty
                ? const Center(
                    child: Text(
                      'No items yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cartItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _buildCartItem(index);
                    },
                  ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // ── PAYMENT SECTION ──
          _buildPaymentSection(),
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
      ),
      child: Row(
        children: [

          // Image placeholder
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

          // Item details
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
                  'Size ${item.size}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Text(
                  'Color ${item.color}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
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
                    // Quantity controls
                    Row(
                      children: [
                        _buildSmallQtyButton(
                          icon: Icons.add,
                          onTap: () => _updateQuantity(index, 1),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _buildSmallQtyButton(
                          icon: Icons.remove,
                          onTap: () => _updateQuantity(index, -1),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          // Delete button
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

          // Subtotal
          _buildSummaryRow('Subtotal', '₱${_subtotal.toStringAsFixed(0)}'),

          const SizedBox(height: 4),

          // Discount row
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                      borderSide:
                          const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: Color(0xFF2563EB)),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _discountAmount =
                          double.tryParse(value) ?? 0;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                '₱${_total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Payment method label
          const Text(
            'Payment Method',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),

          const SizedBox(height: 6),

          // Payment method toggle
          Row(
            children: [
              _buildPaymentMethodChip(
                label: 'Online-Payment',
                value: 'online',
              ),
              const SizedBox(width: 8),
              _buildPaymentMethodChip(
                label: 'Cash',
                value: 'cash',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Cash payment input (only show for cash)
          if (_paymentMethod == 'cash') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cash Payment',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                SizedBox(
                  width: 90,
                  height: 30,
                  child: TextField(
                    controller: _cashPaidController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF111827),
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '100',
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
                      suffixText: _isInsufficientAmount
                          ? 'Insufficient amount'
                          : null,
                      suffixStyle: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Change
            _buildSummaryRow(
              'Change',
              '₱${_change.toStringAsFixed(0)}',
            ),

            const SizedBox(height: 12),
          ],

          // ── BOTTOM BUTTONS ──
          Row(
            children: [

              // New Transaction
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

              // Print Receipt
              Expanded(
                child: ElevatedButton(
                  onPressed: _cartItems.isEmpty ? null : () {
                    // TODO: Print receipt
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF9CA3AF),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Print Receipt',
                    style: TextStyle(
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
    required String value,
  }) {
    final bool isSelected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFD1D5DB),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color:
                isSelected ? Colors.white : const Color(0xFF374151),
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
        ),
        child: Icon(icon, size: 12, color: const Color(0xFF374151)),
      ),
    );
  }

  // ================================================
  // EMPTY STATE
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