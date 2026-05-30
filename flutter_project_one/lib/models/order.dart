// ================================================
// ORDER MODEL
//
// This file defines what an Order looks like in code
// Think of it as a "blueprint" for an order
//
// It contains:
//   - OrderItem class     → one item inside an order
//   - Order class         → one order with a list of items
//   - fakeOrders          → fake hardcoded data for now
//
// Later we will replace fakeOrders with real Supabase data
// But the Order and OrderItem classes stay the same
// ================================================

// ================================================
// ORDER ITEM CLASS
// One item = one product inside an order
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
}

// ================================================
// ORDER CLASS
// One order = one customer purchase
// ================================================
class Order {
  final String orderId;
  final String customerName;
  final String contact;
  final String landmark;
  final String address;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;
  final String dateTime;
  final List<OrderItem> items;

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
  });
}

// ================================================
// FAKE ORDERS DATA
// Temporary hardcoded data for testing
// Replace with real Supabase data later
// ================================================
final List<Order> fakeOrders = [

  // ------------------------------------------------
  // Order 1
  // ------------------------------------------------
  Order(
    orderId: 'order_001',
    customerName: 'Angel Tuazon',
    contact: '09991506274',
    landmark: 'Alcay Store',
    address: 'Camarin Caloocan City 178',
    totalAmount: 10500,
    paymentMethod: 'GCash',
    paymentStatus: 'Paid',
    orderStatus: 'Pending',
    dateTime: '02/05/2025 9:15 am',
    items: [
      OrderItem(
        productName: 'Tsinelas',
        brand: 'Adidas',
        size: 43,
        quantity: 2,
        price: 5500,
        total: 10500,
      ),
    ],
  ),

  // ------------------------------------------------
  // Order 2
  // ------------------------------------------------
  Order(
    orderId: 'order_002',
    customerName: 'Jay Galang',
    contact: '09171234567',
    landmark: 'SM North',
    address: 'Quezon City 1105',
    totalAmount: 3200,
    paymentMethod: 'Cash',
    paymentStatus: 'Pending',
    orderStatus: 'Confirmed',
    dateTime: '02/05/2025 10:30 am',
    items: [
      OrderItem(
        productName: 'Nike Panda',
        brand: 'Nike',
        size: 42,
        quantity: 1,
        price: 3200,
        total: 3200,
      ),
    ],
  ),

  // ------------------------------------------------
  // Order 3
  // ------------------------------------------------
  Order(
    orderId: 'order_003',
    customerName: 'Maria Santos',
    contact: '09281112222',
    landmark: 'Jollibee Monumento',
    address: 'Caloocan City 1400',
    totalAmount: 8900,
    paymentMethod: 'Card',
    paymentStatus: 'Paid',
    orderStatus: 'Preparing',
    dateTime: '02/05/2025 11:00 am',
    items: [
      OrderItem(
        productName: 'Adidas Ultraboost',
        brand: 'Adidas',
        size: 40,
        quantity: 1,
        price: 8900,
        total: 8900,
      ),
    ],
  ),

  // ------------------------------------------------
  // Order 4
  // ------------------------------------------------
  Order(
    orderId: 'order_004',
    customerName: 'Carlo Reyes',
    contact: '09559998888',
    landmark: 'Mercury Drug Tandang Sora',
    address: 'Quezon City 1116',
    totalAmount: 4500,
    paymentMethod: 'GCash',
    paymentStatus: 'Paid',
    orderStatus: 'Shipped',
    dateTime: '02/05/2025 1:00 pm',
    items: [
      OrderItem(
        productName: 'Nike Air Max',
        brand: 'Nike',
        size: 44,
        quantity: 1,
        price: 4500,
        total: 4500,
      ),
    ],
  ),
];