// ================================================
// SALE MODEL
//
// Represents one completed transaction
// Saved to sales list when payment is confirmed
// Used by:
//   - Cashier → saved after cash or online payment
//   - Admin Sales Management → reads this list
//
// IMPORTANT:
//   Sale is saved REGARDLESS of whether the
//   cashier prints or saves the receipt.
//   Printing is optional. Saving to sales is not.
// ================================================


// ================================================
// SALE ITEM
// One line item inside a sale
// ================================================
class SaleItem {

  // product name
  final String productName;

  // selected color
  final String color;

  // selected size
  final String size;

  // quantity sold
  final int quantity;

  // price actually charged per unit (after admin discount, if any)
  final double retailPrice;

  // undiscounted price per unit — same as retailPrice when there
  // was no active discount at time of sale. Lets the receipt show
  // "was ₱X" and the amount saved.
  final double originalPrice;

  const SaleItem({
    required this.productName,
    required this.color,
    required this.size,
    required this.quantity,
    required this.retailPrice,
    double? originalPrice,
  }) : originalPrice = originalPrice ?? retailPrice;

  // ================================================
  // SUBTOTAL GETTER
  // price × quantity
  // ================================================
  double get subtotal => retailPrice * quantity;

  bool get hasDiscount => originalPrice > retailPrice;

  double get savings => hasDiscount ? (originalPrice - retailPrice) * quantity : 0;
}


// ================================================
// SALE
// One completed transaction
// ================================================
class Sale {

  // unique order number
  // format: DG-YYYYMMDD-XXXX
  // example: DG-20250531-0001
  final String orderNumber;

  // list of items in this sale
  final List<SaleItem> items;

  // subtotal before discount
  final double subtotal;

  // discount applied
  final double discount;

  // final total after discount
  final double total;

  // 'cash' or 'online'
  final String paymentMethod;

  // how much cash the customer paid (cash only)
  // 0 if online payment
  final double cashPaid;

  // change returned to customer (cash only)
  // 0 if online payment
  final double change;

  // cashier name — will come from auth later
  final String cashierName;

  // date and time of transaction
  final DateTime transactionDate;

  const Sale({
    required this.orderNumber,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.cashPaid,
    required this.change,
    required this.cashierName,
    required this.transactionDate,
  });

  // ================================================
  // TOTAL ITEMS GETTER
  // total quantity across all line items
  // ================================================
  int get totalItems {
    int count = 0;
    for (SaleItem item in items) {
      count += item.quantity;
    }
    return count;
  }

  // ================================================
  // TOTAL SAVINGS GETTER
  // Sum of per-item savings from admin discounts.
  // This is the real source of truth for "how much did the
  // customer save" — computed from each item's own
  // original vs. discounted price, not the flat `discount` field
  // (which cashiers can no longer set manually).
  // ================================================
  double get totalSavings {
    double total = 0;
    for (SaleItem item in items) {
      total += item.savings;
    }
    return total;
  }

  bool get hasSavings => totalSavings > 0;

  // ================================================
  // PAYMENT METHOD LABEL
  // human-readable payment method
  // ================================================
  String get paymentMethodLabel {
    if (paymentMethod == 'cash') return 'Cash';
    if (paymentMethod == 'online') return 'GCash / Maya / Card';
    return paymentMethod;
  }
}


// ================================================
// FAKE SALES DATA
// temporary hardcoded data for testing
// in production this will come from Supabase
//
// NOTE: in real app, _generateOrderNumber() will
// query Supabase to get the next order number.
// For now we hardcode them.
// ================================================
final List<Sale> fakeSales = [

  Sale(
    orderNumber: 'DG-20250530-0001',
    items: [
      const SaleItem(
        productName: 'Nike Panda',
        color: 'Pink',
        size: '8',
        quantity: 1,
        retailPrice: 2500,
      ),
      const SaleItem(
        productName: 'Adidas Ultraboost 22',
        color: 'Black',
        size: '9',
        quantity: 2,
        retailPrice: 5500,
      ),
    ],
    subtotal: 13500,
    discount: 0,
    total: 13500,
    paymentMethod: 'cash',
    cashPaid: 15000,
    change: 1500,
    cashierName: 'Cashier DeeGee',
    transactionDate: DateTime(2025, 5, 30, 10, 30),
  ),

  Sale(
    orderNumber: 'DG-20250530-0002',
    items: [
      const SaleItem(
        productName: 'Nike Air Max 270',
        color: 'Black',
        size: '9',
        quantity: 1,
        retailPrice: 4500,
      ),
    ],
    subtotal: 4500,
    discount: 0,
    total: 4500,
    paymentMethod: 'online',
    cashPaid: 0,
    change: 0,
    cashierName: 'Cashier DeeGee',
    transactionDate: DateTime(2025, 5, 30, 14, 15),
  ),

];