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
// Later we will replace fakeProducts with real Firestore data
// But the Product and ProductVariant classes stay the same
// ================================================


// ================================================
// PRODUCT VARIANT CLASS
// One variant = one specific color + size combination
// For example: Nike Panda, Pink, Size 8
// ================================================
class ProductVariant {

  // The color of this variant
  final String color;

  // The size of this variant
  final String size;

  // How many of this variant are in stock
  final int stockQty;

  // The cost price — what the store paid for it
  final double costPrice;

  // The retail price — what the customer pays
  final double retailPrice;

  // ================================================
  // CONSTRUCTOR
  // This is how we CREATE a ProductVariant
  // "required" means we MUST provide this value
  // ================================================
  ProductVariant({
    required this.color,
    required this.size,
    required this.stockQty,
    required this.costPrice,
    required this.retailPrice,
  });

  // ================================================
  // STATUS GETTER
  // This automatically calculates the status
  // based on the stock quantity
  //
  // No stock    → "Out of Stock"
  // 1 to 5      → "Low Stock"
  // 6 or more   → "Available"
  //
  // We use "get" so we can call it like a variable
  // variant.status  instead of  variant.getStatus()
  // ================================================
  String get status {
    if (stockQty == 0) {
      return 'Out of Stock';
    } else if (stockQty <= 5) {
      return 'Low Stock';
    } else {
      return 'Available';
    }
  }
}


// ================================================
// PRODUCT CLASS
// One product = one shoe model with multiple variants
// For example: Nike Panda has Pink/Size 8, White/Size 9
// ================================================
class Product {

  // Unique ID for this product
  final String productId;

  // Name of the product
  final String productName;

  // Brand of the product
  final String brand;

  // Category of the product
  final String category;

  // List of variants for this product
  // One product can have many variants
  final List<ProductVariant> variants;

  // ================================================
  // CONSTRUCTOR
  // ================================================
  Product({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.category,
    required this.variants,
  });

  // ================================================
  // TOTAL STOCK GETTER
  // Adds up all the stock from every variant
  // So we don't have to calculate it manually
  //
  // Example:
  // Pink/Size 8 has 6
  // White/Size 9 has 4
  // Total stock = 10
  // ================================================
  int get totalStock {

    // Start at zero
    int total = 0;

    // Loop through every variant and add its stock
    for (ProductVariant variant in variants) {
      total = total + variant.stockQty;
    }

    return total;
  }

  // ================================================
  // AVERAGE PRICE GETTER
  // Calculates the average retail price
  // across all variants
  // ================================================
  double get averagePrice {

    // If no variants return 0
    if (variants.isEmpty) {
      return 0;
    }

    // Add up all retail prices
    double total = 0;
    for (ProductVariant variant in variants) {
      total = total + variant.retailPrice;
    }

    // Divide by number of variants to get average
    return total / variants.length;
  }
}


// ================================================
// FAKE PRODUCTS DATA
// This is our temporary hardcoded data
// It looks exactly like what Firestore would give us
// Later we replace this with real Firestore data
// but the Product and ProductVariant classes stay the same
// ================================================
final List<Product> fakeProducts = [

  // ------------------------------------------------
  // Product 1 - Nike Panda
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
        costPrice: 5500,
        retailPrice: 2500,
      ),
      ProductVariant(
        color: 'White',
        size: '9',
        stockQty: 2,
        costPrice: 5500,
        retailPrice: 2500,
      ),
    ],
  ),

  // ------------------------------------------------
  // Product 2 - Nike Air Max 270
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
        costPrice: 7000,
        retailPrice: 4500,
      ),
      ProductVariant(
        color: 'White',
        size: '10',
        stockQty: 0,
        costPrice: 7000,
        retailPrice: 4500,
      ),
    ],
  ),

  // ------------------------------------------------
  // Product 3 - Adidas Ultraboost
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
        costPrice: 8000,
        retailPrice: 5500,
      ),
      ProductVariant(
        color: 'Black',
        size: '9',
        stockQty: 12,
        costPrice: 8000,
        retailPrice: 5500,
      ),
    ],
  ),

];