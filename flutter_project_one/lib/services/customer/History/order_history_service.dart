import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/order.dart';

// ================================================
// ORDER HISTORY SERVICE
//
// FIX 1: Supabase join syntax — use bare table name
//         "address" not "address!orders_address_id_fkey"
//         when there is only one FK to that table.
// FIX 2: Pull receipt_url from payment so customer
//         can open their PDF receipt.
// FIX 3: Pull tracking_url from orders so the
//         "Track Package" button opens Lalamove.
// ================================================

class OrderHistoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Order>> getMyOrders() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      // ── Step 1: fetch orders with correct join syntax ──
      // NOTE: use the bare FK table name "address" — Supabase
      // auto-resolves the FK when there is only one FK to that table.
      final List<dynamic> ordersResponse = await _supabase
          .from('orders')
          .select('''
            order_id,
            total_amount,
            subtotal,
            shipping,
            discount_amount,
            payment_method,
            order_status,
            tracking_url,
            created_at,
            address (
              street,
              barangay,
              city,
              province,
              zip_code,
              landmark
            ),
            order_item (
              product_name_snapshot,
              brand_snapshot,
              size_snapshot,
              quantity,
              unit_price,
              subtotal
            )
          ''')
          .eq('user_id', user.id)
          .neq('order_status', 'Awaiting Payment')   
          .order('created_at', ascending: false);

      if (ordersResponse.isEmpty) return [];

      final List<int> orderIds = ordersResponse
          .map<int>((dynamic r) => (r['order_id'] as num).toInt())
          .toList();

      final List<dynamic> payments = await _supabase
          .from('payment')
          .select('order_id, payment_status, receipt_url')
          .inFilter('order_id', orderIds);

      final Map<int, String>  paymentStatusMap = {};
      final Map<int, String?> receiptUrlMap    = {};

      for (final dynamic p in payments) {
        final int oid          = (p['order_id'] as num).toInt();
        paymentStatusMap[oid]  = p['payment_status'] ?? 'Pending';
        receiptUrlMap[oid]     = p['receipt_url'] as String?;
      }

      // ── Step 3: fetch customer profile once ──
      final dynamic userProfile = await _supabase
          .from('users')
          .select('first_name, last_name, phone')
          .eq('id', user.id)
          .single();

      final String firstName = userProfile['first_name'] ?? '';
      final String lastName  = userProfile['last_name']  ?? '';
      final String phone     = userProfile['phone']      ?? '';
      final String fullName  = '$firstName $lastName'.trim().isEmpty
          ? 'Customer'
          : '$firstName $lastName'.trim();

      // ── Step 4: build Order list ──
      final List<Order> orders = [];

      for (final dynamic row in ordersResponse) {
        final Map<String, dynamic> map = row as Map<String, dynamic>;
        final int orderId = (map['order_id'] as num).toInt();

        final dynamic rawAddr = map['address'];
        final Map<String, dynamic> addr =
            rawAddr is Map<String, dynamic> ? rawAddr : {};

        final String street   = addr['street']   ?? '';
        final String barangay = addr['barangay'] ?? '';
        final String city     = addr['city']      ?? '';
        final String province = addr['province'] ?? '';
        final String zip      = addr['zip_code']  ?? '';
        final String landmark = addr['landmark']  ?? '';
        // Barangay and province were left out, so the address on the order page
        // stopped at the city.
        final String fullAddress = [street, barangay, city, province, zip]
            .where((s) => s.isNotEmpty)
            .join(', ');

        final List<dynamic>   rawItems = map['order_item'] ?? [];
        final List<OrderItem> items    = rawItems
            .map((dynamic i) =>
                OrderItem.fromMap(i as Map<String, dynamic>))
            .toList();

        String dateTime = '';
        if (map['created_at'] != null) {
          final DateTime dt  =
              DateTime.parse(map['created_at'].toString()).toLocal();
          final String month = dt.month.toString().padLeft(2, '0');
          final String day   = dt.day.toString().padLeft(2, '0');
          final String year  = dt.year.toString();
          final int    h12   = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
          final String min   = dt.minute.toString().padLeft(2, '0');
          final String amPm  = dt.hour < 12 ? 'am' : 'pm';
          dateTime = '$month/$day/$year ${h12}:$min $amPm';
        }

        orders.add(Order(
          orderId:       orderId.toString(),
          customerName:  fullName,
          contact:       phone,
          landmark:      landmark,
          address:       fullAddress,
          totalAmount:   (map['total_amount'] as num).toDouble(),
          // Loaded now. They were never read before, so the order page showed
          // Shipping as 0.00 and never showed the saved amount, and the lines
          // did not add up to the total.
          subtotal:       (map['subtotal'] as num?)?.toDouble() ?? 0,
          shipping:       (map['shipping'] as num?)?.toDouble() ?? 0,
          discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
          paymentMethod: map['payment_method'] ?? '',
          paymentStatus: paymentStatusMap[orderId] ?? 'Pending',
          orderStatus:   map['order_status'] ?? 'Pending',
          dateTime:      dateTime,
          items:         items,
          trackingUrl:   map['tracking_url'] as String?,   // ← add this
          receiptUrl:    receiptUrlMap[orderId],            // ← add this
        ));
      }

      return orders;
    } catch (e) {
      print('OrderHistoryService.getMyOrders error: $e');
      return [];
    }
  }

  // ================================================
  // FETCH SINGLE ORDER BY ID
  // Used when a notification needs to navigate straight to one
  // order (e.g. "TRACK SHIPMENT") without loading the entire order
  // history just to find it.
  // ================================================
  Future<Order?> fetchOrderById(String orderId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final int? parsedId = int.tryParse(orderId);
      if (parsedId == null) return null;

      final dynamic row = await _supabase
          .from('orders')
          .select('''
            order_id,
            total_amount,
            subtotal,
            shipping,
            discount_amount,
            payment_method,
            order_status,
            tracking_url,
            created_at,
            address (
              street,
              barangay,
              city,
              province,
              zip_code,
              landmark
            ),
            order_item (
              product_name_snapshot,
              brand_snapshot,
              size_snapshot,
              quantity,
              unit_price,
              subtotal
            )
          ''')
          .eq('order_id', parsedId)
          .eq('user_id', user.id) // safety: only this customer's own order
          .maybeSingle();

      if (row == null) return null;

      final Map<String, dynamic> map = row as Map<String, dynamic>;

      final dynamic payment = await _supabase
          .from('payment')
          .select('payment_status, receipt_url')
          .eq('order_id', parsedId)
          .maybeSingle();

      final String paymentStatus =
          payment?['payment_status'] as String? ?? 'Pending';
      final String? receiptUrl = payment?['receipt_url'] as String?;

      final dynamic userProfile = await _supabase
          .from('users')
          .select('first_name, last_name, phone')
          .eq('id', user.id)
          .single();

      final String firstName = userProfile['first_name'] ?? '';
      final String lastName  = userProfile['last_name']  ?? '';
      final String phone     = userProfile['phone']      ?? '';
      final String fullName  = '$firstName $lastName'.trim().isEmpty
          ? 'Customer'
          : '$firstName $lastName'.trim();

      final dynamic rawAddr = map['address'];
      final Map<String, dynamic> addr =
          rawAddr is Map<String, dynamic> ? rawAddr : {};

      final String street   = addr['street']   ?? '';
      final String barangay = addr['barangay'] ?? '';
      final String city     = addr['city']      ?? '';
      final String province = addr['province'] ?? '';
      final String zip      = addr['zip_code']  ?? '';
      final String landmark = addr['landmark']  ?? '';
      // Barangay and province were left out, so the address on the order page
      // stopped at the city.
      final String fullAddress = [street, barangay, city, province, zip]
          .where((s) => s.isNotEmpty)
          .join(', ');

      final List<dynamic>   rawItems = map['order_item'] ?? [];
      final List<OrderItem> items    = rawItems
          .map((dynamic i) => OrderItem.fromMap(i as Map<String, dynamic>))
          .toList();

      String dateTime = '';
      if (map['created_at'] != null) {
        final DateTime dt  =
            DateTime.parse(map['created_at'].toString()).toLocal();
        final String month = dt.month.toString().padLeft(2, '0');
        final String day   = dt.day.toString().padLeft(2, '0');
        final String year  = dt.year.toString();
        final int    h12   = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final String min   = dt.minute.toString().padLeft(2, '0');
        final String amPm  = dt.hour < 12 ? 'am' : 'pm';
        dateTime = '$month/$day/$year ${h12}:$min $amPm';
      }

      return Order(
        orderId:       parsedId.toString(),
        customerName:  fullName,
        contact:       phone,
        landmark:      landmark,
        address:       fullAddress,
        totalAmount:   (map['total_amount'] as num).toDouble(),
        subtotal:       (map['subtotal'] as num?)?.toDouble() ?? 0,
        shipping:       (map['shipping'] as num?)?.toDouble() ?? 0,
        discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
        paymentMethod: map['payment_method'] ?? '',
        paymentStatus: paymentStatus,
        orderStatus:   map['order_status'] ?? 'Pending',
        dateTime:      dateTime,
        items:         items,
        trackingUrl:   map['tracking_url'] as String?,
        receiptUrl:    receiptUrl,
      );
    } catch (e) {
      print('OrderHistoryService.fetchOrderById error: $e');
      return null;
    }
  }

  // ================================================
  // PROGRESS: the real dates of each step, and the customer's own cancel reason
  //
  // Reads the order_progress rows of ONE order. Customers can read only the
  // progress rows of their own orders (the order_progress_select policy), so
  // asking by order id is safe. If nothing can be read, the result is empty and
  // the order page simply shows no extra dates. Nothing is estimated.
  // ================================================
  Future<OrderProgressInfo> fetchProgress(String orderId) async {
    final user = _supabase.auth.currentUser;
    final int? parsedId = int.tryParse(orderId);
    if (user == null || parsedId == null) return const OrderProgressInfo();

    try {
      final List<dynamic> rows = await _supabase
          .from('order_progress')
          .select('status, admin_note, updated_at')
          .eq('order_id', parsedId)
          .order('updated_at', ascending: true);

      final Map<String, String> stepDates = <String, String>{};
      String? cancelReason;

      for (final dynamic r in rows) {
        final String status =
            (r['status'] ?? '').toString().trim().toLowerCase();
        final dynamic at = r['updated_at'];

        // The FIRST row for a status is when the order reached it.
        if (status.isNotEmpty && at != null && !stepDates.containsKey(status)) {
          final DateTime? parsed = DateTime.tryParse(at.toString());
          if (parsed != null) {
            stepDates[status] = _formatDateTime(parsed.toLocal());
          }
        }

        if (status == 'cancelled') {
          cancelReason = _customerReasonFrom((r['admin_note'] ?? '').toString());
        }
      }

      return OrderProgressInfo(stepDates: stepDates, cancelReason: cancelReason);
    } catch (e) {
      print('OrderHistoryService.fetchProgress error: $e');
      return const OrderProgressInfo();
    }
  }

  // Same look as the order list: 10/19/2026 3:45 pm
  static String _formatDateTime(DateTime local) {
    final String month = local.month.toString().padLeft(2, '0');
    final String day   = local.day.toString().padLeft(2, '0');
    final String year  = local.year.toString();
    final int    h12   = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final String min   = local.minute.toString().padLeft(2, '0');
    final String amPm  = local.hour < 12 ? 'am' : 'pm';
    return '$month/$day/$year $h12:$min $amPm';
  }

  // Shows the reason ONLY when the customer gave it themselves
  // ("Cancelled by customer: Changed my mind"). Notes from the store or the
  // system are not repeated to the customer here.
  static String? _customerReasonFrom(String note) {
    const String prefix = 'Cancelled by customer:';
    if (!note.startsWith(prefix)) return null;
    String reason = note.substring(prefix.length).trim();
    const String refundSentence = 'Payment was already confirmed';
    final int cut = reason.indexOf(refundSentence);
    if (cut >= 0) reason = reason.substring(0, cut).trim();
    return reason.isEmpty ? null : reason;
  }
}

/// What the order page needs beyond the order itself.
class OrderProgressInfo {
  /// Status (lower case) to a formatted date, ONLY for statuses that really
  /// have a row in order_progress.
  final Map<String, String> stepDates;

  /// The customer's own cancellation reason, if they gave one.
  final String? cancelReason;

  const OrderProgressInfo({
    this.stepDates = const <String, String>{},
    this.cancelReason,
  });
}