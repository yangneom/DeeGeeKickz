// ================================================
// DISCOUNT MODEL
//
// Maps to the `discount` table, joined with the
// product's name + a derived original price
// (min retail_price across non-archived variants).
// ================================================
class Discount {
  final int discountId;
  final int productId;
  final String productName;
  final double originalPrice;
  final String discountType; // 'Fixed' | 'Percentage'
  final double discountValue;
  final String status;
  final DateTime startDate;
  final DateTime endDate;

  Discount({
    required this.discountId,
    required this.productId,
    required this.productName,
    required this.originalPrice,
    required this.discountType,
    required this.discountValue,
    required this.status,
    required this.startDate,
    required this.endDate,
  });

  // ================================================
  // FROM MAP
  // ================================================
  factory Discount.fromMap(Map<String, dynamic> map) {
    return Discount(
      discountId: map['discount_id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      originalPrice: (map['original_price'] as num).toDouble(),
      discountType: map['discount_type'] as String,
      discountValue: (map['discount_value'] as num).toDouble(),
      status: map['status'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
    );
  }

  // ================================================
  // TO MAP
  // ================================================
  Map<String, dynamic> toMap() {
    return {
      'discount_id': discountId,
      'product_id': productId,
      'discount_type': discountType,
      'discount_value': discountValue,
      'status': status,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    };
  }

  // ================================================
  // DISCOUNT DISPLAY
  // "20%" for Percentage, "₱1,000" for Fixed
  // Reuses the same comma-formatting logic that lived
  // in CreateDiscountDialog._addCommas().
  // ================================================
  String get discountDisplay {
    if (discountType == 'Percentage') {
      return '${_trimNumber(discountValue)}%';
    }
    return '₱${_addCommas(discountValue.toInt())}';
  }

  // ================================================
  // FINAL PRICE
  // Same calculation logic as
  // CreateDiscountDialog._calculateFinalPrice()
  // ================================================
  double get finalPrice {
    double result;
    if (discountType == 'Percentage') {
      final double discountAmount = originalPrice * (discountValue / 100);
      result = originalPrice - discountAmount;
    } else {
      result = originalPrice - discountValue;
    }
    if (result < 0) result = 0;
    return result;
  }

  // ================================================
  // FINAL PRICE DISPLAY
  // "₱4,400"
  // ================================================
  String get finalPriceDisplay => '₱${_addCommas(finalPrice.toInt())}';

  // ================================================
  // ORIGINAL PRICE DISPLAY
  // "₱5,500"
  // ================================================
  String get originalPriceDisplay => '₱${_addCommas(originalPrice.toInt())}';

  // ── helpers ──

  static String _addCommas(int number) {
    String numStr = number.toString();
    String result = '';
    int count = 0;
    for (int i = numStr.length - 1; i >= 0; i = i - 1) {
      if (count > 0 && count % 3 == 0) {
        result = ',$result';
      }
      result = numStr[i] + result;
      count = count + 1;
    }
    return result;
  }

  static String _trimNumber(double value) {
    // "20.0" -> "20", "12.5" -> "12.5"
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}