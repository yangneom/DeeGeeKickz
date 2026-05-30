// ================================================
// PRODUCT MODEL
//
// This file defines what a Product looks like in code
// Think of it as a "blueprint" for a product
//
// It contains:
//   - ProductVariant class → one variant (color + size + stock)
//   - Product class        → one product with a list of variants
//   - fakeProducts         → fake hardcoded data for now
//
// Later we will replace fakeProducts with real Supabase data
// But the Product and ProductVariant classes stay the same
// ================================================


// ================================================
// PRODUCT VARIANT CLASS
// One variant = one specific color + size combination
// For example: Nike Panda, Pink, Size 8
// ================================================
class ProductVariant {

  // the color of this variant
  final String color;

  // the size of this variant
  final String size;

  // how many of this variant are physically in stock
  final int stockQty;

  // how many are locked/reserved by online orders
  // these CANNOT be sold in-store by the cashier
  final int reservedQty;

  // the cost price — what the store paid for it
  final double costPrice;

  // the retail price — what the customer pays
  final double retailPrice;

  // ================================================
  // CONSTRUCTOR
  // reservedQty defaults to 0 if not provided
  // so existing code doesn't break
  // ================================================
  ProductVariant({
    required this.color,
    required this.size,
    required this.stockQty,
    this.reservedQty = 0,
    required this.costPrice,
    required this.retailPrice,
  });

  // ================================================
  // AVAILABLE QTY GETTER
  // how many the cashier can actually sell in-store
  // = total stock minus what's reserved for online orders
  //
  // Example:
  // stockQty = 10, reservedQty = 3 → availableQty = 7
  // stockQty = 2,  reservedQty = 2 → availableQty = 0 (fully reserved)
  // ================================================
  int get availableQty {
    int available = stockQty - reservedQty;

    // never go below zero
    if (available < 0) {
      return 0;
    }

    return available;
  }

  // ================================================
  // IS FULLY RESERVED GETTER
  // true when cashier cannot sell this variant at all
  // ================================================
  bool get isFullyReserved {
    return availableQty == 0 && reservedQty > 0;
  }

  // ================================================
  // STATUS GETTER
  // calculates status based on AVAILABLE qty
  // not total stock — cashier only sees what's available
  //
  // Reserved     → all stock is locked by online orders
  // Out of Stock → no stock at all
  // Low Stock    → 1 to 5 available
  // Available    → 6 or more available
  // ================================================
  String get status {

    // fully reserved by online orders
    if (isFullyReserved == true) {
      return 'Reserved';
    }

    // no stock at all
    if (stockQty == 0) {
      return 'Out of Stock';
    }

    // low available stock
    if (availableQty <= 5) {
      return 'Low Stock';
    }

    return 'Available';
  }
}


// ================================================
// PRODUCT CLASS
// One product = one shoe model with multiple variants
// ================================================
class Product {

  // unique ID for this product
  final String productId;

  // name of the product
  final String productName;

  // brand of the product
  final String brand;

  // category of the product
  final String category;

  // list of variants for this product
  final List<ProductVariant> variants;

  // only used by archived products
  // normal products leave this null
  final String? archivedDate;

  // ================================================
  // CONSTRUCTOR
  // ================================================
  Product({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.category,
    required this.variants,
    this.archivedDate,
  });

  // ================================================
  // TOTAL STOCK GETTER
  // adds up all physical stock from every variant
  // ================================================
  int get totalStock {
    int total = 0;
    for (ProductVariant variant in variants) {
      total = total + variant.stockQty;
    }
    return total;
  }

  // ================================================
  // TOTAL RESERVED GETTER
  // adds up all reserved qty across all variants
  // ================================================
  int get totalReserved {
    int total = 0;
    for (ProductVariant variant in variants) {
      total = total + variant.reservedQty;
    }
    return total;
  }

  // ================================================
  // TOTAL AVAILABLE GETTER
  // what the cashier can actually sell
  // ================================================
  int get totalAvailable {
    int total = 0;
    for (ProductVariant variant in variants) {
      total = total + variant.availableQty;
    }
    return total;
  }

  // ================================================
  // IS FULLY RESERVED GETTER
  // true when ALL variants are fully reserved
  // cashier cannot sell any variant of this product
  // ================================================
  bool get isFullyReserved {
    if (variants.isEmpty) return false;

    for (ProductVariant variant in variants) {
      // if even one variant has available stock → not fully reserved
      if (variant.availableQty > 0) {
        return false;
      }
    }

    return true;
  }

  // ================================================
  // AVERAGE PRICE GETTER
  // calculates average retail price across all variants
  // ================================================
  double get averagePrice {
    if (variants.isEmpty) {
      return 0;
    }

    double total = 0;
    for (ProductVariant variant in variants) {
      total = total + variant.retailPrice;
    }

    return total / variants.length;
  }
}


// ================================================
// FAKE PRODUCTS DATA
// temporary hardcoded data for testing
// includes reservedQty to simulate online orders
// ================================================
final List<Product> fakeProducts = [

  // ------------------------------------------------
  // Product 1 - Nike Panda
  // Pink/8 has 3 reserved (online order pending)
  // White/9 is fully reserved
  // ------------------------------------------------
  Product(
    productId: 'product_001',
    productName: 'Nike Panda',
    brand: 'Nike',
    category: 'Running Shoes',
    variants: [
      ProductVariant(
        color: 'Pink',
        size: '8',
        stockQty: 6,
        reservedQty: 3,   // 3 locked → 3 available
        costPrice: 5500,
        retailPrice: 2500,
      ),
      ProductVariant(
        color: 'White',
        size: '9',
        stockQty: 2,
        reservedQty: 2,   // fully reserved → 0 available
        costPrice: 5500,
        retailPrice: 2500,
      ),
    ],
  ),

  // ------------------------------------------------
  // Product 2 - Nike Air Max 270
  // Black/9 has no reservation
  // White/10 is out of stock (no reservation needed)
  // ------------------------------------------------
  Product(
    productId: 'product_002',
    productName: 'Nike Air Max 270 React Flyk b nit Men\'s Running Shoe',
    brand: 'Nike',
    category: 'Sneakers',
    variants: [
      ProductVariant(
        color: 'Black',
        size: '9',
        stockQty: 8,
        reservedQty: 0,   // no reservations
        costPrice: 7000,
        retailPrice: 4500,
      ),
      ProductVariant(
        color: 'White',
        size: '10',
        stockQty: 0,
        reservedQty: 0,   // out of stock
        costPrice: 7000,
        retailPrice: 4500,
      ),
    ],
  ),

  // ------------------------------------------------
  // Product 3 - Adidas Ultraboost
  // Blue/8 is low stock with 1 reserved
  // Black/9 has no reservation
  // ------------------------------------------------
  Product(
    productId: 'product_003',
    productName: 'Adidas Ultraboost 22',
    brand: 'Adidas',
    category: 'Running Shoes',
    variants: [
      ProductVariant(
        color: 'Blue',
        size: '8',
        stockQty: 3,
        reservedQty: 1,   // 1 locked → 2 available
        costPrice: 8000,
        retailPrice: 5500,
      ),
      ProductVariant(
        color: 'Black',
        size: '9',
        stockQty: 12,
        reservedQty: 0,   // no reservations
        costPrice: 8000,
        retailPrice: 5500,
      ),
    ],
  ),

];