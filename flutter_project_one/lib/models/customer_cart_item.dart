/// Represents a single item in the CUSTOMER shopping cart.
/// Mock/fake data only — no Supabase integration yet.
/// Completely separate from cashier-side cart/order models.
class CustomerCartItem {
  final String productId;
  final String productName;
  final String brand;
  final String color;
  final String size;
  final double retailPrice;
  final String imageUrl;
  int quantity;

  CustomerCartItem({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.color,
    required this.size,
    required this.retailPrice,
    required this.imageUrl,
    this.quantity = 1,
  });

  double get subtotal => retailPrice * quantity;

  CustomerCartItem copyWith({
    String? productId,
    String? productName,
    String? brand,
    String? color,
    String? size,
    double? retailPrice,
    String? imageUrl,
    int? quantity,
  }) {
    return CustomerCartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      brand: brand ?? this.brand,
      color: color ?? this.color,
      size: size ?? this.size,
      retailPrice: retailPrice ?? this.retailPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
    );
  }
}

// ─────────────────────────────────────────────
// MOCK CART DATA
// ─────────────────────────────────────────────

final List<CustomerCartItem> mockCustomerCartItems = [
  CustomerCartItem(
    productId: 'shop_001',
    productName: 'AeroBlast Elite V4',
    brand: 'Nike',
    color: 'Midnight Black',
    size: 'US 10.5',
    retailPrice: 245.00,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuDaSwYq5TDmLniPTXSdmuTBhmnPiKoPNI9BxLxMkYtZwUCy5IRe2wXEQcK0Bh1jq0Wk0Hgo-k67gvB-KXV-IW1waZInXXRYYZs_eGSergXEeO5LS1ovFvYzY_0vZ_Bg1TD0dSsVIzGO5M2qUGT3aypl89Y_DXrA2TYrti6WMHbMhCaJ0rGHG-0-am01I5DnPiIfYxQaKafYdyJKuBLQcK8pVu09vpKqGFdFnISoX0y1LhT4hSsszPNjwhepfsz8-0hlFkYve7gnJ2k',
    quantity: 1,
  ),
  CustomerCartItem(
    productId: 'shop_007',
    productName: 'CarbonStrider X',
    brand: 'Adidas',
    color: 'Alpine White',
    size: 'US 9.0',
    retailPrice: 190.00,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuCn_GLi6gO5rBCFpzhVwuNVqG9A5PEWUw8TY-H85L3-QqtXuREhjy5ieJlatxAIcMzX2P8AmegwC6tcogcaZkVV5Ja8Thm_BmjZSFCpReXqACS7XXZP2PO9-5s-6ozkaLl76l2zcT2Sez7OeHdh4wdAvheAw2zcMiqF61SX9BKPI1asRSh5cMffVLzwSb_UosoNlcPX92ldiqeViVp0vvcjsd8_UaT2MWZE77qSIoriSsn4eHIO9ZLLtHVwm8A0pTlRKx4o_DVr7z4',
    quantity: 1,
  ),
];