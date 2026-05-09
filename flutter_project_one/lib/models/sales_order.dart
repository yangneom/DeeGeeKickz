// ================================================
// SALES ORDER MODEL
//
// This file defines what a SalesOrder looks like in code
// Think of it as a "blueprint" for a sales order
//
// It contains:
//   - SalesOrderStatus enum  → the possible statuses of an order
//   - SalesOrder class       → one order with all its details
//   - fakeSalesOrders        → fake hardcoded data for now
//
// Later we will replace fakeSalesOrders with real Firestore data
// But the SalesOrder class and SalesOrderStatus enum stay the same
// ================================================


// ================================================
// SALES ORDER STATUS ENUM
// These are all the possible statuses an order can have
// An order can only ever be one of these 5 options
// ================================================
enum SalesOrderStatus {
  cancelled,
  pending,
  confirmed,
  preparing,
  shipped,
}


// ================================================
// SALES ORDER CLASS
// One order = one transaction made by a customer
// For example: Reference #123456, Cash Payment, Shipped
// ================================================
class SalesOrder {

  // Unique reference number for this order
  final String referenceNumber;

  // The date and time the order was placed
  final DateTime dateTime;

  // The total amount of the order
  final double total;

  // How the customer paid (Cash Payment, Online Payment, etc.)
  final String paymentMethod;

  // The current status of the order
  final SalesOrderStatus status;

  // ================================================
  // CONSTRUCTOR
  // This is how we CREATE a SalesOrder
  // "required" means we MUST provide this value
  // ================================================
  const SalesOrder({
    required this.referenceNumber,
    required this.dateTime,
    required this.total,
    required this.paymentMethod,
    required this.status,
  });
}


// ================================================
// FAKE SALES ORDERS DATA
// This is our temporary hardcoded data
// It looks exactly like what Firestore would give us
// Later we replace this with real Firestore data
// but the SalesOrder class stays the same
// ================================================
final List<SalesOrder> fakeSalesOrders = [

  // ------------------------------------------------
  // Order 1 - Cash Payment, Shipped
  // ------------------------------------------------
  SalesOrder(
    referenceNumber: '123456',
    dateTime: DateTime(2026, 2, 13, 14, 45),
    total: 5500,
    paymentMethod: 'Cash Payment',
    status: SalesOrderStatus.shipped,
  ),

  // ------------------------------------------------
  // Order 2 - Online Payment, Preparing
  // ------------------------------------------------
  SalesOrder(
    referenceNumber: '123457',
    dateTime: DateTime(2026, 2, 13, 14, 45),
    total: 5500,
    paymentMethod: 'Online Payment',
    status: SalesOrderStatus.preparing,
  ),

];