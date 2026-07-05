// ================================================
// ORDER MODEL
// ================================================

// ================================================
// ORDER ITEM CLASS
// ================================================
class OrderItem {
  final String productName;
  final String brand;
  final int size;
  final int quantity;
  final double price;
  final double total;

  OrderItem({
    required this.productName,
    required this.brand,
    required this.size,
    required this.quantity,
    required this.price,
    required this.total,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    final int qty      = (map['quantity'] as num).toInt();
    final double price = (map['unit_price'] as num).toDouble();
    final double total = (map['subtotal'] as num).toDouble();

    int parsedSize = 0;
    final dynamic rawSize = map['size_snapshot'];
    if (rawSize != null) {
      parsedSize = int.tryParse(rawSize.toString()) ?? 0;
    }

    return OrderItem(
      productName: map['product_name_snapshot'] ?? '',
      brand:       map['brand_snapshot'] ?? '',
      size:        parsedSize,
      quantity:    qty,
      price:       price,
      total:       total,
    );
  }
}

// ================================================
// ORDER CLASS
//
// FIX: Added trackingUrl and receiptUrl fields.
//      These are nullable — not every order will
//      have a Lalamove link or receipt yet.
// ================================================
class Order {
  final String  orderId;
  final String  customerName;
  final String  contact;
  final String  landmark;
  final String  address;
  final double  totalAmount;
  final String  paymentMethod;
  final String  paymentStatus;
  final String  orderStatus;
  final String  dateTime;
  final String? adminNote;  // ← ADD
  final List<OrderItem> items;

  // NEW — Lalamove delivery tracking URL saved by admin
  final String? trackingUrl;

  // NEW — PDF receipt URL stored after payment confirmed
  final String? receiptUrl;
  final String? cancelReason;  // ← ADD THIS


  Order({
    required this.orderId,
    required this.customerName,
    required this.contact,
    required this.landmark,
    required this.address,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    required this.dateTime,
    required this.items,
    this.trackingUrl,
    this.receiptUrl,
    this.cancelReason,  // ← ADD THIS
    this.adminNote,  // ← ADD
  });

    factory Order.fromMap(
    Map<String, dynamic> map, {
    String  paymentStatus = '',
    String? trackingUrl,
    String? receiptUrl,
    String? cancelReason,
    String? adminNote,
  }) {
    // ── user info ──
    final dynamic rawUser           = map['users'];
    final Map<String, dynamic> user = (rawUser is Map<String, dynamic>)
        ? rawUser
        : {};
    final String firstName    = user['first_name'] ?? '';
    final String lastName     = user['last_name']  ?? '';
    final String customerName = '$firstName $lastName'.trim().isEmpty
        ? 'Unknown'
        : '$firstName $lastName'.trim();
    final String contact = user['phone'] ?? '';

    // ── address info ──
    final dynamic rawAddr           = map['address'];
    final Map<String, dynamic> addr = (rawAddr is Map<String, dynamic>)
        ? rawAddr
        : {};
    final String landmark    = addr['landmark'] ?? '';
    final String street      = addr['street']   ?? '';
    final String city        = addr['city']      ?? '';
    final String zipCode     = addr['zip_code']  ?? '';
    final String fullAddress = [street, city, zipCode]
        .where((s) => s.isNotEmpty)
        .join(', ');

    // ── order items ──
    final List<dynamic>   rawItems = map['order_item'] ?? [];
    final List<OrderItem> items    = rawItems
        .map((dynamic item) =>
            OrderItem.fromMap(item as Map<String, dynamic>))
        .toList();

    // ── date formatting ──
    String dateTime = '';
    if (map['created_at'] != null) {
      final DateTime dt   =
          DateTime.parse(map['created_at'].toString()).toLocal();
      final String month  = dt.month.toString().padLeft(2, '0');
      final String day    = dt.day.toString().padLeft(2, '0');
      final String year   = dt.year.toString();
      final int    hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final String minute = dt.minute.toString().padLeft(2, '0');
      final String amPm   = dt.hour < 12 ? 'am' : 'pm';
      dateTime = '$month/$day/$year ${hour12}:$minute $amPm';
    }

    return Order(
      orderId:       map['order_id'].toString(),
      customerName:  customerName,
      contact:       contact,
      landmark:      landmark,
      address:       fullAddress,
      totalAmount:   (map['total_amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] ?? '',
      paymentStatus: paymentStatus,
      orderStatus:   map['order_status'] ?? 'Pending',
      dateTime:      dateTime,
      items:         items,
      trackingUrl:   trackingUrl ?? map['tracking_url'] as String?,
      receiptUrl:    receiptUrl,
      cancelReason:  cancelReason,
      adminNote:     adminNote,
    );
  }
}